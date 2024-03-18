{ custom-lib, pkgs, pkgs-unstable }:
let
  json = builtins.fromJSON (builtins.readFile ../versions.json);
  versions = json.releases;
  latestVersions = json.latest;
in
builtins.mapAttrs
  (version: { hash, vendorHash }: custom-lib.buildTerraform {
    inherit pkgs pkgs-unstable version hash vendorHash;
  })
  (versions // builtins.mapAttrs (cycle: version: versions.${version}) latestVersions)
