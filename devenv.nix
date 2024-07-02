{ pkgs, ... }:

{
  packages = [
    pkgs.semantic-release
  ];

  pre-commit.hooks.nixpkgs-fmt.enable = true;
}
