{ buildTerraform
,
}:

{ allPkgs
, releases
, silenceWarnings
,
}:

let
  pkgsByVersion =
    version:
    if builtins.compareVersions version "1.9.0" >= 0 then
      allPkgs."1.9"
    else if builtins.compareVersions version "1.6.0" >= 0 then
      allPkgs."1.6"
    else
      allPkgs."1.0";
in
builtins.mapAttrs
  (
    version:
    { hash, vendorHash }:
    buildTerraform {
      inherit
        version
        hash
        vendorHash
        silenceWarnings
        ;
      pkgs = pkgsByVersion version;
    }
  )
  releases
