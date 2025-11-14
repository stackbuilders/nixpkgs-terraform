{ version, hash }:

{ sha256 }:

let
  opentofu = (builtins.getFlake (toString ./.)).lib.mkOpentofu {
    inherit version hash;
    vendorHash = sha256;
  };
in
  opentofu.goModules or opentofu.go-modules
