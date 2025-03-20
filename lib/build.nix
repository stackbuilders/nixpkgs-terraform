{ pkgs
, version
, hash
, vendorHash
, silenceWarnings ? false
,
}:

pkgs.lib.warnIf (!silenceWarnings && builtins.compareVersions version "1.6.0" >= 0)
  ("allowUnfree is enabled to build version " + version)
  pkgs.mkTerraform
{
  inherit version hash vendorHash;
  patches = [ ../patches/provider-path-1_9.patch ];
}
