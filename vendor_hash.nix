{ version, hash }: { sha256 }:
((builtins.getFlake (toString ./.)).lib.buildTerraform {
  inherit version hash;
  system = builtins.currentSystem;
  vendorHash = sha256;
}).goModules
