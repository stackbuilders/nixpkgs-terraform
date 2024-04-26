# Config

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

## Disable `allowUnfree`


```
nixpkgs-unstable.allowUnfree = false;
```

## Silence Warnings

```sh
> nix build .#\"1.8.0\"
trace: warning: allowUnfree is enabled to build version 1.8.0
```

```
# default.nix
nixpkgs-terraform.silenceWarnings = true;
```

## Related

https://github.com/nix-systems/default
