# Architecture

This document describes the practical first architecture for Kismet OS.

## Core idea

Kismet OS should begin as an opinionated Linux distribution layer, not a reinvention of everything below it.

That means building from a stable base and adding:
- curated packages
- desktop theming
- AI services
- automation helpers
- onboarding and management tooling

## Proposed layers

### 1. Base system
A conventional Linux base, likely one of:
- Arch-based, for aggressive customization and AUR support
- Ubuntu or Debian-based, for broader stability and familiarity
- Fedora-based, for a polished modern KDE stack

### 2. Desktop layer
- KDE Plasma desktop
- SDDM theme
- Plymouth splash
- bootloader branding
- wallpaper, icons, terminal profile, accent system

### 3. Developer layer
- git, curl, wget, vim, neovim, tmux
- python and node tooling
- build-essential equivalents
- docker and compose workflow setup
- flatpak support where appropriate
- zsh as default shell
- Kitty or Alacritty as terminal default

### 4. AI layer
- Ollama service management
- local model helpers
- optional OpenClaw integration
- optional coding-agent integrations
- desktop shortcuts and task entry points

### 5. Control layer
A future Kismet control surface could manage:
- service status
- model downloads
- automation permissions
- hardware profiles
- update channels
- backup/recovery helpers

## Security stance

The most dangerous failure mode for an AI-first OS is pretending broad autonomy is harmless.

So the early architecture should prefer:
- explicit permissions
- auditability
- reversible actions
- local execution where possible
- gradual escalation instead of blanket access

## Beta reality

The beta should ship a coherent environment and documented architecture, not an exaggerated claim of total autonomy.
