{ custom-lib, pkgs, pkgs-unstable }:
let
  versions = builtins.fromJSON (builtins.readFile ../versions.json);
in
builtins.mapAttrs
  (version: { hash, vendorHash }: custom-lib.buildTerraform {
    inherit pkgs pkgs-unstable version hash vendorHash;
  })
  versions
