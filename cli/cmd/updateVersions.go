/*
Copyright © 2024 Stack Builders

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/
package cmd

import (
	"context"
	"encoding/json"
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

type Versions struct {
	Releases map[semver.Version]Release        `json:"releases"`
	Latest   map[semver.Version]semver.Version `json:"latest"`
}

type Release struct {
	Hash       string `json:"hash"`
	VendorHash string `json:"vendorHash"`
}

// updateVersionsCmd represents the updateVersions command
var updateVersionsCmd = &cobra.Command{
	Use:   "update-versions",
	Short: "A brief description of your command",
	Long: `A longer description that spans multiple lines and likely contains examples
and usage of using your command. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.`,
	Run: func(cmd *cobra.Command, args []string) {
		token := os.Getenv("NIXPKGS_TERRAFORM_GITHUB_TOKEN")
		versionsPath, err := filepath.Abs(versionsPath)
		if err != nil {
			log.Fatal("File versions.json not found", err)
		}
		vendorHashPath, err := filepath.Abs(vendorHashPath)
		if err != nil {
			log.Fatal("File vendor-hash.nix not found", err)
		}
		updateVersions(versionsPath, vendorHashPath, token)
	},
}

func updateVersions(versionsPath string, vendorHashPath string, token string) {
	nixPrefetchPath, err := exec.LookPath("nix-prefetch")
	if err != nil {
		log.Fatal("Unable to find nix-prefetch", err)
	}

	versions, err := readVersions(versionsPath)
	if err != nil {
		log.Fatal("Unable to read versions file: ", err)
	}

	threshold, err := semver.NewVersion("1.0.0")
	if err != nil {
		log.Fatal("Unable to parse version: ", err)
	}

	f := func(release *github.RepositoryRelease) error {
		tagName := release.GetTagName()
		version, err := semver.NewVersion(strings.TrimLeft(tagName, "v"))
		if err != nil {
			return err
		}
		if version.Compare(threshold) >= 0 && version.Prerelease() == "" {
			if _, ok := versions.Releases[*version]; ok {
				log.Printf("Version %v found in releases\n", version)
			} else {
				log.Printf("Computing hashes for %v\n", version)
				hash, err := computeHash(nixPrefetchPath, tagName)
				if err != nil {
					return err
				}
				log.Printf("Computed hash: %v\n", hash)
				vendorHash, err := computeVendorHash(nixPrefetchPath, vendorHashPath, version, hash)
				if err != nil {
					return err
				}
				log.Printf("Computed vendor hash: %v\n", vendorHash)
				versions.Releases[*version] = Release{Hash: hash, VendorHash: vendorHash}
			}
		}
		return nil
	}

	err = withReleases(token, f)
	if err != nil {
		log.Fatal(err)
	}

	content, err := json.MarshalIndent(versions, "  ", "  ")
	if err != nil {
		log.Fatal("Unable to marshall versions", err)
	}

	err = os.WriteFile(versionsPath, content, 0644)
	if err != nil {
		log.Fatal("Unable to write to file versions.json", err)
	}
}

func readVersions(versionsPath string) (*Versions, error) {
	content, err := os.ReadFile(versionsPath)
	if err != nil {
		return nil, err
	}
	var versions *Versions
	json.Unmarshal(content, &versions)
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
	updateVersionsCmd.Flags().StringVarP(&owner, "owner", "", "hashicorp", "TODO")
	updateVersionsCmd.Flags().StringVarP(&repo, "repo", "", "terraform", "TODO")
	updateVersionsCmd.Flags().StringVarP(&vendorHashPath, "vendor-hash", "", "vendor-hash.nix", "TODO")
	updateVersionsCmd.Flags().StringVarP(&versionsPath, "versions", "", "versions.json", "TODO")

	rootCmd.AddCommand(updateVersionsCmd)
}
