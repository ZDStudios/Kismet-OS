from __future__ import annotations

from fastapi import FastAPI

from .db import Database
from .hardware import recommended_models
from .models import ConfigUpdate, HabitEventIn
from .monitor import MonitorManager, collect_system_status


def build_app(db: Database | None = None, monitor: MonitorManager | None = None) -> FastAPI:
    database = db or Database()
    watcher = monitor or MonitorManager(database)
    app = FastAPI(title="kismet-agent", version="0.1.0")

    @app.on_event("startup")
    async def startup_event() -> None:
        watcher.start()

    @app.on_event("shutdown")
    async def shutdown_event() -> None:
        watcher.stop()

    @app.get("/health")
    async def health() -> dict:
        return {"ok": True}

    @app.get("/status")
    async def status() -> dict:
        snapshot = database.latest_snapshot()
        return {
            "live": collect_system_status(),
            "latest_snapshot": snapshot,
            "recent_file_events": database.list_file_events(20),
        }

    @app.get("/habits")
    async def habits(limit: int = 50) -> dict:
        return {"items": database.list_habit_events(limit)}

    @app.post("/habits/events")
    async def add_habit_event(event: HabitEventIn) -> dict:
        event_id = database.add_habit_event(event.category, event.action, event.detail, event.score, event.metadata)
        return {"ok": True, "id": event_id}

    @app.get("/recommendations/models")
    async def model_recommendations() -> dict:
        return recommended_models()

    @app.get("/config")
    async def get_config() -> dict:
        return database.get_config()

    @app.post("/config")
    async def update_config(payload: ConfigUpdate) -> dict:
        values = payload.model_dump(exclude_none=True)
        database.set_config(values)
        return {"ok": True, "config": database.get_config()}

    return app
