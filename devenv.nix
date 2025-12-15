{ pkgs, ... }:

{
  packages = [
    pkgs.semantic-release
  ];

  languages.terraform = {
    enable = true;
    version = "1.14";
  };

  git-hooks.hooks.nixpkgs-fmt.enable = true;
}
