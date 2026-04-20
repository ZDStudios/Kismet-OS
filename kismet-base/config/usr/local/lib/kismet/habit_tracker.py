#!/usr/bin/env python3
"""SQLite-backed habit tracker for the Kismet preview agent."""

from __future__ import annotations

import json
import sqlite3
import threading
from datetime import datetime
from pathlib import Path

SCHEMA = """
CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT NOT NULL,
    event_types TEXT NOT NULL,
    extension TEXT,
    directory TEXT,
    hour INTEGER,
    weekday INTEGER,
    ts TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS habits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    pattern TEXT NOT NULL,
    confidence REAL DEFAULT 0.0,
    last_seen TEXT,
    count INTEGER DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_events_ts ON events(ts);
CREATE INDEX IF NOT EXISTS idx_events_dir ON events(directory);
CREATE INDEX IF NOT EXISTS idx_events_hour ON events(hour);
"""


class HabitTracker:
    def __init__(self, db_path: Path):
        self.db_path = db_path
        db_path.parent.mkdir(parents=True, exist_ok=True)
        self._conn = sqlite3.connect(str(db_path), check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        self._conn.executescript(SCHEMA)
        self._conn.commit()
        self._lock = threading.Lock()

    def record(self, event: dict) -> None:
        path = event.get("path", "")
        event_types = ",".join(event.get("events", []))
        ext = Path(path).suffix.lower() or "none"
        directory = str(Path(path).parent)
        now = datetime.now()
        with self._lock:
            self._conn.execute(
                "INSERT INTO events (path, event_types, extension, directory, hour, weekday, ts) VALUES (?, ?, ?, ?, ?, ?, ?)",
                (path, event_types, ext, directory, now.hour, now.weekday(), event.get("ts", now.isoformat())),
            )
            self._conn.commit()
        if self.get_total_count() % 50 == 0:
            self._update_habits()

    def _update_habits(self) -> None:
        rows = self._conn.execute(
            "SELECT hour, COUNT(*) AS cnt FROM events WHERE ts > datetime('now', '-7 days') GROUP BY hour ORDER BY cnt DESC LIMIT 5"
        ).fetchall()
        for row in rows:
            self._upsert_habit(f"active_hour_{row['hour']}", json.dumps({"hour": row['hour'], "count": row['cnt']}), min(row['cnt'] / 100.0, 1.0), row['cnt'])

    def _upsert_habit(self, name: str, pattern: str, confidence: float, count: int) -> None:
        with self._lock:
            self._conn.execute(
                """INSERT INTO habits (name, pattern, confidence, last_seen, count)
                   VALUES (?, ?, ?, ?, ?)
                   ON CONFLICT(name) DO UPDATE SET
                     pattern=excluded.pattern,
                     confidence=excluded.confidence,
                     last_seen=excluded.last_seen,
                     count=excluded.count""",
                (name, pattern, confidence, datetime.now().isoformat(), count),
            )
            self._conn.commit()

    def get_total_count(self) -> int:
        row = self._conn.execute("SELECT COUNT(*) AS c FROM events").fetchone()
        return int(row["c"]) if row else 0

    def get_recent(self, limit: int = 20) -> list[dict]:
        rows = self._conn.execute("SELECT * FROM events ORDER BY id DESC LIMIT ?", (limit,)).fetchall()
        return [dict(row) for row in rows]

    def get_stats(self) -> dict:
        top_dirs = self._conn.execute("SELECT directory, COUNT(*) AS cnt FROM events GROUP BY directory ORDER BY cnt DESC LIMIT 5").fetchall()
        top_ext = self._conn.execute("SELECT extension, COUNT(*) AS cnt FROM events WHERE extension != 'none' GROUP BY extension ORDER BY cnt DESC LIMIT 5").fetchall()
        top_hours = self._conn.execute("SELECT hour, COUNT(*) AS cnt FROM events GROUP BY hour ORDER BY cnt DESC LIMIT 3").fetchall()
        habits = self._conn.execute("SELECT name, confidence, count FROM habits ORDER BY confidence DESC LIMIT 10").fetchall()
        return {
            "total_events": self.get_total_count(),
            "top_directories": [dict(row) for row in top_dirs],
            "top_file_types": [dict(row) for row in top_ext],
            "most_active_hours": [dict(row) for row in top_hours],
            "top_habits": [dict(row) for row in habits],
        }
