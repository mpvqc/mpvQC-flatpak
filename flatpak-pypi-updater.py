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
    data: list = None


@dataclass(frozen=True)
class ResolvedRequirement:
    name: str
    version: str
    filename: str
    sha256: str
    url: str


class RequirementsUpdater:
    _requirements: dict[str, Requirement] = {}  # name mapped to object

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
                raise ValueError("Version requirement '<=' currently not supported")
            else:
                version = "latest"

            self._requirements[name] = Requirement(name, version, filters)

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
        """"""

        def find_first_filename_matching(files: list, must_contain_substr: list[str]) -> dict:
            for file in files:
                if all(f in file["filename"] for f in must_contain_substr):
                    return file
            raise StopIteration(
                f"Cannot find file containing all required substrings: {', '.join(must_contain_substr)}"
            )

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
    parser.add_argument("-o", "--output", help="Output file name", required=True)
    run(parser.parse_args())


def run(args):
    output = Path(args.output).absolute()

    updater = RequirementsUpdater()
    updater.configure_for(args.dependency)
    updater.resolve()

    requirements = updater.extract()
    dump_yml_requirements(output, requirements)


def dump_yml_requirements(output, requirements):
    app_names = " ".join(f"{req.name.lower()}~={req.version}" for req in requirements)
    sources = [
        {
            "type": "file",
            "url": req.url,
            "sha256": req.sha256,
        }
        for req in requirements
    ]
    yaml_object = {
        "name": "pypi-dependencies",
        "cleanup": [
            "/bin",
        ],
        "buildsystem": "simple",
        "build-commands": [
            (
                f"pip3 install --verbose --exists-action=i "
                f'--no-index --find-links="file://${{PWD}}" '
                f"--prefix=${{FLATPAK_DEST}} --no-build-isolation {app_names}"
            ),
        ],
        "sources": sources,
    }
    content = yaml.dump(yaml_object, Dumper=yaml.CDumper)
    output.write_text(content, encoding="utf-8")


if __name__ == "__main__":
    main()
