{ buildTerraformFor }:

{ inputs
, system
, releases
,
}:

builtins.mapAttrs
  (
    version:
    { hash, vendorHash }:
    buildTerraformFor {
      inherit
        inputs
        system
        version
        hash
        vendorHash
        ;
    }
  )
  releases
