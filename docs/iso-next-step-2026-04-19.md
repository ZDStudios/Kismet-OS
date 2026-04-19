# Kismet OS ISO next step - 2026-04-19

## Publish status

Git publish is currently blocked by SSH key usage mismatch in the execution environment.

- Host trust is now seeded.
- The remaining issue is getting git/ssh to use Sir's actual GitHub key successfully from this runtime.
- Local commits are ready to publish once that path is corrected.

## ISO progress made in this pass

- upgraded the Ubuntu build container to include `live-build`, `debootstrap`, grub/syslinux tooling, and related ISO dependencies
- updated the container runner scripts to support both preview and `live-build` modes
- adjusted the live-build script to generate its `auto/config` correctly and run a fuller Ubuntu noble live-build path

## Next command to try

```bash
cd /DATA/AppData/Kismet\ OS/repo
./kismet-build/run-ubuntu-build-env.sh
# inside the container
./kismet-build/run-pipeline-in-container.sh live-build
```

## Likely next blocker

Ubuntu-flavoured live-build can still be finicky around package availability and hook timing. If it fails, capture the first concrete build error and patch that directly instead of redesigning the pipeline again.
