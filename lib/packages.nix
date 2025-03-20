{ buildTerraform
,
}:

{ allPkgs
, releases
, silenceWarnings
,
}:

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
      pkgs =
        if builtins.compareVersions version "1.9.0" >= 0 then
          allPkgs."1.9"
        else if builtins.compareVersions version "1.6.0" >= 0 then
          allPkgs."1.6"
        else
          allPkgs."1.0";
    }
  )
  releases
