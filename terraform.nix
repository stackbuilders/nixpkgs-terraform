{ version, hash }:

{ sha256 }:

let
  terraform = (builtins.getFlake (toString ./.)).lib.mkTerraform {
    inherit version hash;
    vendorHash = sha256;
  };
in
  terraform.goModules or terraform.go-modules
