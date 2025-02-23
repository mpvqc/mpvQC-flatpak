# Copyright 2024
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

APP_ID := 'io.github.mpvqc.mpvQC'
MANIFEST_FILE := 'io.github.mpvqc.mpvQC.yml'
MANIFEST_PYPI_FILE := 'io.github.mpvqc.mpvQC.pypi.yml'
APPSTREAM_FILE := 'io.github.mpvqc.mpvQC.metainfo.xml'
DESKTOP_FILE := 'io.github.mpvqc.mpvQC.desktop'
BUILD_DIR := 'build-dir'

@_default:
    just --list

# Initialize repository
@init:
    uv sync

# Format code
@format:
    uv run ruff check --fix
    uv run ruff format

# Regenerate Python dependency file
[group('support')]
@generate-flatpak-dependencies:
    python flatpak-pypi-updater.py \
    	--dependency inject::none:any \
    	--dependency PySide6-Essentials==6.8.2::manylinux:x86_64 \
    	--dependency shiboken6==6.8.2::manylinux:x86_64 \
    	--dependency MarkupSafe::cp312:manylinux:x86_64 \
    	--dependency Jinja2::none:any \
    	--dependency mpv::none:any \
    	--output {{ MANIFEST_PYPI_FILE }}
    yq -iP {{ MANIFEST_PYPI_FILE }}

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

# (1) Build flatpak
[group('flatpak')]
build-flatpak:
    flatpak-builder --force-clean {{ BUILD_DIR }} {{ MANIFEST_FILE }}

# (2) Install flatpak
[group('flatpak')]
install-flatpak:
    flatpak-builder --force-clean --user --install-deps-from=flathub --repo=repo --install {{ BUILD_DIR }} {{ MANIFEST_FILE }}

# (3) Run flatpak
[group('flatpak')]
run-flatpak:
    flatpak run {{ APP_ID }}
