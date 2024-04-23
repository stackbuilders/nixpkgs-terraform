{ pkgs, pkgs-unstable, version, hash, vendorHash }:
# https://www.hashicorp.com/blog/hashicorp-adopts-business-source-license
if builtins.compareVersions version "1.6.0" >= 0
then
# https://github.com/NixOS/nixpkgs/blob/nixpkgs-unstable/pkgs/applications/networking/cluster/terraform/default.nix
  (pkgs.lib.warn ("allowUnfree is set to true to build version " + version) pkgs-unstable.mkTerraform {
    inherit version hash vendorHash;
    patches = [ ../patches/provider-path-0_15.patch ];
  })
else
# https://github.com/NixOS/nixpkgs/blob/nixos-23.05/pkgs/applications/networking/cluster/terraform/default.nix
  (pkgs.mkTerraform {
    inherit version hash vendorHash;
    patches = [ ../patches/provider-path-0_15.patch ];
  })
