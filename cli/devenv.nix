{ pkgs, ... }:

{
  dotenv.enable = true;

  packages = [
    pkgs.cobra-cli
    pkgs.nix-prefetch
    pkgs.nurl
  ];

  languages.go.enable = true;
}
