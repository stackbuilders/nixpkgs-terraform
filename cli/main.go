package main

import (
	"log"

	"github.com/joho/godotenv"
	"github.com/stackbuilders/nixpkgs-terraform/cli/cmd"
)

func main() {
	err := godotenv.Load()
	if err != nil {
		log.Println(".env file not found")
	}

	cmd.Execute()
}
