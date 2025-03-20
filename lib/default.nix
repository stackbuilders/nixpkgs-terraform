rec {
  buildTerraform = import ./build.nix;
  mkPackages = import ./packages.nix { inherit buildTerraform; };
}
