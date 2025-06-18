{
  inputs = {
    nixpkgs-terraform-providers-bin.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-terraform-providers-bin.url = "github:nix-community/nixpkgs-terraform-providers-bin";
    nixpkgs-terraform.url = "github:stackbuilders/nixpkgs-terraform";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    { nixpkgs
    , nixpkgs-terraform
    , nixpkgs-terraform-providers-bin
    , systems
    , ...
    }:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      devShells = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          terraform = nixpkgs-terraform.packages.${system}."1.12";
          terraform-providers-bin = nixpkgs-terraform-providers-bin.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
              (terraform.withPlugins (p: [
                p.null
                p.random
                terraform-providers-bin.providers.hashicorp.nomad
              ]))
            ];
          };
        }
      );
    };
}
