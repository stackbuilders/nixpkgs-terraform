{ pkgs, ... }:

{
  dotenv.enable = true;

  packages = [
    pkgs.nix-prefetch
    pkgs.semantic-release
    pkgs.cobra-cli
  ];

  languages.go.enable = true;

  scripts.update-versions-py.exec = # We should remove this too when ready to merge
    let
      python = pkgs.python3.withPackages (ps: [
        ps.pygithub
        ps.semver
      ]);
    in
    ''
      ${python}/bin/python update-versions.py
    '';

  pre-commit.hooks.black.enable = true;
  pre-commit.hooks.nixpkgs-fmt.enable = true;
}
