import argparse
import collections
import functools
import itertools
import json
import os
import pathlib
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import (
    Callable,
    Iterable,
    List,
    Optional,
    OrderedDict,
)

import github
from github.GitRelease import GitRelease
from semver import Version as SemVer


@dataclass
class NixHashes:
    hash: str
    vendorHash: str


Versions = OrderedDict[SemVer, NixHashes]


def parse_semver(input: str) -> SemVer:
    return SemVer.parse(input.removeprefix("v"))


def read_current_versions(file: Path) -> Versions:
    with open(file, "r") as f:
        data = json.load(f)

    versions = data["releases"]
    result: OrderedDict[SemVer, NixHashes] = OrderedDict()
    for key_raw, value_raw in versions.items():
        key = parse_semver(key_raw)
        result[key] = NixHashes(
            hash=value_raw["hash"], vendorHash=value_raw["vendorHash"]
        )

    return result


def get_stable_github_versions(releases: Iterable[GitRelease]) -> List[SemVer]:
    stable_version = SemVer(1, 0, 0)

    def to_semver(release: GitRelease) -> SemVer:
        return parse_semver(release.tag_name)

    def is_stable(release: GitRelease) -> bool:
        return to_semver(release) >= stable_version and not (
            release.draft or release.prerelease
        )

    return list(map(to_semver, filter(is_stable, releases)))


def get_latest_versions_per_cycle(
    versions: collections.OrderedDict,
) -> collections.OrderedDict:
    sorted_versions = sorted(versions, key=lambda v: (v.major, v.minor), reverse=True)
    grouped_versions = itertools.groupby(
        sorted_versions, key=lambda v: f"{v.major}.{v.minor}"
    )

    latest_versions = {k: max(list(g)) for k, g in grouped_versions}

    return collections.OrderedDict(sorted(latest_versions.items(), reverse=True))


def get_or_calculate_hashes(
    vendor_hash_nix: Path,
) -> Callable[[Versions, SemVer], Versions]:
    def add_version(
        current_versions: Versions,
        new_version: SemVer,
    ) -> Versions:
        maybe_current_hashes = current_versions.get(new_version)
        calculated_hash = calculate_hash(new_version, maybe_current_hashes)
        calculated_vendor_hash = calculate_vendor_hash(
            new_version, maybe_current_hashes, calculated_hash, vendor_hash_nix
        )

        to_upsert = NixHashes(hash=calculated_hash, vendorHash=calculated_vendor_hash)
        current_versions[new_version] = to_upsert
        return current_versions

    return add_version


def calculate_hash(version: SemVer, maybe_current_hashes: Optional[NixHashes]) -> str:
    if maybe_current_hashes:
        print(f"Using existing hash for {version}")
        return maybe_current_hashes.hash
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


def calculate_vendor_hash(
    version: SemVer,
    maybe_current_hashes: Optional[NixHashes],
    calculated_hash: str,
    vendor_hash_nix: Path,
) -> str:
    if maybe_current_hashes:
        print(f"Using existing vendorHash for {version}")
        return maybe_current_hashes.vendorHash
    else:
        print(f"Calculating vendorHash for {version}")
        return nix_prefetch(
            [
                "--file",
                str(vendor_hash_nix.resolve()),
                "--argstr",
                "version",
                str(version),
                "--argstr",
                "hash",
                calculated_hash,
            ]
        )


def nix_prefetch(args: Iterable[str]) -> str:
    return subprocess.check_output(
        [
            "nix-prefetch",
            "--silent",
            "--option",
            "extra-experimental-features",
            "flakes",
            *args,
        ],
        text=True,
    ).strip()


def main():
    parser = argparse.ArgumentParser(description="Update versions.json file")
    parser.add_argument(
        "--vendor_hash",
        type=pathlib.Path,
        default="vendor-hash.nix",
        help="Path to vendor-hash.nix file",
    )
    args = parser.parse_args()

    gh_token = github.Auth.Token(os.environ["GITHUB_TOKEN"])
    gh = github.Github(auth=gh_token)
    repo = gh.get_repo("hashicorp/terraform")

    versions_file = Path("versions.json")

    gh_releases = repo.get_releases()
    stable_gh_versions = get_stable_github_versions(gh_releases)
    current_versions = read_current_versions(versions_file)

    versions = collections.OrderedDict(
        sorted(
            functools.reduce(
                get_or_calculate_hashes(args.vendor_hash),
                stable_gh_versions,
                current_versions,
            ).items(),
            reverse=True,
        )
    )

    latest_versions_per_cycle = get_latest_versions_per_cycle(versions)

    versions_jsonified = OrderedDict(
        (str(version), hashes.__dict__) for version, hashes in versions.items()
    )

    latest_versions_jsonified = OrderedDict(
        (str(cycle), str(latest_version))
        for cycle, latest_version in latest_versions_per_cycle.items()
    )

    with open(versions_file, "w") as f:
        json.dump(
            {"releases": versions_jsonified, "latest": latest_versions_jsonified},
            f,
            indent=2,
        )


if __name__ == "__main__":
    main()
