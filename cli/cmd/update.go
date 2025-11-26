package cmd

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/Masterminds/semver/v3"
	"github.com/google/go-github/v62/github"
	"github.com/spf13/cobra"
)

var (
	owner         string
	repo          string
	versionsPath  string
	templatesPath string
	minVersionStr string
)

type Versions struct {
	Releases map[semver.Version]Release `json:"releases"`
	Aliases  map[Alias]semver.Version   `json:"aliases"`
}

type Release struct {
	Hash       string `json:"hash"`
	VendorHash string `json:"vendorHash"`
}

type Alias struct {
	semver.Version
}

type LastestChanges struct {
	versions    []semver.Version
	latestAlias *Alias
}

func (a Alias) MarshalText() ([]byte, error) {
	return fmt.Appendf(nil, "%d.%d", a.Major(), a.Minor()), nil
}

func (a Alias) GreaterThan(b *Alias) bool {
	if b == nil {
		return true
	}
	return a.Version.GreaterThan(&b.Version)
}

func (a Alias) String() string {
	return fmt.Sprintf("%d.%d", a.Major(), a.Minor())
}

var updateCmd = &cobra.Command{
	Use:   "update",
	Short: "Update versions file",
	Long:  "Look up the most recent Terraform releases and calculate the needed hashes for new versions",
	RunE: func(cmd *cobra.Command, args []string) error {
		nixPath, err := exec.LookPath("nix")
		if err != nil {
			return fmt.Errorf("unable to find 'nix' executable: %w", err)
		}

		token := os.Getenv("CLI_GITHUB_TOKEN")
		if token == "" {
			log.Println("Warning: CLI_GITHUB_TOKEN is not set. Requests to GitHub API may be rate limited.")
		}

		versionsPath, err := filepath.Abs(versionsPath)
		if err != nil {
			return fmt.Errorf("unable to find versions.json file: %w", err)
		}

		templatesPath, err := filepath.Abs(templatesPath)
		if err != nil {
			return fmt.Errorf("unable to find templates directory: %w", err)
		}

		templatesInfo, err := os.Stat(templatesPath)
		if err != nil {
			return fmt.Errorf("path does not exist or cannot be accessed: %w", err)
		}
		if !templatesInfo.IsDir() {
			return fmt.Errorf("path exists but is not a directory: %s", templatesPath)
		}

		minVersion, err := semver.NewVersion(minVersionStr)
		if err != nil {
			return fmt.Errorf("invalid min-version: %w", err)
		}

		latestChanges, err := updateVersions(
			nixPath,
			token,
			versionsPath,
			templatesPath,
			minVersion,
			owner,
			repo,
		)
		if err != nil {
			return fmt.Errorf("unable to update versions: %w", err)
		}
		var messages []string
		if len(latestChanges.versions) > 0 {
			var formattedVersions []string
			for _, newVersion := range latestChanges.versions {
				formattedVersions = append(formattedVersions, newVersion.String())
			}
			versions := strings.Join(formattedVersions, ", ")
			messages = append(messages, fmt.Sprintf("Add Terraform version(s) %s", versions))
		}
		if latestChanges.latestAlias != nil {
			messages = append(
				messages,
				fmt.Sprintf("Update templates to use version %s", latestChanges.latestAlias),
			)
		}

		if len(messages) > 0 {
			fmt.Printf("feat: %s\n", strings.Join(messages, " / "))
		}
		return nil
	},
}

