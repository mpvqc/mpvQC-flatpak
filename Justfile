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

@_default:
    just --list

# Initialize repository
@init:
    uv sync

# Format code
@format:
    uv run ruff check --fix
    uv run ruff format

# Regenerate com.github.mpvqc.mpvQC.pypi.yaml
[group('support')]
@generate-flatpak-dependencies:
    python flatpak-pypi-updater.py \
    	--dependency inject::none:any \
    	--dependency PySide6-Essentials==6.8.2::manylinux:x86_64 \
    	--dependency shiboken6==6.8.2::manylinux:x86_64 \
    	--dependency MarkupSafe::cp312:manylinux:x86_64 \
    	--dependency Jinja2::none:any \
    	--dependency mpv::none:any \
    	--output com.github.mpvqc.mpvQC.pypi.yaml
    yq -iP com.github.mpvqc.mpvQC.pypi.yaml

# (1) Build flatpak
[group('flatpak')]
build-flatpak:
    flatpak-builder --force-clean build-dir com.github.mpvqc.mpvQC.yml

# (2) Install flatpak
[group('flatpak')]
install-flatpak:
    flatpak-builder --force-clean --user --install-deps-from=flathub --repo=repo --install build-dir com.github.mpvqc.mpvQC.yml

# (3) Run flatpak
[group('flatpak')]
run-flatpak:
    flatpak run com.github.mpvqc.mpvQC
