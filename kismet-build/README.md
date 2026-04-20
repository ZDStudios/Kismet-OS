# Kismet build

This directory is the beginnings of the Kismet OS build pipeline.

## Current scripts
- `fetch-ubuntu-base.sh` — gets a base Ubuntu ISO
- `render-package-plan.sh` — combines manifests into one resolved package plan file
- `make-dev-preview-layout.sh` — stages Kismet overlay files into a dev-preview filesystem layout
- `assemble-rootfs.sh` — stages core Kismet rootfs scaffold
- `build-ubuntu-preview.sh` — runs the current preview build pipeline scaffold

## Current result
The preview pipeline can now emit a rebuilt ISO artifact at `kismet-build/output/kismet-os-dev-preview.iso`.
It is still an early preview path, but it now repacks the real Ubuntu live filesystem, refreshes key size metadata, and preserves the source ISO boot structure during rebuild.
