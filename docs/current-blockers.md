# Current blockers

## Current real state
Kismet OS can now:
- use a real Ubuntu desktop ISO from local storage
- extract the ISO in the Ubuntu build container
- detect and customize the real default live squashfs payload
- prepare a writable live rootfs
- apply Kismet overlay files
- repack the customized squashfs
- rebuild a boot-structured preview ISO at `kismet-build/output/kismet-os-dev-preview.iso`

## Remaining blockers
- automate chroot package installation into the extracted live filesystem
- refresh metadata/manifests from a fuller package-aware chroot path
- boot-test the resulting image in a VM or test environment

## Overall status
The project is now well past pure scaffolding. It is in real preview-image pipeline territory.
