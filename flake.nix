{
  description = "TODO";

  inputs = {
    flake-utils.inputs.systems.follows = "systems";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs-23_05.url = "github:nixos/nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs = { self, flake-utils, nixpkgs-23_05, nixpkgs-unstable, ... }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs-23_05 = nixpkgs-23_05.legacyPackages.${system};
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
              pkgs-23_05.mkTerraform {
                inherit version hash vendorHash;
                patches = [ "${nixpkgs-23_05}/pkgs/applications/networking/cluster/terraform/provider-path-0_15.patch" ];
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
          devShell = pkgs-23_05.mkShell {
            buildInputs = [
              pkgs-23_05.python3
              pkgs-23_05.python3Packages.pygithub
              pkgs-23_05.python3Packages.semver
              pkgs-23_05.nix-prefetch
              pkgs-23_05.nix-prefetch-git
            ];
          };
        }) // {
      lib.packageFromVersion = { system, version }: self.packages.${system}.${version};
    };
}
