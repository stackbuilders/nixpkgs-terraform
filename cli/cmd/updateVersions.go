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

var owner string
var repo string
var vendorHashPath string
var versionsPath string
var minVersionStr string
var maxVersionStr string

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
	return []byte(fmt.Sprintf("%d.%d", a.Major(), a.Minor())), nil
}

var updateVersionsCmd = &cobra.Command{
	Use:   "update-versions",
	Short: "Update versions file",
	Long:  "Look up the most recent Terraform releases and calculate the needed hashes for new versions",
	Run: func(cmd *cobra.Command, args []string) {
		token := os.Getenv("CLI_GITHUB_TOKEN")
		if token == "" {
			log.Fatal("Environment variable CLI_GITHUB_TOKEN is missing")
		}

		versionsPath, err := filepath.Abs(versionsPath)
		if err != nil {
			log.Fatal("File versions.json not found: ", err)
		}

		vendorHashPath, err := filepath.Abs(vendorHashPath)
		if err != nil {
			log.Fatal("File vendor-hash.nix not found: ", err)
		}

		minVersion, err := semver.NewVersion(minVersionStr)
		if err != nil {
			log.Fatal("Invalid min-version: ", err)
		}

		var maxVersion *semver.Version
		if maxVersionStr != "" {
			maxVersion, err = semver.NewVersion(maxVersionStr)
			if err != nil {
				log.Fatal("Invalid max-version: ", err)
			}
		}

		err = updateVersions(token, versionsPath, vendorHashPath, minVersion, maxVersion)
		if err != nil {
			log.Fatal("Unable to update versions: ", err)
		}
	},
}

func updateVersions(token string, versionsPath string, vendorHashPath string, minVersion *semver.Version, maxVersion *semver.Version) error {
	nixPrefetchPath, err := exec.LookPath("nix-prefetch")
	if err != nil {
		return fmt.Errorf("nix-prefetch not found: %w", err)
	}

	versions, err := readVersions(versionsPath)
	if err != nil {
		return err
	}

	err = withReleases(token, func(release *github.RepositoryRelease) error {
		tagName := release.GetTagName()
		version, err := semver.NewVersion(strings.TrimLeft(tagName, "v"))
		if err != nil {
			return err
		}
		if version.Compare(minVersion) >= 0 && (maxVersion == nil || version.Compare(maxVersion) <= 0) && version.Prerelease() == "" {
			if _, ok := versions.Releases[*version]; ok {
				log.Printf("Version %s found in file\n", version)
			} else {
				log.Printf("Computing hashes for %s\n", version)
				hash, err := computeHash(nixPrefetchPath, tagName)
				if err != nil {
					return fmt.Errorf("Unable to compute hash: %w", err)
				}
				log.Printf("Computed hash: %s\n", hash)
				vendorHash, err := computeVendorHash(nixPrefetchPath, vendorHashPath, version, hash)
				if err != nil {
					return fmt.Errorf("Unable to compute vendor hash: %w", err)
				}
				log.Printf("Computed vendor hash: %s\n", vendorHash)
				versions.Releases[*version] = Release{Hash: hash, VendorHash: vendorHash}
			}
		}
		return nil
	})
	if err != nil {
		return err
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
		log.Fatal("Unable to marshall versions: ", err)
	}

	err = os.WriteFile(versionsPath, content, 0644)
	if err != nil {
		log.Fatal("Unable to write file: ", err)
	}

	return nil
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

func withReleases(token string, f func(release *github.RepositoryRelease) error) error {
	client := github.NewClient(nil).WithAuthToken(token)
	opt := &github.ListOptions{Page: 1}
	for {
		releases, resp, err := client.Repositories.ListReleases(context.Background(), owner, repo, opt)
		if err != nil {
			return err
		}
		for _, release := range releases {
			err = f(release)
			if err != nil {
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

func computeHash(nixPrefetchPath string, tagName string) (string, error) {
	hash, err := runNixPrefetch(
		nixPrefetchPath,
		"fetchFromGitHub",
		"--owner",
		owner,
		"--repo",
		repo,
		"--rev",
		tagName)
	if err != nil {
		return "", err
	}
	return hash, nil
}

func computeVendorHash(nixPrefetchPath string, vendorHashFile string, version *semver.Version, hash string) (string, error) {
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
	rootCmd.AddCommand(updateVersionsCmd)

	updateVersionsCmd.Flags().StringVarP(&owner, "owner", "", "hashicorp", "The owner name of the repository on GitHub")
	updateVersionsCmd.Flags().StringVarP(&repo, "repo", "", "terraform", "The repository name on GitHub")
	updateVersionsCmd.Flags().StringVarP(&vendorHashPath, "vendor-hash", "", "vendor-hash.nix", "Nix file required to compute vendorHash")
	updateVersionsCmd.Flags().StringVarP(&versionsPath, "versions", "", "versions.json", "The file to be updated")
	updateVersionsCmd.Flags().StringVarP(&minVersionStr, "min-version", "", "1.0.0", "Min release version")
	updateVersionsCmd.Flags().StringVarP(&maxVersionStr, "max-version", "", "", "Max release version")
}
