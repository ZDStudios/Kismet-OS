from __future__ import annotations

from pathlib import Path

KISMET_HOME = Path.home() / ".kismet"
DB_PATH = KISMET_HOME / "habits.db"
CONFIG_PATH = KISMET_HOME / "config.json"
DEFAULT_WATCH_PATHS = [Path.home() / "Desktop", Path.home() / "Documents", Path.home() / "Downloads", Path.home() / "Projects"]
