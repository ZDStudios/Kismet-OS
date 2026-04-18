# ISO workflow

## Current position
Kismet OS does not yet emit a finished ISO.
However, the build pipeline skeleton now exists.

## Intended workflow
1. define package manifests
2. prepare Ubuntu base image or rootfs
3. apply Kismet filesystem scaffold
4. apply theme assets and desktop defaults
5. apply AI/developer integration layer
6. repack into first developer preview ISO

## Scripts
- `kismet-build/assemble-rootfs.sh`
- `kismet-build/build-ubuntu-preview.sh`

## Honest target
The goal for now is to make the ISO path easier and easier each pass, not to fake a finished artifact before the pipeline is real.
