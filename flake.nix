{
  description = "A collection of Terraform versions that are automatically updated";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = { self, flake-parts, ... }@inputs: flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [
      inputs.flake-parts.flakeModules.easyOverlay
    ];
    systems = import inputs.systems;

    perSystem = { config, pkgs, pkgs-unstable, system, ... }: {
      _module.args = {
        pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${system};
      };

      packages =
        let
          versions = import ./lib/packages.nix { inherit pkgs pkgs-unstable; custom-lib = self.lib; };
          cycles = self.lib.groupByCycle pkgs.symlinkJoin versions;
        in
        versions // cycles;
        #   "1.0" = pkgs.symlinkJoin
        #     {
        #       name = "all-terraform-1.0";
        #       paths = [
        #         versions."1.0.1"
        #         versions."1.0.2"
        #       ];
        #     };
        #   "1.7" = pkgs.linkFarm [
        #     versions."1.7.1"
        #     versions."1.7.2"
        #   ];
        # };
        #
      overlayAttrs = {
        terraform-versions = config.packages;
      };

      devShells.default = pkgs.mkShell {
        buildInputs = [
          pkgs-unstable.black
          (pkgs-unstable.python3.withPackages (ps: [
            ps.pygithub
            ps.semver
          ]))
          pkgs-unstable.nix-prefetch
          pkgs.nodejs
          pkgs.rubyPackages.dotenv
        ];
      };
    };

    flake = {
      templates = {
        default = {
          description = "Simple nix-shell with Terraform installed via nixpkgs-terraform";
          path = ./templates/default;
        };
        devenv = {
          description = "Using nixpkgs-terraform with devenv";
          path = ./templates/devenv;
        };
      };

      lib = import ./lib // rec {
        # TODO: move this helper functions to another place
        groupByCycle = symlinkJoin: versions: builtins.mapAttrs
          (cycle: cycleVersions: symlinkJoin {
            name = "terraform-all-${cycle}";
            paths = builtins.map (version: versions.${version}) cycleVersions;
          })
          (cycleVersions versions);
        cycleVersions = versions: builtins.groupBy
          (version:
            let
              splittedVersion = builtins.splitVersion version;
            in
            builtins.concatStringsSep "." [
              (builtins.elemAt splittedVersion 0)
              (builtins.elemAt splittedVersion 1)
            ]
          )
          (builtins.attrNames versions);
      };
    };
  };
}
