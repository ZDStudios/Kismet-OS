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
- boot-test the latest preview ISO in a VM and capture the first boot/runtime failures cleanly
- tighten SDDM, Plymouth, and desktop-session validation so branding mistakes get caught before ISO emission
- reduce preview ISO size and polish first-boot UX once the login path is stable

## Overall status
The project is now well past pure scaffolding. It is in real preview-image pipeline territory.
