{ pkgs, pkgs-unstable, version, hash, vendorHash, silenceWarnings ? false }:
# https://www.hashicorp.com/blog/hashicorp-adopts-business-source-license
if builtins.compareVersions version "1.9.0" >= 0
then
# https://github.com/NixOS/nixpkgs/blob/nixpkgs-unstable/pkgs/applications/networking/cluster/terraform/default.nix
  (pkgs.lib.warnIf (! silenceWarnings) ("allowUnfree is enabled to build version " + version) pkgs-unstable.mkTerraform
  {
    inherit version hash vendorHash;
    patches = [ ../patches/provider-path-1_9.patch ];
  })
else if builtins.compareVersions version "1.6.0" >= 0
then
# https://github.com/NixOS/nixpkgs/blob/nixpkgs-unstable/pkgs/applications/networking/cluster/terraform/default.nix
  (pkgs.lib.warnIf (! silenceWarnings) ("allowUnfree is enabled to build version " + version) pkgs-unstable.mkTerraform
  {
    inherit version hash vendorHash;
    patches = [ ../patches/provider-path-0_15.patch ];
  })
else
# https://github.com/NixOS/nixpkgs/blob/nixos-23.05/pkgs/applications/networking/cluster/terraform/default.nix
  (pkgs.mkTerraform {
    inherit version hash vendorHash;
    patches = [ ../patches/provider-path-0_15.patch ];
  })
