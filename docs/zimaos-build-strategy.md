# ZimaOS build strategy for Kismet OS

## Key reality
ZimaOS does not currently expose the expected Ubuntu/Debian package tooling in this runtime, so trying to force `apt` onto the host is the wrong first move.

## Practical approach
Use Docker on ZimaOS to run an Ubuntu 24.04 build environment for Kismet OS.

## Why this is the right move
- Ubuntu toolchain is available inside the container
- ISO build tools can be installed normally
- Kismet repo can be mounted directly into the container
- host stays clean
- build process becomes reproducible

## Planned workflow
1. build `kismet-ubuntu-build` container image
2. mount `/DATA/AppData/Kismet OS/repo` into `/workspace`
3. run Kismet build scripts inside the Ubuntu container
4. emit artifacts back into the mounted repo folders

## Installed-in-container tool targets
- xorriso
- libarchive-tools
- squashfs-tools
- curl/wget/rsync/xz-utils

## Strategic note
This is better than trying to mutate ZimaOS into a pseudo-Ubuntu host.
