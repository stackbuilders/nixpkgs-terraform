{ version, hash }: { sha256 }:
let
  flake = builtins.getFlake (toString ./.);
  system = builtins.currentSystem;

  pkgs = import flake.inputs.nixpkgs { inherit system; };
  pkgs-unstable = import flake.inputs.nixpkgs-unstable { inherit system; };

  terraform = flake.lib.buildTerraform {
    inherit pkgs pkgs-unstable version hash;
    vendorHash = sha256;
  };
in
  terraform.goModules or terraform.go-modules
