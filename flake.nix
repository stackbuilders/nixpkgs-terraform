{
  description = "A collection of Terraform versions that are automatically updated";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = { self, flake-parts, ... }@inputs: flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [
      inputs.flake-parts.flakeModules.easyOverlay
    ];
    systems = import inputs.systems;

    perSystem = { config, pkgs, pkgs-unstable, system, ... }: {
      _module.args = {
        pkgs-unstable = import inputs.nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      };

      checks = config.packages;

      packages =
        let
          versions = builtins.fromJSON (builtins.readFile ./versions.json);
          releases = import ./lib/releases.nix { inherit pkgs pkgs-unstable; custom-lib = self.lib; releases = versions.releases; };
          latestVersions = builtins.mapAttrs (_cycle: version: releases.${version}) versions.latest;
        in
        releases // latestVersions;

      overlayAttrs = {
        terraform-versions = config.packages;
      };
    };

    flake = {
      templates = {
        default = {
          description = "Simple nix-shell with Terraform installed via nixpkgs-terraform";
          path = ./templates/default;
        };
        devenv = {
          description = "Using nixpkgs-terraform with devenv";
          path = ./templates/devenv;
        };
        terranix = {
          description = "Using nixpkgs-terraform with terranix";
          path = ./templates/terranix;
        };
      };

      lib = import ./lib;
    };
  };
}
