{ version, hash }: { sha256 }:
let
  terraform = ((builtins.getFlake (toString ./.)).lib.buildTerraform {
    inherit version hash;
    system = builtins.currentSystem;
    vendorHash = sha256;
  });
in
  terraform.goModules or terraform.go-modules
