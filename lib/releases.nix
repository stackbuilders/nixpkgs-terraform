{ custom-lib, pkgs-23_05, pkgs-24_05, pkgs, releases, silenceWarnings }:
builtins.mapAttrs
  (version: { hash, vendorHash }: custom-lib.buildTerraform {
    inherit pkgs-23_05 pkgs-24_05 pkgs version hash vendorHash silenceWarnings;
  })
  releases
