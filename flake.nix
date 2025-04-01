{
  description = "A collection of Terraform versions that are automatically updated";

  inputs = {
    nixpkgs-1_0.url = "github:nixos/nixpkgs/41de143fda10e33be0f47eab2bfe08a50f234267"; # nixos-23.05
    nixpkgs-1_6.url = "github:nixos/nixpkgs/d6b3ddd253c578a7ab98f8011e59990f21dc3932"; # nixos-24.05
    nixpkgs.url = "github:nixos/nixpkgs/af51545ec9a44eadf3fe3547610a5cdd882bc34e"; # nixpkgs-unstable
    systems.url = "github:nix-systems/default";
  };

  outputs =
    { self
    , nixpkgs
    , nixpkgs-1_0
    , nixpkgs-1_6
    , systems
    , ...
    }:
    let
      supportedSystems = import systems;
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Import nixpkgs for each supported system
      nixpkgsFor = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
      );

      nixpkgs1_0For = forAllSystems (
        system:
        import nixpkgs-1_0 {
          inherit system;
        }
      );

      nixpkgs1_6For = forAllSystems (
        system:
        import nixpkgs-1_6 {
          inherit system;
          config.allowUnfree = true;
        }
      );

      # Library functions
      lib = import ./lib;

      # Create overlay
      overlayFor = system: final: prev: {
        terraform-versions = packagesFor.${system};
      };

      # Create packages for each system
      packagesFor = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
          pkgs-1_0 = nixpkgs1_0For.${system};
          pkgs-1_6 = nixpkgs1_6For.${system};

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
        releases // latestVersions
      );

      # Create checks for each system
      checksFor = forAllSystems (system: packagesFor.${system});
    in
    {
      packages = packagesFor;

      checks = checksFor;

      overlays = forAllSystems (system: overlayFor system);

      lib = lib;

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
    };
}
