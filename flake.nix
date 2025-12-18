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
    inputs@{ self
    , nixpkgs
    , systems
    , ...
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs (import systems);

      terraformVersions = builtins.fromJSON (builtins.readFile ./terraform.json);

      terraformReleases = forAllSystems (
        system:
        self.lib.mkReleases {
          inherit system;
          releases = terraformVersions.releases;
          namePrefix = "terraform";
          mkRelease = self.lib.mkTerraform;
        }
      );

      terraformAliases = forAllSystems (
        system:
        nixpkgs.lib.mapAttrs'
          (cycle: version: {
            name = "terraform-${cycle}";
            value = terraformReleases.${system}."terraform-${version}";
          })
          terraformVersions.aliases
      );

      deprecatedReleases = forAllSystems (
        system:
        builtins.mapAttrs
          (
            version: _:
              builtins.warn "package \"${version}\" is deprecated; use \"terraform-${version}\" instead"
                terraformReleases.${system}."terraform-${version}"
          )
          terraformVersions.releases
      );

      deprecatedAliases = forAllSystems (
        system:
        builtins.mapAttrs
          (
            cycle: _:
              builtins.warn "package \"${cycle}\" is deprecated; use \"terraform-${cycle}\" instead"
                terraformAliases.${system}."terraform-${cycle}"
          )
          terraformVersions.aliases
      );
    in
    {
      packages = forAllSystems (
        system:
        terraformReleases.${system}
        // terraformAliases.${system}
        // deprecatedReleases.${system}
        // deprecatedAliases.${system}
      );

      checks = terraformAliases;

      overlays = {
        default =
          final: prev:
          {
            terraform-versions =
              builtins.warn
                "\"terraform-versions\" packages are deprecated; use the prefixed \"terraform-\" packages instead"
                self.packages.${prev.system};
          }
          // self.overlays.terraform final prev;
        terraform = final: prev: terraformReleases.${prev.system} // terraformAliases.${prev.system};
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
