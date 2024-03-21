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
        pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${system};
      };

      checks = config.packages;

      packages =
        let
          versions = import ./lib/packages.nix { inherit pkgs pkgs-unstable; custom-lib = self.lib; };
          linkPackagesByCycle = versionsPerCycle: builtins.mapAttrs
            (cycle: cycleVersions: pkgs.symlinkJoin {
              name = "terraform-${cycle}";
              paths = builtins.map (version: versions.${version}) cycleVersions;
            })
            versionsPerCycle;
          groupVersionsByCycle = versions: builtins.groupBy
            (version:
              let
                splittedVersion = builtins.splitVersion version;
              in
              "all-" + (builtins.concatStringsSep "." [
                (builtins.elemAt splittedVersion 0)
                (builtins.elemAt splittedVersion 1)
              ])
            )
            (builtins.attrNames versions);
          cycles = linkPackagesByCycle (groupVersionsByCycle versions);
        in
        versions // cycles;

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
