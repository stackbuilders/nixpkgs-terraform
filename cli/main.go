package main

import (
	"log"

	"github.com/joho/godotenv"
	"github.com/stackbuilders/nixpkgs-terraform/cli/cmd"
)

func main() {
	err := godotenv.Load()
	if err != nil {
		log.Printf("Unable to load .env file: %v", err)
	}

	cmd.Execute()
}
