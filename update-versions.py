import argparse
import collections
import functools
import github
import json
import os
import pathlib
import semver
import subprocess


def read_versions():
    with open("versions.json", "r") as f:
        return json.load(f)


def is_stable(release):
    version = release.tag_name.removeprefix("v")
    return semver.compare(version, "1.1.0") >= 0 and not (
        release.draft or release.prerelease
    )


def by_version(release):
    return release.tag_name.removeprefix("v").split(".")


def to_version(vendor_hash):
    def add_version(versions, release):
        version = release.tag_name.removeprefix("v")
        calculated_hash = calculate_hash(versions, version)
        versions[version] = {
            "hash": calculated_hash,
            "vendorHash": calculate_vendor_hash(
                versions, version, calculated_hash, vendor_hash
            ),
        }
        return versions

    return add_version


def calculate_hash(versions, version):
    current_hash = versions.get(version, {}).get("hash")
    if current_hash:
        print(f"Using existing hash for {version}")
        return current_hash
    else:
        print(f"Calculating hash for {version}")
        return nix_prefetch(
            [
                "fetchFromGitHub",
                "--owner",
                "hashicorp",
                "--repo",
                "terraform",
                "--rev",
                f"v{version}",
            ]
        )


def calculate_vendor_hash(versions, version, calculated_hash, vendor_hash):
    current_vendor_hash = versions.get(version, {}).get("vendorHash")
    if current_vendor_hash:
        print(f"Using existing vendorHash for {version}")
        return current_vendor_hash
    else:
        print(f"Calculating vendorHash for {version}")
        return nix_prefetch(
            [
                "--file",
                str(vendor_hash.resolve()),
                "--argstr",
                "version",
                version,
                "--argstr",
                "hash",
                calculated_hash,
            ]
        )


def nix_prefetch(args):
    return subprocess.check_output(
        [
            "nix-prefetch",
            "--silent",
            "--option",
            "extra-experimental-features",
            "flakes",
        ]
        + args,
        text=True,
    ).strip()


parser = argparse.ArgumentParser(description="Update versions.json file")
parser.add_argument("--vendor_hash", type=pathlib.Path, default="vendor-hash.nix")
args = parser.parse_args()

auth = github.Auth.Token(os.environ["GITHUB_TOKEN"])
g = github.Github(auth=auth)
repo = g.get_repo("hashicorp/terraform")
# TODO: Drop "v" prefix first
releases = list(filter(is_stable, repo.get_releases()))
current_versions = read_versions()
versions = collections.OrderedDict(
    sorted(
        functools.reduce(
            to_version(args.vendor_hash), releases, current_versions
        ).items(),
        reverse=True,
    )
)
with open("versions.json", "w") as f:
    json.dump(versions, f, indent=2)
