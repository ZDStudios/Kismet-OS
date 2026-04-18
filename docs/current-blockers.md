# Current blockers

## Current real state
Kismet OS can now:
- use a real Ubuntu desktop ISO from local storage
- extract the ISO in the Ubuntu build container
- prepare a writable live rootfs
- apply Kismet overlay files
- repack the customized squashfs

## Remaining blockers
- run the ISO rebuild step and confirm artifact generation
- automate chroot package installation into the extracted live filesystem
- refresh metadata/manifests more intelligently
- boot-test the resulting image in a VM or test environment

## Overall status
The project is now well past pure scaffolding. It is in real preview-image pipeline territory.
