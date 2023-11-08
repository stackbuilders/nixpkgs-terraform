{
  description = "TODO";

  inputs = {
    flake-utils.inputs.systems.follows = "systems";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    systems.url = "github:nix-systems/default";
  };

  outputs = { self, flake-utils, nixpkgs-unstable, nixpkgs, ... }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
          versions = builtins.fromJSON (builtins.readFile ./versions.json);
          buildTerraform = { version, hash, vendorHash }:
            # https://www.hashicorp.com/blog/hashicorp-adopts-business-source-license
            if builtins.compareVersions version "1.6.0" >= 0
            then
            # https://github.com/NixOS/nixpkgs/blob/nixpkgs-unstable/pkgs/applications/networking/cluster/terraform/default.nix
              pkgs-unstable.mkTerraform
                {
                  inherit version hash vendorHash;
                  patches = [ "${nixpkgs-unstable}/pkgs/applications/networking/cluster/terraform/provider-path-0_15.patch" ];
                }
            else
            # https://github.com/NixOS/nixpkgs/blob/nixos-23.05/pkgs/applications/networking/cluster/terraform/default.nix
              pkgs.mkTerraform {
                inherit version hash vendorHash;
                patches = [ "${nixpkgs}/pkgs/applications/networking/cluster/terraform/provider-path-0_15.patch" ];
              };
        in
        {
          # https://github.com/NixOS/nix/issues/7165
          checks = self.packages.${system};
          packages = builtins.listToAttrs
            (builtins.map
              (version: {
                name = version;
                value = buildTerraform {
                  inherit version;
                  inherit (versions.${version}) hash vendorHash;
                };
              })
              (builtins.attrNames versions));
          devShell = pkgs.mkShell {
            buildInputs = [
              pkgs.python3
              pkgs.python3Packages.pygithub
              pkgs.python3Packages.semver
              pkgs.nix-prefetch
              pkgs.nix-prefetch-git
            ];
          };
        }) // {
      lib.packageFromVersion = { system, version }: self.packages.${system}.${version};
    };
}
