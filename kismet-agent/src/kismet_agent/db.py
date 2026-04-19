from __future__ import annotations

import json
import sqlite3
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

from .paths import DB_PATH, KISMET_HOME


SCHEMA = """
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

CREATE TABLE IF NOT EXISTS kv_config (
    key TEXT PRIMARY KEY,
    value_json TEXT NOT NULL
);
"""


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


class Database:
    def __init__(self, path: Path = DB_PATH) -> None:
        self.path = path
        KISMET_HOME.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.path)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self) -> None:
        with closing(self.connect()) as conn:
            conn.executescript(SCHEMA)
            conn.commit()

    def add_habit_event(self, category: str, action: str, detail: str | None, score: int, metadata: dict) -> int:
        with closing(self.connect()) as conn:
            cur = conn.execute(
                "INSERT INTO habit_events(created_at, category, action, detail, score, metadata_json) VALUES(?, ?, ?, ?, ?, ?)",
                (utc_now(), category, action, detail, score, json.dumps(metadata)),
            )
            conn.commit()
            return int(cur.lastrowid)

    def list_habit_events(self, limit: int = 50) -> list[dict]:
        with closing(self.connect()) as conn:
            rows = conn.execute(
                "SELECT * FROM habit_events ORDER BY id DESC LIMIT ?",
                (limit,),
            ).fetchall()
        return [self._row_to_dict(row) for row in rows]

    def add_snapshot(self, payload: dict) -> None:
        with closing(self.connect()) as conn:
            conn.execute(
                "INSERT INTO system_snapshots(created_at, payload_json) VALUES(?, ?)",
                (utc_now(), json.dumps(payload)),
            )
            conn.commit()

    def latest_snapshot(self) -> dict | None:
        with closing(self.connect()) as conn:
            row = conn.execute(
                "SELECT * FROM system_snapshots ORDER BY id DESC LIMIT 1"
            ).fetchone()
        if not row:
            return None
        return self._row_to_dict(row)

    def add_file_event(self, path: str, event_type: str, is_directory: bool) -> None:
        with closing(self.connect()) as conn:
            conn.execute(
                "INSERT INTO file_events(created_at, path, event_type, is_directory) VALUES(?, ?, ?, ?)",
                (utc_now(), path, event_type, 1 if is_directory else 0),
            )
            conn.commit()

    def list_file_events(self, limit: int = 50) -> list[dict]:
        with closing(self.connect()) as conn:
            rows = conn.execute(
                "SELECT * FROM file_events ORDER BY id DESC LIMIT ?",
                (limit,),
            ).fetchall()
        return [self._row_to_dict(row) for row in rows]

    def set_config(self, values: dict) -> None:
        with closing(self.connect()) as conn:
            for key, value in values.items():
                conn.execute(
                    "INSERT INTO kv_config(key, value_json) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value_json=excluded.value_json",
                    (key, json.dumps(value)),
                )
            conn.commit()

    def get_config(self) -> dict:
        with closing(self.connect()) as conn:
            rows = conn.execute("SELECT key, value_json FROM kv_config").fetchall()
        return {row["key"]: json.loads(row["value_json"]) for row in rows}

    @staticmethod
    def _row_to_dict(row: sqlite3.Row) -> dict:
        data = dict(row)
        for key in ["metadata_json", "payload_json"]:
            if key in data:
                try:
                    data[key.removesuffix("_json")] = json.loads(data.pop(key))
                except json.JSONDecodeError:
                    data[key.removesuffix("_json")] = None
        return data
