{ buildTerraform }:

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
}
