rec {
  buildTerraform = import ./build.nix;
  buildTerraformFor = import ./build-for.nix { inherit buildTerraform; };
  mkPackages = import ./packages.nix { inherit buildTerraformFor; };
}
