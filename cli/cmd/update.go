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

const (
	OWNER = "hashicorp"
	REPO  = "terraform"
)

var (
	vendorHashPath string
	versionsPath   string
	templatesPath  string
	minVersionStr  string
)

type Versions struct {
	Releases map[semver.Version]Release `json:"releases"`
	Latest   map[Alias]semver.Version   `json:"latest"`
}

type Release struct {
	Hash       string `json:"hash"`
	VendorHash string `json:"vendorHash"`
}

type Alias struct {
	semver.Version
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

var updateCmd = &cobra.Command{
	Use:   "update",
	Short: "Update versions file",
	Long:  "Look up the most recent Terraform releases and calculate the needed hashes for new versions",
	RunE: func(cmd *cobra.Command, args []string) error {
		nixPath, err := exec.LookPath("nix")
		if err != nil {
			return fmt.Errorf("nix not found: %w", err)
		}

		nixPrefetchPath, err := exec.LookPath("nix-prefetch")
		if err != nil {
			return fmt.Errorf("nix-prefetch not found: %w", err)
		}

		token := os.Getenv("CLI_GITHUB_TOKEN")
		if token == "" {
			return fmt.Errorf("Environment variable CLI_GITHUB_TOKEN is missing")
		}

		versionsPath, err := filepath.Abs(versionsPath)
		if err != nil {
			return fmt.Errorf("file versions.json not found: %w", err)
		}

		vendorHashPath, err := filepath.Abs(vendorHashPath)
		if err != nil {
			return fmt.Errorf("File vendor-hash.nix not found: %w", err)
		}

		templatesPath, err := filepath.Abs(templatesPath)
		if err != nil {
			return fmt.Errorf("Directory templates not found: %w", err)
		}

		templatesInfo, err := os.Stat(templatesPath)
		if err != nil {
			return fmt.Errorf("Path doesn't exist or can't be accessed: %w", err)
		}
		if !templatesInfo.IsDir() {
			return fmt.Errorf("Path exists but is not a directory: %s", templatesPath)
		}

		minVersion, err := semver.NewVersion(minVersionStr)
		if err != nil {
			return fmt.Errorf("Invalid min-version: %w", err)
		}

		newVersions, err := updateVersions(
			nixPath,
			nixPrefetchPath,
			token,
			versionsPath,
			vendorHashPath,
			templatesPath,
			minVersion,
		)
		if err != nil {
			return fmt.Errorf("Unable to update versions: %w", err)
		}
		if len(newVersions) > 0 {
			var formattedVersions []string
			for _, newVersion := range newVersions {
				formattedVersions = append(formattedVersions, newVersion.String())
			}
			fmt.Printf("feat: Add Terraform version(s) %s\n", strings.Join(formattedVersions, ", "))
		}

		return nil
	},
}

func updateVersions(
	nixPath string,
	nixPrefetchPath string,
	token string,
	versionsPath string,
	vendorHashPath string,
	templatesPath string,
	minVersion *semver.Version,
) ([]semver.Version, error) {
	versions, err := readVersions(versionsPath)
	if err != nil {
		return nil, fmt.Errorf("unable to read versions: %w", err)
	}

	releases, err := getRepoReleases(token)
	if err != nil {
		return nil, err
	}

	var newVersions []semver.Version
	for _, release := range releases {
		tagName := release.GetTagName()
		version, err := semver.NewVersion(strings.TrimLeft(tagName, "v"))
		if err != nil {
			log.Printf("Skipping invalid tag '%s': %v\n", tagName, err)
			continue
		}

		if version.Compare(minVersion) >= 0 && version.Prerelease() == "" {
			if _, ok := versions.Releases[*version]; ok {
				log.Printf("Version %s found in file\n", version)
			} else {
				log.Printf("Computing hashes for %s\n", version)
				hash, err := computeHash(nixPath, tagName)
				if err != nil {
					return nil, fmt.Errorf("Unable to compute hash: %w", err)
				}

				log.Printf("Computed hash: %s\n", hash)
				vendorHash, err := computeVendorHash(nixPrefetchPath, vendorHashPath, version, hash)
				if err != nil {
					return nil, fmt.Errorf("Unable to compute vendor hash: %w", err)
				}

				log.Printf("Computed vendor hash: %s\n", vendorHash)
				versions.Releases[*version] = Release{Hash: hash, VendorHash: vendorHash}
				newVersions = append(newVersions, *version)
			}
		}
	}

	versions.Latest = make(map[Alias]semver.Version)
	for version := range versions.Releases {
		alias := Alias{*semver.New(version.Major(), version.Minor(), 0, "", "")}
		if latest, ok := versions.Latest[alias]; !ok || version.Compare(&latest) > 0 {
			versions.Latest[alias] = version
		}
	}

	content, err := json.MarshalIndent(versions, "", "  ")
	if err != nil {
		return nil, fmt.Errorf("Unable to marshall versions: %w", err)
	}

	err = os.WriteFile(versionsPath, content, 0644)
	if err != nil {
		return nil, fmt.Errorf("Unable to write file: %w", err)
	}

	latestAlias, err := updateTemplatesVersions(versions, templatesPath)
	if err != nil {
		return nil, fmt.Errorf("Unable to update templates versions: %w", err)
	}
	if latestAlias != nil && len(newVersions) == 0 {
		newVersions = []semver.Version{latestAlias.Version}
	}

	return newVersions, nil
}

func getLatestAlias(aliases []Alias) (*Alias, error) {
	var latestAlias *Alias
	for _, alias := range aliases {
		if alias.GreaterThan(latestAlias) {
			latestAlias = &alias
		}
	}
	if latestAlias == nil {
		return nil, fmt.Errorf("No latest version found")
	}

	return latestAlias, nil
}

func updateTemplatesVersions(versions *Versions, templatesPath string) (*Alias, error) {
	var aliases []Alias
	for alias := range versions.Latest {
		aliases = append(aliases, alias)
	}

	latestAlias, err := getLatestAlias(aliases)
	if err != nil {
		return nil, fmt.Errorf("Unable to get latest version: %w", err)
	}
	files, err := filepath.Glob(fmt.Sprintf("%s/**/flake.nix", templatesPath))
	if err != nil {
		return nil, fmt.Errorf("Unable to find flake.nix files: %w", err)
	}

	re := regexp.MustCompile(`"(\d+\.\d+(\.\d+)?)"`)
	for _, file := range files {
		content, err := os.ReadFile(file)
		if err != nil {
			return nil, fmt.Errorf("Unable to read file %s: %w", file, err)
		}
		updatedContent := re.ReplaceAllString(string(content), fmt.Sprintf(`"%s"`, latestAlias.String()))
		if string(content) == updatedContent {
			log.Printf("No changes needed for %s\n", file)
			continue
		}

		err = os.WriteFile(file, []byte(updatedContent), 0644)
		if err != nil {
			return nil, fmt.Errorf("Unable to write file %s: %w", file, err)
		}

		log.Printf("Updated %s to version %s\n", file, latestAlias)
	}
	return latestAlias, nil
}

func readVersions(versionsPath string) (*Versions, error) {
	content, err := os.ReadFile(versionsPath)
	if err != nil {
		return nil, err
	}
	var versions *Versions
	err = json.Unmarshal(content, &versions)
	if err != nil {
		return nil, err
	}
	return versions, nil
}

func getRepoReleases(token string) ([]github.RepositoryRelease, error) {
	client := github.NewClient(nil).WithAuthToken(token)
	opt := &github.ListOptions{Page: 1}

	var allReleases []github.RepositoryRelease
	for {
		releases, resp, err := client.Repositories.ListReleases(
			context.Background(),
			OWNER,
			REPO,
			opt,
		)
		if err != nil {
			return nil, err
		}

		for _, release := range releases {
			allReleases = append(allReleases, *release)
		}
		if resp.NextPage == 0 {
			break
		}

		opt.Page = resp.NextPage
	}

	return allReleases, nil
}

func computeHash(nixPath string, tagName string) (string, error) {
	cmd := exec.Command(
		nixPath, "flake", "prefetch",
		"--extra-experimental-features", "nix-command flakes",
		"--json", fmt.Sprintf("github:%s/%s/%s", OWNER, REPO, tagName),
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

func computeVendorHash(
	nixPrefetchPath string,
	vendorHashFile string,
	version *semver.Version,
	hash string,
) (string, error) {
	vendorHash, err := runNixPrefetch(
		nixPrefetchPath,
		"--file",
		vendorHashFile,
		"--argstr",
		"version",
		version.String(),
		"--argstr",
		"hash",
		hash)
	if err != nil {
		return "", err
	}

	return vendorHash, nil
}

func runNixPrefetch(nixPrefetchPath string, extraArgs ...string) (string, error) {
	args := append([]string{"--option", "extra-experimental-features", "flakes"}, extraArgs...)

	cmd := exec.Command(nixPrefetchPath, args...)
	cmd.Stderr = log.Writer()

	output, err := cmd.Output()
	if err != nil {
		return "", err
	}

	return strings.TrimRight(string(output), "\n"), nil
}

func init() {
	updateCmd.Flags().
		StringVarP(&vendorHashPath, "vendor-hash", "", "vendor-hash.nix", "Nix file required to compute vendorHash")
	updateCmd.Flags().
		StringVarP(&versionsPath, "versions", "", "versions.json", "The file to be updated")
	updateCmd.Flags().
		StringVarP(&templatesPath, "templates-dir", "", "templates", "Directory containing templates to update versions")
	updateCmd.Flags().
		StringVarP(&minVersionStr, "min-version", "", "1.0.0", "Min release version")

	rootCmd.AddCommand(updateCmd)
}
