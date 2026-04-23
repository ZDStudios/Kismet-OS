# Kismet base

This directory contains the first practical starter files for building Kismet OS as a real base environment.

## Current contents
- `package-manifest.ubuntu` — starter package baseline for the current preview pipeline
- `bootstrap/setup-ubuntu-base.sh` — initial base bootstrap script

## Intent
This is not a full ISO builder yet.
It is the first concrete layer that turns Kismet OS from a concept repo into a buildable environment plan.

## Direction
- Base: Kismet OS preview pipeline on top of Ubuntu internals
- UX inspiration: Zorin OS
- attitude and power-user polish inspiration: Garuda Linux
- desktop direction: GNOME Shell + GDM


## Recent preview polish

- Added Kismet-owned desktop launchers and icons for the game library plus featured games so the preview stops falling back to generic Ubuntu/Yaru game entries.
- Hermes and OpenCode launchers now fail gracefully with explicit preview-image availability messaging instead of misleading fallbacks.
- Icon cache refresh is now part of the build polish path to reduce missing icon glitches on first boot.
- Catppuccin Mocha Blue is now bundled as the default GTK theme for the GNOME preview.
- Open Bar is bundled and preconfigured for a floating glass-style top bar.
- Ubuntu Dock is shifted to a left-side launcher layout for a more Zorin-like feel.
- Added extra first-login polish for GTK4 theme mirroring and a few desktop comfort tweaks.
