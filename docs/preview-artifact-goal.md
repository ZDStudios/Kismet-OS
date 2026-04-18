# Preview artifact goal

## Target
Produce the first Kismet OS developer preview artifact from an Ubuntu base image by progressively customizing the live filesystem and repacking the ISO.

## Artifact definition
The first real preview artifact does not need to be perfect. It needs to prove the pipeline can:
- fetch base ISO
- extract image contents
- modify or replace the live filesystem
- apply Kismet overlays and defaults
- repack an ISO image

## Current objective
Get to the point where `kismet-os-dev-preview.iso` can be emitted from the local pipeline, even if the first iterations still need validation or manual fixes.
