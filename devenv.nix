{ pkgs, ... }:

{
  dotenv.enable = true;

  packages = [
    pkgs.nix-prefetch
    pkgs.semantic-release
  ];

  pre-commit.hooks.nixpkgs-fmt.enable = true;
}
