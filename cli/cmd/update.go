package cmd

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
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
			return fmt.Errorf("File versions.json not found: %w", err)
		}

		vendorHashPath, err := filepath.Abs(vendorHashPath)
		if err != nil {
			return fmt.Errorf("File vendor-hash.nix not found: %w", err)
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
			minVersion,
		)
		if err != nil {
			return fmt.Errorf("Unable to update versions: %w", err)
		}
		if len(newVersions) > 0 {
			var formattedVersions []string
			for _, addedVersion := range newVersions {
				formattedVersions = append(formattedVersions, addedVersion.String())
			}
			fmt.Printf("feat: Add Terraform version(s) %s", strings.Join(formattedVersions, ", "))
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
	minVersion *semver.Version,
) ([]*semver.Version, error) {
	versions, err := readVersions(versionsPath)
	if err != nil {
		return nil, fmt.Errorf("unable to read versions: %w", err)
	}

	var addedVersions []*semver.Version
	releases, err := getRepoReleases(token)
	if err != nil {
		return nil, err
	}
	for _, release := range releases {
		tagName := release.GetTagName()
		version, err := semver.NewVersion(strings.TrimLeft(tagName, "v"))
		if err != nil {
			return nil, fmt.Errorf("unable to parse version: %w", err)
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
				addedVersions = append(addedVersions, version)
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

	return addedVersions, nil
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

func getRepoReleases(token string) ([]*github.RepositoryRelease, error) {
	client := github.NewClient(nil).WithAuthToken(token)
	opt := &github.ListOptions{Page: 1}
	var allReleases []*github.RepositoryRelease
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
		allReleases = append(allReleases, releases...)
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
	cmd.Stderr = os.Stdout

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
	rootCmd.AddCommand(updateCmd)

	updateCmd.Flags().
		StringVarP(&vendorHashPath, "vendor-hash", "", "vendor-hash.nix", "Nix file required to compute vendorHash")
	updateCmd.Flags().
		StringVarP(&versionsPath, "versions", "", "versions.json", "The file to be updated")
	updateCmd.Flags().
		StringVarP(&minVersionStr, "min-version", "", "1.0.0", "Min release version")
}
