{ pkgs, ... }:

{
  dotenv.enable = true;

  packages = [
    pkgs.nix-prefetch
    pkgs.cobra-cli
  ];

  languages.go.enable = true;
}
