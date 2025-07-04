{
  description = "A collection of Terraform versions that are automatically updated";

  inputs = {
    # INFO: Channel used for building versions from 1.0 up to 1.5
    nixpkgs-1_0.url = "github:nixos/nixpkgs/nixos-23.05-small";
    # INFO: Channel used for building versions from 1.6 up to 1.8
    nixpkgs-1_6.url = "github:nixos/nixpkgs/nixos-24.05-small";
    # INFO: Channel used for building versions from 1.9 onwards
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs@{ self
    , nixpkgs
    , systems
    , ...
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs (import systems);

      versions = builtins.fromJSON (builtins.readFile ./versions.json);

      # Create packages for each system
      releasesFor = forAllSystems (
        system:
        self.lib.__mkPackages {
          inherit inputs system;
          releases = versions.releases;
        }
      );

      latestFor = forAllSystems (
        system: builtins.mapAttrs (_cycle: version: releasesFor.${system}.${version}) versions.latest
      );
    in
    {
      packages = forAllSystems (system: releasesFor.${system} // latestFor.${system});

      checks = latestFor;

      overlays.default = final: prev: {
        terraform-versions = self.packages.${prev.system};
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
        nixpkgs-terraform-providers-bin = {
          description = "Using nixpkgs-terraform with nixpkgs-terraform-providers-bin";
          path = ./templates/nixpkgs-terraform-providers-bin;
        };
        terranix = {
          description = "Using nixpkgs-terraform with terranix";
          path = ./templates/terranix;
        };
      };
    };
}
