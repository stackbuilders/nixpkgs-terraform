{ version, hash }: { sha256 }:
let
  package = ((builtins.getFlake (toString ./.)).lib.buildTerraform {
    inherit version hash;
    system = builtins.currentSystem;
    vendorHash = sha256;
  });
in
  package.goModules or package.go-modules
