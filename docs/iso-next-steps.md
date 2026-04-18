# ISO next steps

## Current new milestone
Kismet OS now has scripts for:
- fetching the Ubuntu base ISO
- rendering package plans
- generating a Kismet filesystem layout
- assembling rootfs scaffolding
- extracting the Ubuntu ISO contents when tooling is present
- preparing a Kismet overlay tree

## Remaining path to first real preview ISO
1. identify the live root filesystem inside the extracted ISO
2. unsquash it into a writable customization directory
3. install package manifests into that environment
4. overlay Kismet files and themes
5. regenerate squashfs
6. rebuild ISO metadata and image structure
7. boot test in VM

## Honest status
This is now real distro-style groundwork. The image is not finished yet, but the project is moving in the same shape real remaster efforts do.