func updateVersions(
	nixPath string,
	token string,
	versionsPath string,
	templatesPath string,
	minVersion *semver.Version,
	owner string,
	repo string,
) (*LastestChanges, error) {
	versions, err := readVersions(versionsPath)
	if err != nil {
		return nil, fmt.Errorf("unable to read versions: %w", err)
	}

	var newSemverVersions []*semver.Version
	err = withRepoReleases(token, owner, repo, minVersion, func(version *semver.Version, release *github.RepositoryRelease) error {
		versionCopy := *version
		if _, ok := versions.Releases[versionCopy]; ok {
			return nil
		}

		log.Printf("Computing hash for %s\n", version)
		hash, err := computeHash(nixPath, release.GetTagName(), owner, repo)
		if err != nil {
			return fmt.Errorf("unable to compute hash: %w", err)
		}

		log.Printf("Computed hash: %s\n", hash)
		versions.Releases[versionCopy] = Release{Hash: hash, VendorHash: ""}
		newSemverVersions = append(newSemverVersions, &versionCopy)
		return nil
	})
	if err != nil {
		return nil, err
	}

	if len(newSemverVersions) > 0 {
		log.Println("Writing versions.json with new versions to compute vendor hashes")
		content, err := json.MarshalIndent(versions, "", "  ")
		if err != nil {
			return nil, fmt.Errorf("unable to marshal versions: %w", err)
		}
		if err := os.WriteFile(versionsPath, content, 0644); err != nil {
			return nil, fmt.Errorf("unable to write file: %w", err)
		}

		for _, version := range newSemverVersions {
			log.Printf("Computing vendor hash for %s\n", version)
			vendorHash, err := computeVendorHash(nixPath, version)
			if err != nil {
				return nil, fmt.Errorf("unable to compute vendor hash for %s: %w", version, err)
			}

			log.Printf("Computed vendor hash: %s\n", vendorHash)
			release := versions.Releases[*version]
			release.VendorHash = vendorHash
			versions.Releases[*version] = release
		}
	}

	// Always update aliases and write the file, even if no new versions,
	// to ensure aliases are correct.
	versions.Aliases = make(map[Alias]semver.Version)
	for version := range versions.Releases {
		vCopy := version
		alias := Alias{*semver.New(vCopy.Major(), vCopy.Minor(), 0, "", "")}
		if latest, ok := versions.Aliases[alias]; !ok || vCopy.GreaterThan(&latest) {
			versions.Aliases[alias] = vCopy
		}
	}

	log.Println("Writing final versions.json")
	content, err := json.MarshalIndent(versions, "", "  ")
	if err != nil {
		return nil, fmt.Errorf("unable to marshal versions: %w", err)
	}
	if err := os.WriteFile(versionsPath, content, 0644); err != nil {
		return nil, fmt.Errorf("unable to write file: %w", err)
	}

	latestAlias, err := updateTemplatesVersions(versions, templatesPath)
	if err != nil {
		return nil, fmt.Errorf("unable to update templates versions: %w", err)
	}

	var newVersionsValues []semver.Version
	for _, v := range newSemverVersions {
		newVersionsValues = append(newVersionsValues, *v)
	}

	return &LastestChanges{
		versions:    newVersionsValues,
		latestAlias: latestAlias,
	}, nil
}

func getLatestAlias(aliases []Alias) (*Alias, error) {
	var latestAlias *Alias
	for _, alias := range aliases {
		if alias.GreaterThan(latestAlias) {
			latestAlias = &alias
		}
	}
	if latestAlias == nil {
		return nil, fmt.Errorf("no latest version found")
	}

	return latestAlias, nil
}

func updateTemplatesVersions(versions *Versions, templatesPath string) (*Alias, error) {
	var aliases []Alias
	for alias := range versions.Aliases {
		aliases = append(aliases, alias)
	}

	latestAlias, err := getLatestAlias(aliases)
	if err != nil {
		return nil, fmt.Errorf("unable to get latest version: %w", err)
	}

	files, err := filepath.Glob(fmt.Sprintf("%s/**/flake.nix", templatesPath))
	if err != nil {
		return nil, fmt.Errorf("unable to find flake.nix files: %w", err)
	}

	updated := false
	re := regexp.MustCompile(`"(\d+\.\d+(\.\d+)?)"`)
	for _, file := range files {
		content, err := os.ReadFile(file)
		if err != nil {
			return nil, fmt.Errorf("unable to read file %s: %w", file, err)
		}
		updatedContent := re.ReplaceAllString(
			string(content),
			fmt.Sprintf(`"%s"`, latestAlias),
		)
		if string(content) == updatedContent {
			log.Printf("No changes needed for %s\n", file)
			continue
		}

		err = os.WriteFile(file, []byte(updatedContent), 0644)
		if err != nil {
			return nil, fmt.Errorf("unable to write file %s: %w", file, err)
		}
		log.Printf("Updated %s to version %s\n", file, latestAlias)
		updated = true
	}

	if updated {
		return latestAlias, nil
	}

	return nil, nil
}

