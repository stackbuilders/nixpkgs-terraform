{ pkgs, ... }:

{
  dotenv.enable = true;

  packages = [
    pkgs.cobra-cli
    pkgs.nix-prefetch
    pkgs.semantic-release
  ];

  languages.go.enable = true;

  pre-commit.hooks.nixpkgs-fmt.enable = true;
}
