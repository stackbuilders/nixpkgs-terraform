{ pkgs, ... }:

{
  packages = [
    pkgs.semantic-release
  ];

  git-hooks.hooks = {
    action-validator.enable = true;
    actionlint.enable = true;
    nixpkgs-fmt.enable = true;
  };
}
