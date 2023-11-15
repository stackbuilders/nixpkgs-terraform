# nixpkgs-terraform

[![CI](https://github.com/stackbuilders/nixpkgs-terraform/actions/workflows/ci.yml/badge.svg)](https://github.com/stackbuilders/nixpkgs-terraform/actions/workflows/ci.yml)
[![Update](https://github.com/stackbuilders/nixpkgs-terraform/actions/workflows/update.yml/badge.svg)](https://github.com/stackbuilders/nixpkgs-terraform/actions/workflows/update.yml)

A collection of Terraform versions that are automatically updated.

## How it works

TODO: Quick overview of `nixpkgs-terraform.packages.${system}.${version}`

**Available versions**

Terraform versions greater than 1.5.0 are kept up to date via a weekly
scheduled [CI workflow](.github/workflows/update.yml).

**Inspired by**

The current project structure as well as some components of the CI workflow are
heavily inspired by the following projects:

- [nixpkgs-python](https://github.com/cachix/nixpkgs-python)
- [nixpkgs-ruby](https://github.com/bobvanderlinden/nixpkgs-ruby)

## Install

Add the following input to `flake.nix`:

```nix
inputs.nixpkgs-terraform.url = "github:stackbuilders/nixpkgs-terraform";
```

Additionally, some extra inputs are required for the example provided in the
[Usage](#usage) section:

```nix
inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
inputs.systems.url = "github:nix-systems/default";
```

**Binary Cache**

It is highly recommended to set up the
[nixpkgs-terraform](https://nixpkgs-terraform.cachix.org) binary cache to
download pre-compiled Terraform binaries rather than compiling them locally for
a better user experience. Add the following configuration to the `flake.nix`
file:

```nix
nixConfig = {
  extra-substituters = "https://nixpkgs-terraform.cachix.org";
  extra-trusted-public-keys = "";
};
```

## Usage

After configuring the inputs from the [Install](#install) section, a common use
case for this flake could be spawning a [nix-shell] with a specific Terraform
version, which could be accomplished by extracting the desired version from
`nixpkgs-terraform.packages` as follows:

```nix
outputs = { self, nixpkgs-terraform, nixpkgs, systems, ... }:
  let
    forEachSystem = nixpkgs.lib.genAttrs (import systems);
  in {
    devShell = forEachSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        terraform = nixpkgs-terraform.packages.${system}."1.6.3";
      in {
        default = pkgs.mkShell {
          buildInputs = [ terraform ];
        };
      });
  };
```

Start a new [nix-shell] with Terraform installed by running the following
command:

```sh
env NIXPKGS_ALLOW_UNFREE=1 nix develop --impure
```

**Note:** Due to Hashicorp’s most recent [license
change](https://www.hashicorp.com/blog/hashicorp-adopts-business-source-license),
the `NIXPKGS_ALLOW_UNFREE` flag is required for Terraform versions >= 1.6.0,
`nix develop` should work out of the box for older versions.

## License

MIT, see [the LICENSE file](LICENSE).

## Contributing

Do you want to contribute to this project? Please take a look at our
[contributing guideline](docs/CONTRIBUTING.md) to know how you can help us
build it.

---
<img src="https://www.stackbuilders.com/media/images/Sb-supports.original.png"
alt="Stack Builders" width="50%"></img>  
[Check out our libraries](https://github.com/stackbuilders/) | [Join our
team](https://www.stackbuilders.com/join-us/)

[nix-shell]: https://nixos.wiki/wiki/Development_environment_with_nix-shell
