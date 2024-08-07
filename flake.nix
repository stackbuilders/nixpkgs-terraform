{
  description = "A collection of Terraform versions that are automatically updated";

  inputs = {
    config.url = "github:stackbuilders/nixpkgs-terraform?dir=templates/config";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs-1_0.url = "github:nixos/nixpkgs/41de143fda10e33be0f47eab2bfe08a50f234267"; # nixos-23.05
    nixpkgs-1_6.url = "github:nixos/nixpkgs/d6b3ddd253c578a7ab98f8011e59990f21dc3932"; # nixos-24.05
    nixpkgs-1_9.url = "github:nixos/nixpkgs/f5fd8730397b9951d24de58f51a5e9cb327e2a85"; # nixpkgs-unstable
    systems.url = "github:nix-systems/default";
  };

  outputs = inputs@{ self, ... }: inputs.flake-parts.lib.mkFlake
    { inherit inputs; }
    {
      imports = [
        inputs.flake-parts.flakeModules.easyOverlay
      ];

      systems = import inputs.systems;

      perSystem = { config, pkgs-1_0, pkgs-1_6, pkgs-1_9, system, ... }:
        let
          flakeConfig = import inputs.config;
        in
        {
          _module.args = {
            pkgs-1_0 = import inputs.nixpkgs-1_0 {
              inherit system;
            };
            pkgs-1_6 = import inputs.nixpkgs-1_6 {
              inherit system;
              config = flakeConfig.nixpkgs-unstable;
            };
            pkgs-1_9 = import inputs.nixpkgs-1_9 {
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
                  releases = pkgs-1_9.lib.filterAttrs (version: _: allowUnfree || versionLessThan1_6 version) versions.releases;
                  latest = pkgs-1_9.lib.filterAttrs (_: version: allowUnfree || versionLessThan1_6 version) versions.latest;
                };
              releases = import ./lib/releases.nix {
                inherit pkgs-1_0 pkgs-1_6 pkgs-1_9; custom-lib = self.lib;
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
