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
	"fmt"
	"log"

	"github.com/Masterminds/semver/v3"
	"github.com/google/go-github/github"
	"github.com/spf13/cobra"
)

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
		client := github.NewClient(nil)
		opt := &github.ListOptions{Page: 1}
		for {
			releases, resp, err := client.Repositories.ListReleases(context.Background(), "hashicorp", "terraform", opt)
			if err != nil {
				log.Fatal("Unable to list releases: ", err)
			}
			for _, release := range releases {
				version, err := semver.NewVersion(release.GetTagName())
				if err != nil {
					log.Fatal("Unable to parse version: ", err)
				}
				fmt.Printf("%v\n", version)
			}
			if resp.NextPage == 0 {
				break
			}
			opt.Page = resp.NextPage
		}
	},
}

func init() {
	rootCmd.AddCommand(updateVersionsCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// updateVersionsCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// updateVersionsCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}
