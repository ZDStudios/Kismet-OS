#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sqlite3
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

BASE_DIR = Path.home() / ".kismet"
DB_PATH = BASE_DIR / "habits.db"
CONFIG_PATH = BASE_DIR / "config.json"
WATCH_PATHS = [Path.home() / name for name in ("Desktop", "Documents", "Downloads", "Projects")]
PORT = 7731


def utc_now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def ensure_db() -> None:
    BASE_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS habit_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            category TEXT NOT NULL,
            action TEXT NOT NULL,
            detail TEXT,
            score INTEGER NOT NULL DEFAULT 1,
            metadata_json TEXT NOT NULL DEFAULT '{}'
        );
        CREATE TABLE IF NOT EXISTS system_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            payload_json TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS file_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            path TEXT NOT NULL,
            event_type TEXT NOT NULL,
            is_directory INTEGER NOT NULL DEFAULT 0
        );
        """
    )
    conn.commit()
    conn.close()


def connect() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def read_cpu_model() -> str:
    try:
        with open("/proc/cpuinfo", "r", encoding="utf-8") as handle:
            for line in handle:
                if line.lower().startswith("model name"):
                    return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return "Unknown CPU"


def read_mem_gib() -> float:
    try:
        with open("/proc/meminfo", "r", encoding="utf-8") as handle:
            for line in handle:
                if line.startswith("MemTotal:"):
                    return round(int(line.split()[1]) / 1024 / 1024, 2)
    except OSError:
        pass
    return 0.0


def detect_gpus() -> list[str]:
    results: list[str] = []
    drm = Path("/sys/class/drm")
    if drm.exists():
        for candidate in sorted(drm.glob("card*/device/uevent")):
            try:
                text = candidate.read_text(encoding="utf-8")
            except OSError:
                continue
            for line in text.splitlines():
                if line.startswith("DRIVER="):
                    results.append(line.split("=", 1)[1])
    return sorted(set(results))


def profile() -> dict:
    ram = read_mem_gib()
    gpus = detect_gpus()
    has_nvidia = any("nvidia" in gpu.lower() for gpu in gpus)
    if has_nvidia and ram >= 32:
        tier = "workstation"
    elif has_nvidia or ram >= 16:
        tier = "creator"
    elif ram >= 8:
        tier = "balanced"
    else:
        tier = "light"
    return {
        "cpu": read_cpu_model(),
        "memory_gib": ram,
        "gpus": gpus,
        "tier": tier,
        "cpu_count": os.cpu_count() or 1,
    }


def recommended_models() -> dict:
    p = profile()
    tier = p["tier"]
    base = [{"name": "nomic-embed-text", "reason": "Embeddings for local retrieval"}]
    if tier == "workstation":
        extra = [
            {"name": "qwen2.5-coder:14b", "reason": "High-end coding model"},
            {"name": "llama3.1:8b", "reason": "General assistant"},
            {"name": "deepseek-r1:14b", "reason": "Heavier reasoning option"},
        ]
    elif tier == "creator":
        extra = [
            {"name": "qwen2.5-coder:7b", "reason": "Strong coding model for capable desktops"},
            {"name": "llama3.1:8b", "reason": "General assistant"},
            {"name": "phi4-mini", "reason": "Fast fallback"},
        ]
    elif tier == "balanced":
        extra = [
            {"name": "qwen2.5-coder:3b", "reason": "Balanced coding model"},
            {"name": "llama3.2:3b", "reason": "Balanced assistant"},
            {"name": "phi4-mini", "reason": "Fast fallback"},
        ]
    else:
        extra = [
            {"name": "llama3.2:1b", "reason": "Very light assistant"},
            {"name": "qwen2.5-coder:1.5b", "reason": "Low-end coding helper"},
        ]
    return {"profile": p, "recommended": base + extra}


def system_status() -> dict:
    total = avail = 0
    try:
        with open("/proc/meminfo", "r", encoding="utf-8") as handle:
            for line in handle:
                if line.startswith("MemTotal:"):
                    total = int(line.split()[1])
                elif line.startswith("MemAvailable:"):
                    avail = int(line.split()[1])
    except OSError:
        pass
    load = [0.0, 0.0, 0.0]
    try:
        with open("/proc/loadavg", "r", encoding="utf-8") as handle:
            load = [float(x) for x in handle.read().split()[:3]]
    except OSError:
        pass
    thermal = []
    for zone in Path("/sys/class/thermal").glob("thermal_zone*"):
        try:
            thermal.append({
                "zone": zone.name,
                "type": (zone / "type").read_text(encoding="utf-8").strip(),
                "temp_c": int((zone / "temp").read_text(encoding="utf-8").strip()) / 1000.0,
            })
        except OSError:
            continue
    disk = os.statvfs(str(Path.home()))
    total_bytes = disk.f_blocks * disk.f_frsize
    free_bytes = disk.f_bavail * disk.f_frsize
    return {
        "timestamp": time.time(),
        "profile": profile(),
        "loadavg": load,
        "memory": {
            "total_kib": total,
            "available_kib": avail,
            "used_percent": round((1 - (avail / total)) * 100, 2) if total else 0,
        },
        "disk": {
            "total": total_bytes,
            "free": free_bytes,
            "used": total_bytes - free_bytes,
        },
        "thermal": thermal,
    }


def insert_snapshot(payload: dict) -> None:
    conn = connect()
    conn.execute("INSERT INTO system_snapshots(created_at, payload_json) VALUES(?, ?)", (utc_now(), json.dumps(payload)))
    conn.commit()
    conn.close()


def list_rows(table: str, limit: int = 20) -> list[dict]:
    conn = connect()
    rows = conn.execute(f"SELECT * FROM {table} ORDER BY id DESC LIMIT ?", (limit,)).fetchall()
    conn.close()
    result = []
    for row in rows:
        item = dict(row)
        for key in ("metadata_json", "payload_json"):
            if key in item:
                item[key[:-5]] = json.loads(item.pop(key))
        result.append(item)
    return result


def add_habit_event(data: dict) -> int:
    conn = connect()
    cur = conn.execute(
        "INSERT INTO habit_events(created_at, category, action, detail, score, metadata_json) VALUES(?, ?, ?, ?, ?, ?)",
        (utc_now(), data["category"], data["action"], data.get("detail"), int(data.get("score", 1)), json.dumps(data.get("metadata", {}))),
    )
    conn.commit()
    event_id = int(cur.lastrowid)
    conn.close()
    return event_id


def load_config() -> dict:
    try:
        return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except Exception:
        return {}


def save_config(data: dict) -> dict:
    current = load_config()
    current.update(data)
    BASE_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_PATH.write_text(json.dumps(current, indent=2), encoding="utf-8")
    return current


def watch_loop(stop_event: threading.Event) -> None:
    seen: dict[str, float] = {}
    while not stop_event.wait(60):
        insert_snapshot(system_status())
        now = time.time()
        for root in WATCH_PATHS:
            if not root.exists():
                continue
            for path in root.rglob("*"):
                try:
                    stat = path.stat()
                except OSError:
                    continue
                stamp = stat.st_mtime
                key = str(path)
                if key in seen and stamp > seen[key]:
                    conn = connect()
                    conn.execute(
                        "INSERT INTO file_events(created_at, path, event_type, is_directory) VALUES(?, ?, ?, ?)",
                        (utc_now(), key, "modified", 1 if path.is_dir() else 0),
                    )
                    conn.commit()
                    conn.close()
                seen[key] = stamp
            for key in list(seen):
                if key.startswith(str(root)) and not Path(key).exists():
                    conn = connect()
                    conn.execute(
                        "INSERT INTO file_events(created_at, path, event_type, is_directory) VALUES(?, ?, ?, ?)",
                        (utc_now(), key, "deleted", 0),
                    )
                    conn.commit()
                    conn.close()
                    del seen[key]


class Handler(BaseHTTPRequestHandler):
    def _write(self, payload: dict, status: int = 200) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self._write({"ok": True})
        elif parsed.path == "/status":
            self._write({
                "live": system_status(),
                "latest_snapshot": (list_rows("system_snapshots", 1) or [None])[0],
                "recent_file_events": list_rows("file_events", 20),
            })
        elif parsed.path == "/habits":
            qs = parse_qs(parsed.query)
            limit = int(qs.get("limit", ["50"])[0])
            self._write({"items": list_rows("habit_events", limit)})
        elif parsed.path == "/recommendations/models":
            self._write(recommended_models())
        elif parsed.path == "/config":
            self._write(load_config())
        else:
            self._write({"error": "not found"}, 404)

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            data = json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            self._write({"error": "invalid json"}, 400)
            return
        if self.path == "/habits/events":
            event_id = add_habit_event(data)
            self._write({"ok": True, "id": event_id})
        elif self.path == "/config":
            self._write({"ok": True, "config": save_config(data)})
        else:
            self._write({"error": "not found"}, 404)

    def log_message(self, format: str, *args) -> None:
        return


def main() -> None:
    ensure_db()
    insert_snapshot(system_status())
    stop_event = threading.Event()
    thread = threading.Thread(target=watch_loop, args=(stop_event,), daemon=True)
    thread.start()
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    try:
        server.serve_forever()
    finally:
        stop_event.set()
        server.server_close()


if __name__ == "__main__":
    main()
