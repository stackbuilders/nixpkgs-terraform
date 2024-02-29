{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs-terraform.url = "github:stackbuilders/nixpkgs-terraform";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    terranix.url = "github:terranix/terranix";
  };

  nixConfig = {
    extra-substituters = "https://nixpkgs-terraform.cachix.org";
    extra-trusted-public-keys = "nixpkgs-terraform.cachix.org-1:8Sit092rIdAVENA3ZVeH9hzSiqI/jng6JiCrQ1Dmusw=";
  };

  outputs = { self, flake-utils, nixpkgs-terraform, nixpkgs, terranix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        terraform = nixpkgs-terraform.packages.${system}."1.7.4";
      in
      {
        defaultPackage = terranix.lib.terranixConfiguration {
          inherit system;
          modules = [ ./config.nix ];
        };
        devShells.default = pkgs.mkShell {
          buildInputs = [ terraform pkgs.terranix];
        };
      });
}
