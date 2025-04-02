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
      forAllSystems = nixpkgs.lib.genAttrs (import systems);

      # Import nixpkgs for each supported system
      pkgsFor = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
      );

      pkgs-1_0For = forAllSystems (
        system:
        import nixpkgs-1_0 {
          inherit system;
        }
      );

      pkgs-1_6For = forAllSystems (
        system:
        import nixpkgs-1_6 {
          inherit system;
          config.allowUnfree = true;
        }
      );

      # Create packages for each system
      packagesFor = forAllSystems (
        system:
        let
          versions = builtins.fromJSON (builtins.readFile ./versions.json);
          releases = self.lib.mkPackages {
            allPkgs = {
              "1.0" = pkgs-1_0For.${system};
              "1.6" = pkgs-1_6For.${system};
              "1.9" = pkgsFor.${system};
            };
            releases = versions.releases;
          };
          latestVersions = builtins.mapAttrs (_cycle: version: releases.${version}) versions.latest;
        in
        releases // latestVersions
      );
    in
    {
      packages = packagesFor;

      checks = packagesFor;

      overlays.default = final: prev: {
        terraform-versions = packagesFor.${prev.system};
      };

      lib = import ./lib;

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
