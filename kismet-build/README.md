# Kismet build

This directory is the beginnings of the Kismet OS build pipeline.

## Current scripts
- `fetch-ubuntu-base.sh` — gets a base Ubuntu ISO
- `render-package-plan.sh` — combines manifests into one resolved package plan file
- `make-dev-preview-layout.sh` — stages Kismet overlay files into a dev-preview filesystem layout
- `assemble-rootfs.sh` — stages core Kismet rootfs scaffold
- `build-ubuntu-preview.sh` — runs the current preview build pipeline scaffold
- `run-pipeline-in-container.sh` — runs the preview pipeline, full validation pass, or QEMU boot smoke in the Ubuntu Docker build image
- `smoke-test-preview.sh` — validates the rebuilt ISO, squashfs metadata, Kismet branding, and patched installer surfaces
- `scan-preview-branding.py` — scans the editable rootfs for non-whitelisted Ubuntu branding regressions
- `test-preview-in-container.sh` — runs smoke tests, branding scans, or a full build plus validation inside the Ubuntu Docker build image
- `run-preview-cycle.sh` — single entrypoint to rebuild the preview, optionally validate/QEMU boot it, then print fresh artifact sizes and hashes
- `boot-preview-in-qemu.sh` — host-side QEMU smoke boot helper that can capture a boot screenshot and serial log

## Current result
The preview pipeline can now emit a rebuilt ISO artifact at `kismet-build/output/kismet-os-dev-preview.iso`.
It is still an early preview path, but it now repacks the real Ubuntu live filesystem, refreshes key size metadata, patches deeper branding surfaces, and preserves the source ISO boot structure during rebuild.

## Useful container entry points
- `./kismet-build/run-preview-cycle.sh test` — rebuild the preview ISO, run smoke validation, then print fresh artifact sizes and hashes
- `./kismet-build/run-preview-cycle.sh qemu` — rebuild, validate, run QEMU boot smoke, then print fresh artifact sizes and hashes
- `./kismet-build/run-preview-cycle.sh pipeline` — rebuild only, then print fresh artifact sizes and hashes
- `./kismet-build/run-pipeline-in-container.sh preview` — rebuild the preview ISO inside Docker
- `./kismet-build/run-pipeline-in-container.sh preview-test` — rebuild plus smoke tests and branding scan inside Docker
- `./kismet-build/run-pipeline-in-container.sh preview-qemu` — rebuild plus smoke tests, branding scan, and QEMU boot smoke inside Docker
- `./kismet-build/test-preview-in-container.sh pipeline` — full pipeline rebuild without validation
- `./kismet-build/test-preview-in-container.sh build` — full pipeline rebuild plus smoke tests and branding scan

