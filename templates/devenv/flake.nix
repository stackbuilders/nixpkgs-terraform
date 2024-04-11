{
  inputs = {
    devenv.url = "github:cachix/devenv";
    nixpkgs-terraform.url = "github:stackbuilders/nixpkgs-terraform";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
  };

  # nixConfig = {
  #   extra-substituters = "https://nixpkgs-terraform.cachix.org";
  #   extra-trusted-public-keys = "nixpkgs-terraform.cachix.org-1:8Sit092rIdAVENA3ZVeH9hzSiqI/jng6JiCrQ1Dmusw=";
  # };

  outputs = inputs@{ self, devenv, nixpkgs-terraform, nixpkgs, systems }:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      devShells = forEachSystem
        (system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          {
            default = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                ({ pkgs, config, ... }: {
                  cachix.pull = [ "nixpkgs-terraform" "devenv" ];

                  languages.terraform.enable = true;
                  languages.terraform.version = "1.7.4";
                })
              ];
            };
          });
    };
}
