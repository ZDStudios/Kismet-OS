from __future__ import annotations

import os
import shutil
import threading
import time
from pathlib import Path

from watchdog.events import FileSystemEvent, FileSystemEventHandler
from watchdog.observers import Observer

from .db import Database
from .hardware import detect_profile
from .paths import DEFAULT_WATCH_PATHS


def _read_meminfo() -> dict:
    data: dict[str, int] = {}
    try:
        with open("/proc/meminfo", "r", encoding="utf-8") as handle:
            for line in handle:
                key, value = line.split(":", 1)
                data[key] = int(value.strip().split()[0])
    except OSError:
        return {}
    return data


def _read_loadavg() -> list[float]:
    try:
        with open("/proc/loadavg", "r", encoding="utf-8") as handle:
            return [float(part) for part in handle.read().split()[:3]]
    except OSError:
        return [0.0, 0.0, 0.0]


def _read_thermal() -> list[dict]:
    zones: list[dict] = []
    base = Path("/sys/class/thermal")
    if not base.exists():
        return zones
    for zone in sorted(base.glob("thermal_zone*")):
        try:
            zone_type = (zone / "type").read_text(encoding="utf-8").strip()
            temp = int((zone / "temp").read_text(encoding="utf-8").strip()) / 1000.0
            zones.append({"zone": zone.name, "type": zone_type, "temp_c": temp})
        except OSError:
            continue
    return zones


def _read_battery() -> list[dict]:
    batteries: list[dict] = []
    for supply in Path("/sys/class/power_supply").glob("BAT*"):
        try:
            batteries.append(
                {
                    "name": supply.name,
                    "capacity": int((supply / "capacity").read_text(encoding="utf-8").strip()),
                    "status": (supply / "status").read_text(encoding="utf-8").strip(),
                }
            )
        except OSError:
            continue
    return batteries


def collect_system_status() -> dict:
    mem = _read_meminfo()
    disk = shutil.disk_usage(str(Path.home()))
    return {
        "timestamp": time.time(),
        "profile": detect_profile(),
        "cpu_percent": round(os.getloadavg()[0] / max(os.cpu_count() or 1, 1) * 100, 2) if hasattr(os, "getloadavg") else None,
        "loadavg": _read_loadavg(),
        "memory": {
            "total_kib": mem.get("MemTotal", 0),
            "available_kib": mem.get("MemAvailable", 0),
            "used_percent": round((1 - (mem.get("MemAvailable", 0) / max(mem.get("MemTotal", 1), 1))) * 100, 2) if mem.get("MemTotal") else 0,
        },
        "disk": {
            "total": disk.total,
            "used": disk.used,
            "free": disk.free,
        },
        "thermal": _read_thermal(),
        "battery": _read_battery(),
    }


class FileEventRecorder(FileSystemEventHandler):
    def __init__(self, db: Database) -> None:
        self.db = db

    def on_any_event(self, event: FileSystemEvent) -> None:
        if event.is_synthetic:
            return
        self.db.add_file_event(event.src_path, event.event_type, event.is_directory)


class MonitorManager:
    def __init__(self, db: Database, watch_paths: list[str] | None = None, interval_seconds: int = 60) -> None:
        self.db = db
        self.watch_paths = [Path(p).expanduser() for p in (watch_paths or [str(p) for p in DEFAULT_WATCH_PATHS])]
        self.interval_seconds = interval_seconds
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self._observer: Observer | None = None

    def start(self) -> None:
        self._thread = threading.Thread(target=self._run_sampler, daemon=True)
        self._thread.start()
        self._observer = Observer()
        handler = FileEventRecorder(self.db)
        for path in self.watch_paths:
            if path.exists():
                self._observer.schedule(handler, str(path), recursive=True)
        self._observer.start()

    def stop(self) -> None:
        self._stop.set()
        if self._observer:
            self._observer.stop()
            self._observer.join(timeout=5)
        if self._thread:
            self._thread.join(timeout=5)

    def _run_sampler(self) -> None:
        while not self._stop.is_set():
            self.db.add_snapshot(collect_system_status())
            self._stop.wait(self.interval_seconds)
