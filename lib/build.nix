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
}
