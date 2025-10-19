# SPDX-FileCopyrightText: mpvQC developers
#
# SPDX-License-Identifier: MIT

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
    uv sync --group dev

# Format code
@format:
    uvx prek run --all-files

# Regenerate Python dependency file
[group('support')]
@generate-flatpak-dependencies:
    uv run flatpak-pypi-updater.py \
    	--dependency inject::none:any \
    	--dependency PySide6-Essentials==6.10.0::manylinux:x86_64 \
    	--dependency shiboken6==6.10.0::manylinux:x86_64 \
    	--dependency MarkupSafe==3.0.2::cp312:manylinux:x86_64 \
    	--dependency Jinja2::none:any \
    	--dependency mpv::none:any \
    	--dependency loguru::none:any \
    	--cleanup "/bin" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/lupdate" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/qmlls" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/qmlformat" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/assistant" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/linguist" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/designer" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/lrelease" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/qmllint" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/svgtoqml" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/QtWidgets.abi3.so" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/Qt/lib/libQt6Widgets.so.6" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/Qt/lib/libQt6Designer.so.6" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/Qt/lib/libQt6DesignerComponents.so.6" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/Qt/lib/libQt6QuickControls2Imagine.so.6" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/Qt/lib/libQt6QuickControls2Fusion.so.6" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/Qt/lib/libQt6QuickControls2Universal.so.6" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/Qt/translations/assistant_*" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/Qt/translations/designer_*" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/Qt/translations/linguist_*" \
    	--cleanup "/lib/python3.12/site-packages/PySide6/Qt/translations/qt_help_*" \
    	--output {{ MANIFEST_PYPI_FILE }}

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
