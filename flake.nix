{
  description = "TODO";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs = { self, flake-utils, nixpkgs, ... }:
    let
      mkPackageName = version: "terraform-${builtins.concatStringsSep "_" (builtins.splitVersion version)}";
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          versions = builtins.fromJSON (builtins.readFile ./versions.json);
          # https://github.com/NixOS/nixpkgs/blob/nixpkgs-unstable/pkgs/applications/networking/cluster/terraform/default.nix
          mkTerraform = { version, hash, vendorHash }: pkgs.mkTerraform {
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
                name = mkPackageName version;
                value = mkTerraform {
                  inherit version;
                  inherit (versions.${version}) hash vendorHash;
                };
              })
              (builtins.attrNames versions));
          #   templates.default = {
          #     description = "TODO";
          #     path = ./templates/default;
          #   };
        }) // {
      lib.packageFromVersion = { system, version }: self.packages.${system}.${mkPackageName version};
    };
}
