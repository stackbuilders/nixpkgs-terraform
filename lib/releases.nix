{ custom-lib, pkgs, pkgs-unstable, releases, silenceWarnings }:
builtins.mapAttrs
  (version: { hash, vendorHash }: custom-lib.buildTerraform {
    inherit pkgs pkgs-unstable version hash vendorHash silenceWarnings;
  })
  releases
