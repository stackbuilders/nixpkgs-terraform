let
  buildTerraform =
    { pkgs
    , version
    , hash
    , vendorHash
    ,
    }:

    pkgs.lib.warnIf (builtins.compareVersions version "1.6.0" >= 0)
      ("allowUnfree is enabled to build version " + version)
      pkgs.mkTerraform
      {
        inherit version hash vendorHash;
        patches =
          if builtins.compareVersions version "1.9.0" >= 0 then
            [ ../patches/provider-path-1_9.patch ]
          else
            [ ../patches/provider-path-0_15.patch ];
        passthru.plugins = builtins.removeAttrs pkgs.terraform-providers [
          "override"
          "overrideDerivation"
          "recurseForDerivations"
        ];
      };

  __buildTerraformFor =
    { inputs
    , system
    , version
    , hash
    , vendorHash
    ,
    }:

    let
      pkgs-1_9 = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      pkgs-1_6 = import inputs.nixpkgs-1_6 {
        inherit system;
        config.allowUnfree = true;
      };
      pkgs-1_0 = import inputs.nixpkgs-1_0 { inherit system; };
    in
    buildTerraform {
      inherit
        version
        hash
        vendorHash
        ;
      pkgs =
        if builtins.compareVersions version "1.9.0" >= 0 then
          pkgs-1_9
        else if builtins.compareVersions version "1.6.0" >= 0 then
          pkgs-1_6
        else
          pkgs-1_0;
    };

  __mkPackages =
    { inputs
    , system
    , releases
    ,
    }:

    builtins.mapAttrs
      (
        version:
        { hash, vendorHash }:
        __buildTerraformFor {
          inherit
            inputs
            system
            version
            hash
            vendorHash
            ;
        }
      )
      releases;
in
{
  inherit buildTerraform __buildTerraformFor __mkPackages;
}
