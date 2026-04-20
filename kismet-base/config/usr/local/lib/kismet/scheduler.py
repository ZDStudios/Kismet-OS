#!/usr/bin/env python3
"""Lightweight predictive scheduler for the Kismet preview agent."""

from __future__ import annotations

import json
import sqlite3
import subprocess
import threading
from datetime import datetime, timedelta
from pathlib import Path

import psutil

BUILT_IN_TASKS = [
    {"name": "apt-update", "description": "Update package lists", "command": ["apt-get", "update", "-qq"], "schedule": "daily", "idle_only": True, "min_idle_minutes": 10},
    {"name": "journal-clean", "description": "Trim journal", "command": ["journalctl", "--vacuum-size=500M"], "schedule": "weekly", "idle_only": True, "min_idle_minutes": 5},
    {"name": "trim-ssd", "description": "Run fstrim", "command": ["fstrim", "-av"], "schedule": "weekly", "idle_only": True, "min_idle_minutes": 5},
]
SCHEDULE_INTERVALS = {"daily": timedelta(days=1), "weekly": timedelta(weeks=1), "monthly": timedelta(days=30)}


class PredictiveScheduler:
    def __init__(self, db_path: Path):
        self.db_path = db_path
        db_path.parent.mkdir(parents=True, exist_ok=True)
        self._conn = sqlite3.connect(str(db_path), check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        self._lock = threading.Lock()
        self._conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS scheduled_tasks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL,
                description TEXT,
                command TEXT NOT NULL,
                schedule TEXT NOT NULL,
                idle_only INTEGER DEFAULT 1,
                min_idle_m INTEGER DEFAULT 10,
                last_run TEXT,
                next_run TEXT,
                enabled INTEGER DEFAULT 1,
                run_count INTEGER DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS task_runs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                task_name TEXT NOT NULL,
                started_at TEXT NOT NULL,
                ended_at TEXT,
                exit_code INTEGER,
                output TEXT
            );
            """
        )
        self._conn.commit()
        self._seed_tasks()

    def _seed_tasks(self) -> None:
        for task in BUILT_IN_TASKS:
            self._conn.execute(
                "INSERT OR IGNORE INTO scheduled_tasks (name, description, command, schedule, idle_only, min_idle_m, next_run) VALUES (?, ?, ?, ?, ?, ?, datetime('now'))",
                (task["name"], task["description"], json.dumps(task["command"]), task["schedule"], 1 if task.get("idle_only") else 0, task.get("min_idle_minutes", 10)),
            )
        self._conn.commit()

    def _system_idle_minutes(self) -> float:
        return 15.0 if psutil.cpu_percent(interval=1) < 10 else 0.0

    def get_pending(self) -> list[dict]:
        rows = self._conn.execute("SELECT * FROM scheduled_tasks WHERE enabled=1 ORDER BY next_run").fetchall()
        return [dict(row) for row in rows]

    def get_due_tasks(self) -> list[dict]:
        rows = self._conn.execute("SELECT * FROM scheduled_tasks WHERE enabled=1 AND (next_run IS NULL OR next_run <= ?)", (datetime.now().isoformat(),)).fetchall()
        return [dict(row) for row in rows]

    def execute(self, task: dict) -> dict:
        if task.get("idle_only") and self._system_idle_minutes() < task.get("min_idle_m", 10):
            return {"status": "deferred", "reason": "system not idle"}
        command = json.loads(task["command"]) if isinstance(task["command"], str) else task["command"]
        started_at = datetime.now().isoformat()
        try:
            result = subprocess.run(command, capture_output=True, text=True, timeout=300)
            status = "completed" if result.returncode == 0 else "failed"
            exit_code = result.returncode
            output = (result.stdout + result.stderr)[:2000]
        except Exception as exc:
            status = "failed"
            exit_code = -1
            output = str(exc)
        ended_at = datetime.now().isoformat()
        with self._lock:
            self._conn.execute("INSERT INTO task_runs (task_name, started_at, ended_at, exit_code, output) VALUES (?, ?, ?, ?, ?)", (task["name"], started_at, ended_at, exit_code, output))
            interval = SCHEDULE_INTERVALS.get(task["schedule"], timedelta(days=1))
            self._conn.execute("UPDATE scheduled_tasks SET last_run=datetime('now'), next_run=?, run_count=run_count+1 WHERE name=?", ((datetime.now() + interval).isoformat(), task["name"]))
            self._conn.commit()
        return {"status": status, "exit_code": exit_code, "output": output}

    def run_now(self, task_name: str) -> dict:
        row = self._conn.execute("SELECT * FROM scheduled_tasks WHERE name=?", (task_name,)).fetchone()
        if not row:
            return {"error": f"Task '{task_name}' not found"}
        return self.execute(dict(row))
