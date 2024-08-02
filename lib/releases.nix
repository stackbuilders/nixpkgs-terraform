{ custom-lib, pkgs-1_0, pkgs-1_6, pkgs-1_9, releases, silenceWarnings }:
builtins.mapAttrs
  (version: { hash, vendorHash }: custom-lib.buildTerraform {
    inherit pkgs-1_0 pkgs-1_6 pkgs-1_9 version hash vendorHash silenceWarnings;
  })
  releases
