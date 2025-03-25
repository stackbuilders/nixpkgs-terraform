{
  description = "A collection of Terraform versions that are automatically updated";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs-1_0.url = "github:nixos/nixpkgs/41de143fda10e33be0f47eab2bfe08a50f234267"; # nixos-23.05
    nixpkgs-1_6.url = "github:nixos/nixpkgs/d6b3ddd253c578a7ab98f8011e59990f21dc3932"; # nixos-24.05
    nixpkgs.url = "github:nixos/nixpkgs/af51545ec9a44eadf3fe3547610a5cdd882bc34e"; # nixpkgs-unstable
    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs@{ self, ... }:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.flake-parts.flakeModules.easyOverlay
      ];

      systems = import inputs.systems;

      perSystem =
        { config
        , pkgs
        , pkgs-1_0
        , pkgs-1_6
        , system
        , ...
        }:

        {
          _module.args = {
            pkgs-1_0 = import inputs.nixpkgs-1_0 {
              inherit system;
            };
            pkgs-1_6 = import inputs.nixpkgs-1_6 {
              inherit system;
              config.allowUnfree = true;
            };
            pkgs = import inputs.nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
          };

          checks = config.packages;

          packages =
            let
              versions = builtins.fromJSON (builtins.readFile ./versions.json);
              releases = self.lib.mkPackages {
                allPkgs = {
                  "1.0" = pkgs-1_0;
                  "1.6" = pkgs-1_6;
                  "1.9" = pkgs;
                };
                releases = versions.releases;
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
