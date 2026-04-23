# Kismet build

This directory is the beginnings of the Kismet OS build pipeline.

## Current scripts
- `fetch-ubuntu-base.sh` — gets the current base ISO used for the Kismet OS preview pipeline
- `render-package-plan.sh` — combines manifests into one resolved package plan file
- `make-dev-preview-layout.sh` — stages Kismet overlay files into a dev-preview filesystem layout
- `assemble-rootfs.sh` — stages core Kismet rootfs scaffold
- `build-ubuntu-preview.sh` — runs the current preview build pipeline scaffold
- `run-pipeline-in-container.sh` — runs the preview pipeline, full validation pass, or QEMU boot smoke in the Kismet build Docker image
- `smoke-test-preview.sh` — validates the rebuilt ISO, squashfs metadata, Kismet branding, and patched installer surfaces
- `scan-preview-branding.py` — scans the editable rootfs for non-whitelisted legacy branding regressions
- `test-preview-in-container.sh` — runs smoke tests, branding scans, or a full build plus validation inside the Kismet build Docker image, including BIOS and UEFI QEMU smoke paths
- `run-preview-cycle.sh` — single entrypoint to rebuild the preview, optionally validate/QEMU boot it, then print fresh artifact sizes, checksum manifest output, and any split zip parts
- `boot-preview-in-qemu.sh` — host-side QEMU smoke boot helper that captures a persistent boot screenshot plus serial and monitor logs under `kismet-build/output/qemu-smoke/`, with optional UEFI boot via OVMF

## Current result
The preview pipeline can now emit a rebuilt ISO artifact at `kismet-build/output/kismet-os-dev-preview.iso`.
It is still an early preview path, but it now repacks the real live filesystem used by the Kismet OS preview build, refreshes key size metadata, patches deeper branding surfaces, preserves the source ISO boot structure during rebuild, and emits a checksum manifest plus optional split zip parts for easier transfer of multi-gig preview artifacts.

## Useful container entry points
- `./kismet-build/run-preview-cycle.sh test` — rebuild the preview ISO, run smoke validation, then print fresh artifact sizes and hashes
- `./kismet-build/run-preview-cycle.sh qemu` — rebuild, validate, run BIOS QEMU boot smoke, write screenshot/log artifacts to `kismet-build/output/qemu-smoke/`, then print fresh artifact sizes and hashes
- `./kismet-build/run-preview-cycle.sh qemu-uefi` — rebuild, validate, run UEFI QEMU boot smoke, and keep the same screenshot/log artifact flow for firmware-specific boot debugging
- `./kismet-build/run-preview-cycle.sh qemu-gnome` — rebuild, validate, then run a longer GNOME-focused QEMU boot smoke tuned for the graphical login/session path
- `./kismet-build/run-preview-cycle.sh pipeline` — rebuild only, then print fresh artifact sizes, checksum manifest entries, and any split zip parts
- `./kismet-build/run-pipeline-in-container.sh preview` — rebuild the preview ISO inside Docker

## Artifact packaging helpers
- `kismet-build/output/kismet-os-dev-preview.sha256` — checksum manifest for the latest ISO and zip package
- `KISMET_ZIP_SPLIT_SIZE_MB=1900 ./kismet-build/build-ubuntu-preview.sh` — override the split threshold in MiB when you want smaller or larger transfer chunks
- if the preview zip exceeds the configured threshold, the rebuild step now emits `kismet-os-dev-preview.zip.part-*` files automatically for easier upload/copy workflows
- `./kismet-build/run-pipeline-in-container.sh preview-test` — rebuild plus smoke tests and branding scan inside Docker
- `./kismet-build/run-pipeline-in-container.sh preview-qemu` — rebuild plus smoke tests, branding scan, and BIOS QEMU boot smoke inside Docker
- `./kismet-build/run-pipeline-in-container.sh preview-qemu-uefi` — rebuild plus smoke tests, branding scan, and UEFI QEMU boot smoke inside Docker
- `./kismet-build/run-pipeline-in-container.sh preview-qemu-gnome` — rebuild plus smoke tests, then run a GNOME-focused QEMU smoke pass against the fresh preview ISO inside Docker
- `./kismet-build/test-preview-in-container.sh qemu-uefi` — rebuild plus smoke tests, branding scan, and UEFI QEMU boot smoke inside Docker
- `./kismet-build/test-preview-in-container.sh qemu-smoke-uefi` — run UEFI QEMU boot smoke against an existing preview ISO
- `./kismet-build/test-preview-in-container.sh pipeline` — full pipeline rebuild without validation
- `./kismet-build/test-preview-in-container.sh build` — full pipeline rebuild plus smoke tests and branding scan

## QEMU override knobs
- `KISMET_MEMORY_MB` or `QEMU_MEMORY_MB` — set VM RAM for preview boot smoke
- `KISMET_SMP` or `QEMU_SMP_CPUS` — set VM vCPU count for preview boot smoke
- `QEMU_FIRMWARE=bios|uefi` — switch firmware mode for smoke runs
- `QEMU_BOOT_WAIT_SECONDS` and `QEMU_SENDKEYS` — tune screenshot timing and menu navigation during preview capture

