# SPDX-FileCopyrightText: mpvQC developers
#
# SPDX-License-Identifier: MIT

import argparse
import json
import re
import urllib.request
from dataclasses import dataclass
from pathlib import Path

import yaml


@dataclass(frozen=True)
class Requirement:
    name: str
    version: str
    filters: list[str]  # filter1:filter2:filter3
    data: list


@dataclass(frozen=True)
class ResolvedRequirement:
    name: str
    version: str
    filename: str
    sha256: str
    url: str


class RequirementsUpdater:
    _requirements: dict[str, Requirement] = {}

    @property
    def requirements(self) -> dict[str, Requirement]:
        return dict(self._requirements)

    def configure_for(self, dependencies: list[str]) -> None:
        for dependency in dependencies:
            name, filters = dependency.split("::")
            filters = [f.strip() for f in filters.split(":")]

            if "==" in name:
                name, _, version = re.split("(>=|==|<=)", name)
            elif "<=" in name:
                msg = "Version requirement '<=' currently not supported"
                raise ValueError(msg)
            else:
                version = "latest"

            self._requirements[name] = Requirement(name, version, filters, data=[])

    def resolve(self) -> None:
        for requirement in self._requirements.values():
            name = requirement.name

            with urllib.request.urlopen(f"https://pypi.org/pypi/{name}/json", timeout=5) as connection:
                data = json.loads(connection.read().decode("utf-8").strip())

            version = data["info"]["version"] if requirement.version == "latest" else requirement.version
            filters = requirement.filters
            data = data["releases"][version]

            self._requirements[requirement.name] = Requirement(name, version, filters, data)

    def extract(self) -> list[ResolvedRequirement]:
        def find_first_filename_matching(files: list, must_contain_substr: list[str]) -> dict:
            for file in files:
                if all(f in file["filename"] for f in must_contain_substr):
                    return file
            msg = f"Cannot find file containing all required substrings: {', '.join(must_contain_substr)}"
            raise StopIteration(msg)

        dependencies = []

        for requirement in self._requirements.values():
            filters = requirement.filters
            release = find_first_filename_matching(files=requirement.data, must_contain_substr=filters)
            value = ResolvedRequirement(
                name=requirement.name,
                version=requirement.version,
                filename=release["filename"],
                sha256=release["digests"]["sha256"],
                url=release["url"],
            )
            dependencies.append(value)

        dependencies.sort(key=lambda x: x.name)

        return dependencies


def main():
    parser = argparse.ArgumentParser(description="Prints relevant info for flatpak pypi dependencies")
    parser.add_argument(
        "--dependency",
        type=str,
        action="append",
        default=[],
        help="dependency to consider: dependency::filename-filter1:filename-filter2",
    )
    parser.add_argument(
        "--cleanup",
        type=str,
        action="append",
        default=[],
        help="items to add to the flatpak manifest cleanup property",
    )
    parser.add_argument("-o", "--output", help="Output file name", required=True)
    run(parser.parse_args())


def run(args):
    updater = RequirementsUpdater()
    updater.configure_for(args.dependency)
    updater.resolve()

    dump_yml_requirements(
        yaml_file=Path(args.output).absolute(),
        requirements=updater.extract(),
    )


def dump_yml_requirements(
    yaml_file: Path,
    requirements: list[ResolvedRequirement],
):
    app_names = " ".join(f"{req.name.lower()}~={req.version}" for req in requirements)
    sources = [
        {
            "type": "file",
            "url": req.url,
            "sha256": req.sha256,
        }
        for req in requirements
    ]

    # noinspection PyTypeChecker
    cleanup = sorted(read_existing_cleanup(yaml_file), key=str.lower)

    yaml_object = {
        "name": "pypi-dependencies",
        "buildsystem": "simple",
        "build-commands": [
            (
                f"pip3 install --verbose --exists-action=i "
                f'--no-index --find-links="file://${{PWD}}" '
                f"--prefix=${{FLATPAK_DEST}} --no-build-isolation {app_names}"
            ),
        ],
        "sources": sources,
        "cleanup": cleanup,
    }

    content = yaml.dump(yaml_object, Dumper=yaml.Dumper, sort_keys=False)
    yaml_file.write_text(content, encoding="utf-8")


def read_existing_cleanup(yaml_file: Path) -> list[str]:
    if not yaml_file.exists():
        return []

    try:
        content = yaml_file.read_text(encoding="utf-8")
        data = yaml.safe_load(content)
        return data.get("cleanup", [])
    except Exception:
        return []


if __name__ == "__main__":
    main()

if __name__ == "__main__":
    main()
