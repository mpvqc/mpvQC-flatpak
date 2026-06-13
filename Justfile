# SPDX-FileCopyrightText: mpvQC developers
#
# SPDX-License-Identifier: MIT

APP_ID := 'io.github.mpvqc.mpvQC'
MANIFEST_FILE := 'io.github.mpvqc.mpvQC.yml'
MANIFEST_PYPI_FILE := 'io.github.mpvqc.mpvQC.pypi.yml'
APPSTREAM_FILE := 'io.github.mpvqc.mpvQC.metainfo.xml'
DESKTOP_FILE := 'io.github.mpvqc.mpvQC.desktop'
BUILD_DIR := 'build-dir'

alias fmt := format

@_default:
    just --list --unsorted

# Initialize repository
init:
    uvx prek install

# Format code
format:
    uvx prek --config=.config/prek.toml run --all-files

# Update git hook dependencies
update-git-hook-dependencies:
    uvx prek --config=.config/prek.toml auto-update

# Regenerate Python dependency file
[group('support')]
generate-flatpak-dependencies:
    #!/usr/bin/env nu
    let cleanup = (open "{{ MANIFEST_PYPI_FILE }}" | get cleanup?)
    let reqs = [
        "inject==5.3.0"
        "PySide6-Essentials==6.11.1"
        "shiboken6==6.11.1"
        "MarkupSafe==3.0.3"
        "Jinja2==3.1.6"
        "mpv==1.0.8"
    ]
    let generated = (^uvx --with pyyaml req2flatpak --target-platforms 313-x86_64 --requirements ...$reqs --yaml | from yaml)
    let out = if ($cleanup | is-empty) { $generated } else { $generated | merge { cleanup: ($cleanup | sort --ignore-case) } }
    $out | to yaml | save --force "{{ MANIFEST_PYPI_FILE }}"

# Lint flatpak appstream file
[group('flatpak-lint')]
@lint-flatpak-appstream:
    flatpak run --command=flatpak-builder-lint org.flatpak.Builder appstream {{ APPSTREAM_FILE }}

# Lint flatpak manifest file
[group('flatpak-lint')]
@lint-flatpak-manifest:
    flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest {{ MANIFEST_FILE }}

# Lint flatpak builddir directory
[group('flatpak-lint')]
@lint-flatpak-builddir:
    flatpak run --command=flatpak-builder-lint org.flatpak.Builder builddir {{ BUILD_DIR }}

# Lint flatpak repo
[group('flatpak-lint')]
@lint-flatpak-repo:
    flatpak run --command=flatpak-builder-lint org.flatpak.Builder repo repo

# Check for dependency updates (read-only)
[group('flatpak-update')]
@run-x-checker-check:
    docker run --rm \
        -v $PWD:/run/app \
        ghcr.io/flathub/flatpak-external-data-checker:latest \
        /run/app/{{ MANIFEST_FILE }}

# Sync dependency updates (update manifest file)
[group('flatpak-update')]
@run-x-checker-update:
    docker run --rm \
        -v $PWD:/run/app \
        ghcr.io/flathub/flatpak-external-data-checker:latest \
        --update --edit-only \
        /run/app/{{ MANIFEST_FILE }}

# Force clean environment
[group('flatpak')]
clean-flatpak-resources:
    rm -rf {{ BUILD_DIR }}
    rm -rf .flatpak-builder
    rm -rf repo

# (1) Build flatpak
[group('flatpak')]
build-flatpak:
    flatpak-builder \
        --force-clean {{ BUILD_DIR }} {{ MANIFEST_FILE }}

# (2) Install flatpak
[group('flatpak')]
install-flatpak:
    flatpak-builder \
        --force-clean \
        --user \
        --install-deps-from=flathub \
        --disable-download \
        --repo=repo \
        --install {{ BUILD_DIR }} {{ MANIFEST_FILE }}

# (3) Run flatpak
[group('flatpak')]
run-flatpak:
    flatpak run {{ APP_ID }}

# (4) Uninstall flatpak
[group('flatpak')]
uninstall-flatpak:
    flatpak uninstall --user {{ APP_ID }}
