rec {
  buildTerraform = import ./build.nix;
  __buildTerraformFor = import ./build-for.nix { inherit buildTerraform; };
  __mkPackages = import ./packages.nix { inherit __buildTerraformFor; };
}
