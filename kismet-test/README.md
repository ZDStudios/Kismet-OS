# Kismet test environment

This directory is for fast visual and UX testing of Kismet OS ideas without waiting for a full ISO.

## Current plan
Use a lightweight Linux desktop container with VNC/web access to:
- inspect wallpapers and theme direction
- prototype shell and desktop defaults
- test onboarding and first-boot wizard ideas
- sanity check Kismet branding decisions
- smoke-test staged config files before another heavy ISO attempt

## Compose file
- `docker-compose.vnc.yml`

## Build and run

```bash
cd kismet-test
docker compose -f docker-compose.vnc.yml up --build -d
```

The preview container now:
- mounts the repo at `/workspace`
- copies Kismet skel defaults into `/root`
- installs `kismet-firstboot-wizard` into the container for quick UX testing
- exposes a simple health check for the web desktop
- has a smoke-test entrypoint script at `smoke-preview-container.sh`

## Smoke test

```bash
cd kismet-test
./smoke-preview-container.sh
```

This boots the preview desktop, waits for the container to become healthy, checks the web desktop on port 6080, and verifies that `kismet-firstboot-wizard` is installed.

## Access targets
- Web VNC: http://localhost:6080
- Raw VNC: localhost:5901

## Note
This is a testing aid, not the final distro artifact.
