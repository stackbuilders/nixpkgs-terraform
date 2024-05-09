# nixpkgs-terraform - config

This flake stores the default configuration for `nixpkgs-terraform`.

## Usage

To override the default configuration, create a new flake project and follow
the steps described below:

Create an empty directory:

```sh
mkdir config
```

Scaffold a new flake project using the `config` template:

```sh
cd config
nix flake init -t github:stackbuilders/nixpkgs-terraform#config
```

After modifying the default configuration in the `default.nix` file, create a
new input for the configuration flake and override the `config` input for
`nixpkgs-terraform` as follows:

```nix
inputs = {
  nixpkgs-terraform-config.url = "./config";
  nixpkgs-terraform.url = "github:stackbuilders/nixpkgs-terraform";
  nixpkgs-terraform.inputs.config.follows = "nixpkgs-terraform-config";
};
```

The relative path `./config` provided in the example above could be replaced
with a full path or a git URL; look at the [URL-like
syntax](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake.html#url-like-syntax)
for more details.

## Overview

The following section provides an overview of all the available options
supported by `nixpkgs-terraform`.

### `nixpkgs-unstable.allowUnfree` (default `true`)

Control whether Terraform versions after the [HashiCorp license
change](https://www.hashicorp.com/blog/hashicorp-adopts-business-source-license)
are available or not; if set to `true`, all free and non-free versions are
available; otherwise, only free versions are available.

### `nixpkgs-terraform.silenceWarnings` (default `true`)

Starting with version `4.0`, the flag `allowUnfree` is enabled by default; to
notify users of this change, a warning message is printed whenever a non-free
package is evaluated. If set to `true`, the warning message is silence.

## References

This configuration flake has the same structure as
[nix-systems/default](https://github.com/nix-systems/default).
