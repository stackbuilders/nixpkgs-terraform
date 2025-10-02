{ pkgs, ... }:

{
  packages = [
    pkgs.semantic-release
  ];

  git-hooks.hooks.nixpkgs-fmt.enable = true;
}
