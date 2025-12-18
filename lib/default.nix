{ inputs }:

{
  mkTerraform =
    { system ? builtins.currentSystem
    , version
    , hash
    , vendorHash
    ,
    }:

    let
      pkgs =
        if builtins.compareVersions version "1.9.0" >= 0 then
          import inputs.nixpkgs
            {
              inherit system;
              config.allowUnfree = true;
            }
        else if builtins.compareVersions version "1.6.0" >= 0 then
          import inputs.nixpkgs-24_05
            {
              inherit system;
              config.allowUnfree = true;
            }
        else
          import inputs.nixpkgs-23_05 {
            inherit system;
            config.allowUnfree = false;
          };
    in

    pkgs.lib.warnIf (builtins.compareVersions version "1.6.0" >= 0)
      "allowUnfree is enabled to build version ${version}"
      pkgs.mkTerraform
      {
        inherit version hash vendorHash;
        patches =
          if builtins.compareVersions version "1.14.0" >= 0 then
            [ ../patches/provider-path-1_14.patch ]
          else if builtins.compareVersions version "1.9.0" >= 0 then
            [ ../patches/provider-path-1_9.patch ]
          else
            [ ../patches/provider-path-0_15.patch ];
        passthru.plugins = removeAttrs pkgs.terraform-providers [
          "override"
          "overrideDerivation"
          "recurseForDerivations"
        ];
      };

  mkOpenTofu =
    { system ? builtins.currentSystem
    , version
    , hash
    , vendorHash
    ,
    }:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    in
    pkgs.opentofu.overrideAttrs {
      inherit version vendorHash;
      src = pkgs.fetchFromGitHub {
        inherit hash;
        owner = "opentofu";
        repo = "opentofu";
        tag = "v${version}";
      };
    };

  mkReleases =
    { system
    , releases
    , namePrefix
    , mkRelease
    ,
    }:
    inputs.nixpkgs.lib.mapAttrs'
      (
        version:
        { hash, vendorHash }:
        {
          name = "${namePrefix}-${version}";
          value = mkRelease {
            inherit
              system
              version
              hash
              vendorHash
              ;
          };
        }
      )
      releases;
}
