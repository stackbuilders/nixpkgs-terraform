# CLI

A set of tools for maintainers.

## Requirements

Install [devenv](https://devenv.sh/getting-started/)

## Usage

Change working directory:

```
cd cli
```

Spawn a [nix-shell]:

```
devenv shell
```

Compile code:

```
go build
```

Update versions file:

```
go run . update-versions \
  --versions ../versions.json \
  --vendor-hash ../vendor-hash.nix
```

[nix-shell]: https://nixos.wiki/wiki/Development_environment_with_nix-shell
