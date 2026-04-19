# kismet-agent

`kismet-agent` is the local Kismet OS control daemon.

It monitors lightweight system state from `/proc`, `/sys`, and selected filesystem activity, stores habit and event summaries in SQLite, and exposes a localhost REST API on port `7731`.

## Features

- periodic CPU, memory, load, thermal, battery, and disk snapshots
- inotify-backed file activity watcher using `watchdog`
- SQLite habit/event store at `~/.kismet/habits.db`
- localhost REST API for status, habits, events, recommendations, and config
- systemd-friendly foreground process

## API

- `GET /health`
- `GET /status`
- `GET /habits`
- `POST /habits/events`
- `GET /recommendations/models`
- `GET /config`
- `POST /config`

## Run locally

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
kismet-agent --host 127.0.0.1 --port 7731
```
