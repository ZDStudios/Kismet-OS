# First bootable preview path

## Next concrete step toward a real ISO
The project now has the right next target: customize the Ubuntu live root filesystem and repack it.

## Current implemented path
- fetch Ubuntu ISO
- render package plan
- render chroot package install script
- generate Kismet overlay tree
- prepare writable live rootfs path
- apply Kismet overlay to the editable live rootfs
- repack filesystem.squashfs

## Remaining blockers
- install `bsdtar` or equivalent extraction helper in the build environment
- install `xorriso` or `genisoimage` for ISO repack
- run package install inside the extracted/customized environment
- update ISO manifest and boot metadata
- emit final bootable ISO and test in VM

## Why this matters
This is the handoff from abstract scaffolding to real image customization. Once extraction and repack tooling are present, Kismet OS can start producing genuine preview artifacts.
