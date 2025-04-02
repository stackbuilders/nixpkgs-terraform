{ version, hash }:
{ sha256 }:
let
  flake = builtins.getFlake (toString ./.);
  system = builtins.currentSystem;

  terraform = flake.lib.buildTerraformFor {
    inherit
      system
      version
      hash
      ;
    inputs = flake.inputs;
    vendorHash = sha256;
  };
in
terraform.goModules or terraform.go-modules
