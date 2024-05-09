{
  description = "A collection of Terraform versions that are automatically updated";

  inputs = {
    config.url = "github:stackbuilders/nixpkgs-terraform?dir=templates/config";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    systems.url = "github:nix-systems/default";
  };

  outputs = inputs@{ self, ... }: inputs.flake-parts.lib.mkFlake
    { inherit inputs; }
    {
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
              config = flakeConfig.nixpkgs-unstable;
            };
          };

          checks = config.packages;

          packages =
            let
              filteredVersions =
                let
                  versions = builtins.fromJSON (builtins.readFile ./versions.json);
                  allowUnfree = flakeConfig.nixpkgs-unstable.allowUnfree;
                  versionLessThan1_6 = version: builtins.compareVersions version "1.6.0" < 0;
                in
                {
                  releases = pkgs.lib.filterAttrs (version: _: allowUnfree || versionLessThan1_6 version) versions.releases;
                  latest = pkgs.lib.filterAttrs (_: version: allowUnfree || versionLessThan1_6 version) versions.latest;
                };
              releases = import ./lib/releases.nix {
                inherit pkgs pkgs-unstable; custom-lib = self.lib;
                releases = filteredVersions.releases;
                silenceWarnings = flakeConfig.nixpkgs-terraform.silenceWarnings;
              };
              latestVersions = builtins.mapAttrs (_cycle: version: releases.${version}) filteredVersions.latest;
            in
            releases // latestVersions;

          overlayAttrs = {
            terraform-versions = config.packages;
          };
        };

      flake = {
        templates = {
          config = {
            description = "Template use to override nixpkgs-terraform default configuration";
            path = ./templates/config;
          };
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
