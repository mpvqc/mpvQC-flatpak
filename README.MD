# mpvQC-flatpak

Flatpak is a software utility for deploying, managing, and running applications on Linux.
It allows apps to run consistently across different Linux distributions.
This repository contains necessary artifacts and scripts to build mpvQC flatpaks.

## For users

Install mpvQC from the published Flatpak ref:

- Download the <a href="https://mpvqc.github.io/mpvQC-flatpak/mpvQC.flatpakref" download="mpvQC.flatpakref">Flatpak Ref File</a> and double click it

or via **command line**:

```shell
flatpak install --user https://mpvqc.github.io/mpvQC-flatpak/mpvQC.flatpakref
```

## For developers

You need
[just](https://github.com/casey/just),
[uv](https://docs.astral.sh/uv/),
[nu](https://www.nushell.sh/) and the Flatpak toolchain (`flatpak` + `flatpak-builder`).
The dependency-update checks additionally use `docker`.

Everything is driven through the [Justfile](Justfile). Run `just` to list every recipe. The ones you reach for most:

- `just init`: install the git hooks
- `just generate-flatpak-dependencies`: regenerate the bundled Python dependencies
- `just build-flatpak`, `just install-flatpak`, `just run-flatpak`: build, install and run the flatpak locally
- `just format`: format the repo
