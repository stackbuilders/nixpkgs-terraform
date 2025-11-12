{
  description = "A collection of Terraform versions that are automatically updated";

  inputs = {
    # INFO: Channel used for building versions from 1.0 up to 1.5
    nixpkgs-23_05.url = "github:nixos/nixpkgs/nixos-23.05-small";
    # INFO: Channel used for building versions from 1.6 up to 1.8
    nixpkgs-24_05.url = "github:nixos/nixpkgs/nixos-24.05-small";
    # INFO: Channel used for building versions from 1.9 onwards
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs@{ nixpkgs
    , self
    , systems
    , ...
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs (import systems);

      terraformVersions = builtins.fromJSON (builtins.readFile ./versions.json);

      terraformReleases = forAllSystems (
        system:
        self.lib.mkReleases {
          inherit system;
          mkRelease = self.lib.mkTerraform;
          releases = terraformVersions.releases;
        }
      );

      terraformAliases = forAllSystems (
        system:
        builtins.mapAttrs
          (
            _cycle: version: terraformReleases.${system}.${version}
          )
          terraformVersions.aliases
      );
    in
    {
      packages = forAllSystems (system: terraformReleases.${system} // terraformAliases.${system});

      checks = terraformAliases;

      overlays.default = final: prev: {
        terraform-versions = self.packages.${prev.system};
      };

      lib = import ./lib { inherit inputs; };

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
