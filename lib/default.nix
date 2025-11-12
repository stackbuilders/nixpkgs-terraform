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
          if builtins.compareVersions version "1.9.0" >= 0 then
            [ ../patches/provider-path-1_9.patch ]
          else
            [ ../patches/provider-path-0_15.patch ];
        passthru.plugins = removeAttrs pkgs.terraform-providers [
          "override"
          "overrideDerivation"
          "recurseForDerivations"
        ];
      };

  mkReleases =
    { system
    , mkRelease
    , releases
    ,
    }:
    builtins.mapAttrs
      (
        version:
        { hash, vendorHash }:
        mkRelease {
          inherit
            system
            version
            hash
            vendorHash
            ;
        }
      )
      releases;
}
