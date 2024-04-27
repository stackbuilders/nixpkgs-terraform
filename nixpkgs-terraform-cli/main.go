/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>

*/
package main

import (
	"github.com/stackbuilders/nixpkgs-terraform/nixpkgs-terraform-cli/cmd"
	_ "github.com/stackbuilders/nixpkgs-terraform/nixpkgs-terraform-cli/cmd/update"
	_ "github.com/stackbuilders/nixpkgs-terraform/nixpkgs-terraform-cli/cmd/publish"
)

func main() {
	cmd.Execute()
}
