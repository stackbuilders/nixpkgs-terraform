{ pkgs, ... }:

{
  packages = [
    pkgs.semantic-release
  ];

  pre-commit.hooks.nixpkgs-fmt.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
