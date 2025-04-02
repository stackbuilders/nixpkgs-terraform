{ version, hash }: { sha256 }:
let
  flake = builtins.getFlake (toString ./.);
  system = builtins.currentSystem;

  pkgs-1_0 = flake.inputs.nixpkgs-1_0.legacyPackages.${system};
  pkgs-1_6 = flake.inputs.nixpkgs-1_6.legacyPackages.${system};
  pkgs = flake.inputs.nixpkgs.legacyPackages.${system};

  finalPkgs =
    if builtins.compareVersions version "1.9.0" >= 0 then
      pkgs
    else if builtins.compareVersions version "1.6.0" >= 0 then
      pkgs-1_6
    else
      pkgs-1_0;

  terraform = flake.lib.buildTerraform {
    inherit version hash;
    pkgs = finalPkgs;
    vendorHash = sha256;
  };
in
  terraform.goModules or terraform.go-modules
