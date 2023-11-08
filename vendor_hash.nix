{ version, hash }: { sha256 }:
((builtins.getFlake (toString ./.)).lib.buildTerraform {
  inherit version hash;
  system = builtins.currentSystem;
  vendorHash = "";
}).go-modules.overrideAttrs (_: { vendorSha256 = sha256; })
