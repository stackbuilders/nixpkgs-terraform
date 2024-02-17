{ version, hash }: { sha256 }:
let
  flake = builtins.getFlake (toString ./.);
  system = builtins.currentSystem;

  pkgs = flake.inputs.nixpkgs.legacyPackages.${system};
  pkgs-unstable = flake.inputs.nixpkgs-unstable.legacyPackages.${system};

  terraform = flake.lib.buildTerraform {
    inherit pkgs pkgs-unstable version hash;
    vendorHash = sha256;
  };
in
  terraform.goModules or terraform.go-modules
