# Distro development patterns

This document distills the practical patterns real Linux distributions and remaster projects tend to follow.

## Common pattern 1: base image plus overlay
Most custom distributions do not build an operating system from nothing. They start from a base image or package universe and add:
- package manifests
- filesystem overlays
- desktop defaults
- branding assets
- first-boot logic
- installer or remaster configuration

This is exactly the right path for Kismet OS.

## Common pattern 2: reproducible stages
Real distro projects usually split work into stages:
1. choose base
2. resolve package lists
3. prepare root filesystem changes
4. apply branding and desktop defaults
5. add services and integration scripts
6. build or remaster image
7. test in VM and on hardware

Kismet OS should keep following that model.

## Common pattern 3: overlays instead of hand-editing images
A maintainable distro project keeps most custom work in a normal repository and applies it into the image build process later.

That means storing things like:
- `/etc/skel` defaults
- theme files
- service units
- helper scripts
- package manifests

That is better than manually tweaking one-off images.

## Common pattern 4: separate policy from payload
Good distro projects separate:
- package selection
- filesystem content
- service behavior
- branding
- installer behavior

Kismet OS is starting to do that through manifests, config, theme, build, and integration folders.

## Common pattern 5: testable build pipeline
Serious distro work eventually needs scripts that can:
- fetch the base ISO or root filesystem
- unpack or mount it
- inject package and filesystem changes
- repack the result
- emit logs and artifacts

Kismet OS is not fully there yet, but the build folder now exists for exactly this reason.

## Common pattern 6: honest milestones
Healthy distro projects do not pretend a finished ISO exists before the build pipeline is real. They ship milestones like:
- package baseline complete
- overlay filesystem ready
- live image customization working
- installer customization working
- first boot working in VM
- first public preview ISO

## Recommendation for Kismet OS
Keep using:
- Ubuntu as the practical base
- repository-managed overlays
- package manifests split by concern
- explicit first-boot and service scaffolds
- separate theme, integrations, and build directories
- VM-first testing before promising real release quality
