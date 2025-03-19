package main

import (
	"log"
	"os"

	"github.com/joho/godotenv"
	"github.com/stackbuilders/nixpkgs-terraform/cli/cmd"
)

func main() {
	if err := godotenv.Load(); err != nil && !os.IsNotExist(err) {
		log.Fatal(err)
	}

	cmd.Execute()
}
