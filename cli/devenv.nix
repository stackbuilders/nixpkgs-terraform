{ pkgs, ... }:

{
  dotenv.disableHint = true;

  packages = [
    pkgs.cobra-cli
    pkgs.nix-prefetch
  ];

  languages.go.enable = true;
}
