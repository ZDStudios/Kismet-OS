# Kismet OS fundamentals

This is the first pass at the actual OS fundamentals layer.

## Current scaffolded fundamentals
- package manifests split by concern
- user-facing Kismet config skeleton
- first-boot script scaffold
- first-boot systemd service scaffold
- rootfs assembly script scaffold
- Ubuntu preview build script scaffold
- initial theme asset placeholders

## Why this matters
This is the line where Kismet OS stops being just a public concept page and starts becoming a structured build target.

## Next implementation moves
- teach the preview build script to consume a real Ubuntu base
- add SDDM and Plymouth asset files, not just README placeholders
- add desktop defaults and launcher entries
- add OpenClaw integration bootstrap
- add model bootstrap flow for Ollama
