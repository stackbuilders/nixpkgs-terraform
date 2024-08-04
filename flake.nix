{
  description = "A collection of Terraform versions that are automatically updated";

  inputs = {
    config.url = "github:stackbuilders/nixpkgs-terraform?dir=templates/config";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs-23_05.url = "github:nixos/nixpkgs/nixos-23.05";
    nixpkgs-24_05.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs = inputs@{ self, ... }: inputs.flake-parts.lib.mkFlake
    { inherit inputs; }
    {
      imports = [
        inputs.flake-parts.flakeModules.easyOverlay
      ];

      systems = import inputs.systems;

      perSystem = { config, pkgs-23_05, pkgs-24_05, pkgs, system, ... }:
        let
          flakeConfig = import inputs.config;
        in
        {
          _module.args = {
            pkgs-23_05 = import inputs.nixpkgs-23_05 {
              inherit system;
            };
            pkgs-24_05 = import inputs.nixpkgs-24_05 {
              inherit system;
              config = flakeConfig.nixpkgs-unstable;
            };
            pkgs = import inputs.nixpkgs {
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
                inherit pkgs-23_05 pkgs-24_05 pkgs; custom-lib = self.lib;
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
