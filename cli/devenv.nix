{ pkgs, ... }:

{
  dotenv.disableHint = true;

  packages = [
    pkgs.cobra-cli
  ];

  languages.go.enable = true;
}
