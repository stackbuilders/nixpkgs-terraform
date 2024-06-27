{ pkgs, ... }:

{
  packages = [
    pkgs.cobra-cli
  ];

  languages.go.enable = true;
}
