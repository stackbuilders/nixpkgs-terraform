# nixpkgs-terraform

[![Build](https://github.com/stackbuilders/nixpkgs-terraform/actions/workflows/build.yml/badge.svg)](https://github.com/stackbuilders/nixpkgs-terraform/actions/workflows/build.yml)
[![Update](https://github.com/stackbuilders/nixpkgs-terraform/actions/workflows/update.yml/badge.svg)](https://github.com/stackbuilders/nixpkgs-terraform/actions/workflows/update.yml)
[![Release](https://github.com/stackbuilders/nixpkgs-terraform/actions/workflows/release.yml/badge.svg)](https://github.com/stackbuilders/nixpkgs-terraform/actions/workflows/release.yml)
[![Publish](https://github.com/stackbuilders/nixpkgs-terraform/actions/workflows/publish.yml/badge.svg)](https://github.com/stackbuilders/nixpkgs-terraform/actions/workflows/publish.yml)

[![FlakeHub](https://img.shields.io/endpoint?url=https://flakehub.com/f/stackbuilders/nixpkgs-terraform/badge)](https://flakehub.com/flake/stackbuilders/nixpkgs-terraform)
[![flakestry.dev](https://flakestry.dev/api/badge/flake/github/stackbuilders/nixpkgs-terraform)](https://flakestry.dev/flake/github/stackbuilders/nixpkgs-terraform)

This [flake](https://nixos.wiki/wiki/Flakes) exposes a collection of Terraform
[versions](versions.json) as Nix packages, starting with version 1.0.0. The
packages provided can be used for creating reproducible development
environments using a [nix-shell] or [devenv](https://devenv.sh).

## How it works

This flake provides a set of Terraform versions in the form of:

```nix
nixpkgs-terraform.packages.${system}.${version}
```

Terraform versions are kept up to date via a weekly scheduled [CI
workflow](.github/workflows/update.yml).

## Install

The quickest way to get started with an empty project is to scaffold a new
project using the [default](templates/default) template:

```sh
nix flake init -t github:stackbuilders/nixpkgs-terraform
```

Alternatively, add the following input to an existing `flake.nix` file:

```nix
inputs.nixpkgs-terraform.url = "github:stackbuilders/nixpkgs-terraform";
```

Some extra inputs are required for the example provided in the [Usage](#usage)
section:

```nix
inputs.flake-utils.url = "github:numtide/flake-utils";
inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
```

### Binary Cache

It is highly recommended to set up the
[nixpkgs-terraform](https://nixpkgs-terraform.cachix.org) binary cache to
download pre-compiled Terraform binaries rather than compiling them locally for
a better user experience. Add the following configuration to the `flake.nix`
file:

```nix
nixConfig = {
  extra-substituters = "https://nixpkgs-terraform.cachix.org";
  extra-trusted-public-keys = "nixpkgs-terraform.cachix.org-1:8Sit092rIdAVENA3ZVeH9hzSiqI/jng6JiCrQ1Dmusw=";
};
```

## Usage

After configuring the inputs from the [Install](#install) section, a common use
case for this flake could be spawning a [nix-shell] with a specific Terraform
version, which could be accomplished by extracting the desired version from
`nixpkgs-terraform.packages` or by using an overlay as follows:

#### As a package

```nix
outputs = { self, flake-utils, nixpkgs-terraform, nixpkgs }:
  flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      terraform = nixpkgs-terraform.packages.${system}."1.7.3";
    in
    {
      devShells.default = pkgs.mkShell {
        buildInputs = [ terraform ];
      };
    });
```

#### As an overlay

```nix
outputs = { self, flake-utils, nixpkgs-terraform, nixpkgs }:
  flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ nixpkgs-terraform.overlays.default ];
      };
    in
    {
      devShells.default = pkgs.mkShell {
        buildInputs = [ pkgs.terraform-versions."1.7.3" ];
      };
    });
```

Start a new [nix-shell] with Terraform in scope by running the following
command:

```sh
env NIXPKGS_ALLOW_UNFREE=1 nix develop --impure
```

**Note:** Due to Hashicorp’s most recent [license
change](https://www.hashicorp.com/blog/hashicorp-adopts-business-source-license),
the `NIXPKGS_ALLOW_UNFREE` flag is required for Terraform versions `>= 1.6.0`,
`nix develop` should work out of the box for older versions.

### Templates

This flake provides the following templates:

- [default](templates/default) - Simple nix-shell with Terraform installed via
  nixpkgs-terraform.
- [devenv](templates/devenv) - Using nixpkgs-terraform with devenv.
- [terranix](templates/terranix) - Using nixpkgs-terraform with terranix.

Run the following command to scaffold a new project using a template:

```sh
nix flake init -t github:stackbuilders/nixpkgs-terraform#<template>
```

**Note:** Replace `<template>` with one of the templates listed above.

## Inspired By

The current project structure as well as some components of the CI workflow are
heavily inspired by the following projects:

- [nixpkgs-python](https://github.com/cachix/nixpkgs-python) - All Python
  versions, kept up-to-date on hourly basis using Nix.
- [nixpkgs-ruby](https://github.com/bobvanderlinden/nixpkgs-ruby) - A Nix
  repository with all Ruby versions being kept up-to-date automatically.

## License

MIT, see [the LICENSE file](LICENSE).

## Contributing

Do you want to contribute to this project? Please take a look at our
[contributing guideline](docs/CONTRIBUTING.md) to know how you can help us
build it.

Aside from the contribution guidelines outlined above, this project uses
[semantic-release] to automate version management; thus, we encourage
contributors to follow the commit conventions outlined
[here](https://semantic-release.gitbook.io/semantic-release/#commit-message-format)
to make it easier for maintainers to release new changes.

---

<img src="https://www.stackbuilders.com/media/images/Sb-supports.original.png"
alt="Stack Builders" width="50%"></img>  
[Check out our libraries](https://github.com/stackbuilders/) | [Join our
team](https://www.stackbuilders.com/join-us/)

[nix-shell]: https://nixos.wiki/wiki/Development_environment_with_nix-shell
[semantic-release]: https://semantic-release.gitbook.io/semantic-release/
