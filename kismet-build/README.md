# Kismet build

This directory is the beginnings of the Kismet OS build pipeline.

## Current scripts
- `fetch-ubuntu-base.sh` — gets a base Ubuntu ISO
- `render-package-plan.sh` — combines manifests into one resolved package plan file
- `make-dev-preview-layout.sh` — stages Kismet overlay files into a dev-preview filesystem layout
- `assemble-rootfs.sh` — stages core Kismet rootfs scaffold
- `build-ubuntu-preview.sh` — runs the current preview build pipeline scaffold

## Current result
Not a finished ISO yet.
But now the project has a reproducible place where ISO/remaster work can accumulate instead of being rethought from scratch every session.
