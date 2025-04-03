{ __buildTerraformFor }:

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
  releases
