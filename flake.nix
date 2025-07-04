{
  description = "A collection of Terraform versions that are automatically updated";

  inputs = {
    nixpkgs-1_0.url = "github:nixos/nixpkgs/41de143fda10e33be0f47eab2bfe08a50f234267"; # nixos-23.05
    nixpkgs-1_6.url = "github:nixos/nixpkgs/d6b3ddd253c578a7ab98f8011e59990f21dc3932"; # nixos-24.05
    nixpkgs.url = "github:nixos/nixpkgs/2f9173bde1d3fbf1ad26ff6d52f952f9e9da52ea"; # nixpkgs-unstable
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
