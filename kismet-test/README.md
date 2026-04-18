# Kismet test environment

This directory is for fast visual and UX testing of Kismet OS ideas without waiting for a full ISO.

## Current plan
Use a lightweight Linux desktop container with VNC/web access to:
- inspect wallpapers and theme direction
- prototype shell and desktop defaults
- test onboarding/welcome flow ideas
- sanity check Kismet branding decisions

## Compose file
- `docker-compose.vnc.yml`

## Access targets
- Web VNC: http://localhost:6080
- Raw VNC: localhost:5901

## Note
This is a testing aid, not the final distro artifact.
