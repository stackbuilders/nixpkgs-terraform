{ version }: { sha256 }:
((builtins.getFlake (toString ./.)).lib.packageFromVersion {
  inherit version;
  system = builtins.currentSystem;
}).go-modules.overrideAttrs (_: { vendorSha256 = sha256; })
