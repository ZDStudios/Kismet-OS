from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class HabitEventIn(BaseModel):
    category: str = Field(min_length=1, max_length=64)
    action: str = Field(min_length=1, max_length=128)
    detail: str | None = Field(default=None, max_length=512)
    score: int = 1
    metadata: dict[str, Any] = Field(default_factory=dict)


class ConfigUpdate(BaseModel):
    suggested_models_enabled: bool | None = None
    watch_paths: list[str] | None = None
    preferred_profile: str | None = None
    auto_start_ollama: bool | None = None
    auto_install_openclaw: bool | None = None
    auto_install_claude_code: bool | None = None