func readVersions(versionsPath string) (*Versions, error) {
	content, err := os.ReadFile(versionsPath)
	if err != nil {
		return nil, err
	}

	var versions *Versions
	if err = json.Unmarshal(content, &versions); err != nil {
		return nil, err
	}

	return versions, nil
}

func withRepoReleases(
	token string,
	owner string,
	repo string,
	minVersion *semver.Version,
	callback func(version *semver.Version, release *github.RepositoryRelease) error,
) error {
	client := github.NewClient(nil)
	if token != "" {
		client = client.WithAuthToken(token)
	}

	opt := &github.ListOptions{Page: 1}
	for {
		releases, resp, err := client.Repositories.ListReleases(
			context.Background(),
			owner,
			repo,
			opt,
		)
		if err != nil {
			return err
		}

		for _, release := range releases {
			if release.GetPrerelease() {
				continue
			}

			tagName := release.GetTagName()
			version, err := semver.NewVersion(strings.TrimLeft(tagName, "v"))
			if err != nil {
				log.Printf("Skipping invalid tag '%s': %v\n", tagName, err)
				continue
			}

			if version.LessThan(minVersion) {
				continue
			}

			if err := callback(version, release); err != nil {
				return err
			}
		}

		if resp.NextPage == 0 {
			break
		}

		opt.Page = resp.NextPage
	}

	return nil
}

func computeHash(nixPath string, tagName string, owner string, repo string) (string, error) {
	cmd := exec.Command(
		nixPath, "flake", "prefetch",
		"--extra-experimental-features", "nix-command flakes",
		"--json", fmt.Sprintf("github:%s/%s?ref=%s", owner, repo, tagName),
	)

	// Redirect stderr to the standard logger
	cmd.Stderr = log.Writer()

	// Get the output
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("command execution failed: %w", err)
	}

	// Parse JSON output to get hash
	var result struct {
		Hash string `json:"hash"`
	}
	if err := json.Unmarshal(output, &result); err != nil {
		return "", fmt.Errorf("failed to parse JSON output: %w", err)
	}

	return result.Hash, nil
}

func computeVendorHash(nixPath string, version *semver.Version) (string, error) {
	cmd := exec.Command(
		nixPath, "build",
		"--extra-experimental-features", "nix-command flakes",
		"--no-link",
		fmt.Sprintf(".#'\"terraform-%s\"'", version.String()),
	)
	// TODO: remove hard-coded dir
	cmd.Dir = "/Users/sestrella/code/stackbuilders/nixpkgs-terraform"

	output, err := cmd.CombinedOutput()
	if err == nil {
		return "", fmt.Errorf("nix build succeeded unexpectedly for version %s with an empty vendor hash", version.String())
	}

	re := regexp.MustCompile(`got:\s+(sha256-[a-zA-Z0-9+/=]+)`)
	matches := re.FindStringSubmatch(string(output))

	if len(matches) < 2 {
		return "", fmt.Errorf("could not find vendor hash in nix build output for version %s: %s", version.String(), string(output))
	}

	return matches[1], nil
}

func init() {
	updateCmd.Flags().
		StringVarP(&versionsPath, "versions", "", "versions.json", "The file to be updated")
	updateCmd.Flags().
		StringVarP(&templatesPath, "templates-dir", "", "templates", "Directory containing templates to update versions")
	updateCmd.Flags().
		StringVarP(&minVersionStr, "min-version", "", "1.0.0", "Min release version")
	updateCmd.Flags().
		StringVarP(&owner, "owner", "", "hashicorp", "GitHub repository owner")
	updateCmd.Flags().
		StringVarP(&repo, "repo", "", "terraform", "GitHub repository name")

	rootCmd.AddCommand(updateCmd)
}
