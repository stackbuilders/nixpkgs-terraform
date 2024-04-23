{
  description = "A collection of Terraform versions that are automatically updated";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    # TODO: replace poc_allow_unfree with default branch
    config.url = "github:stackbuilders/nixpkgs-terraform/poc_allow_unfree?dir=config";
    # config.url = "path:/Users/sestrella/code/stackbuilders/nixpkgs-terraform/config";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    systems.url = "github:nix-systems/default";
  };

  outputs = { self, flake-parts, ... }@inputs: flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [
      inputs.flake-parts.flakeModules.easyOverlay
    ];
    systems = import inputs.systems;

    perSystem = { config, pkgs, pkgs-unstable, system, ... }:
      let
        flakeConfig = import inputs.config;
      in
      {
        _module.args = {
          pkgs-unstable = import inputs.nixpkgs-unstable {
            inherit system;
            config = flakeConfig.nixpkgs-unstable.config;
          };
        };

        checks = config.packages;

        packages =
          let
            # TODO: filter versions when allowUnfree is set to false
            versions = builtins.fromJSON (builtins.readFile ./versions.json);
            releases = import ./lib/releases.nix {
              inherit pkgs pkgs-unstable; custom-lib = self.lib;
              releases = versions.releases;
              silenceWarnings = flakeConfig.nixpkgs-terraform.config.silenceWarnings;
            };
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
