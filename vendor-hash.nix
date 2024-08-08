{ version, hash }: { sha256 }:
let
  flake = builtins.getFlake (toString ./.);
  system = builtins.currentSystem;

  pkgs-1_0 = flake.inputs.nixpkgs-1_0.legacyPackages.${system};
  pkgs-1_6 = flake.inputs.nixpkgs-1_6.legacyPackages.${system};
  pkgs-1_9 = flake.inputs.nixpkgs-1_9.legacyPackages.${system};

  terraform = flake.lib.buildTerraform {
    inherit pkgs-1_0 pkgs-1_6 pkgs-1_9 version hash;
    vendorHash = sha256;
  };
in
  terraform.goModules or terraform.go-modules
