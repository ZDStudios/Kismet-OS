from __future__ import annotations

import json
import os
from pathlib import Path


def _read_text(path: str) -> str | None:
    try:
        return Path(path).read_text(encoding="utf-8").strip()
    except OSError:
        return None


def cpu_model() -> str:
    try:
        with open("/proc/cpuinfo", "r", encoding="utf-8") as handle:
            for line in handle:
                if line.lower().startswith("model name"):
                    return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return "Unknown CPU"


def total_memory_gib() -> float:
    try:
        with open("/proc/meminfo", "r", encoding="utf-8") as handle:
            for line in handle:
                if line.startswith("MemTotal:"):
                    kib = int(line.split()[1])
                    return round(kib / 1024 / 1024, 2)
    except OSError:
        pass
    return 0.0


def gpu_summary() -> list[str]:
    drm = Path("/sys/class/drm")
    names: list[str] = []
    if drm.exists():
        for card in sorted(drm.glob("card*/device/uevent")):
            text = _read_text(str(card)) or ""
            if "DRIVER=" in text:
                driver = next((line.split("=", 1)[1] for line in text.splitlines() if line.startswith("DRIVER=")), "unknown")
                names.append(driver)
    if not names:
        modalias = _read_text("/sys/class/dmi/id/product_name")
        if modalias:
            names.append(modalias)
    return sorted(set(names))


def detect_profile() -> dict:
    ram = total_memory_gib()
    gpus = gpu_summary()
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
        "cpu": cpu_model(),
        "memory_gib": ram,
        "gpus": gpus,
        "tier": tier,
        "cpu_count": os.cpu_count() or 1,
    }


def recommended_models() -> dict:
    profile = detect_profile()
    tier = profile["tier"]
    common = [
        {"name": "nomic-embed-text", "reason": "Embeddings for local search and OpenClaw retrieval"},
    ]
    if tier == "workstation":
        chat = [
            {"name": "qwen2.5-coder:14b", "reason": "Strong local coding model for high-end systems"},
            {"name": "llama3.1:8b", "reason": "General assistant model with broad compatibility"},
            {"name": "deepseek-r1:14b", "reason": "Heavier reasoning option if VRAM/RAM allows"},
        ]
    elif tier == "creator":
        chat = [
            {"name": "qwen2.5-coder:7b", "reason": "Good local coding model without absurd requirements"},
            {"name": "llama3.1:8b", "reason": "General use assistant model"},
            {"name": "phi4-mini", "reason": "Lightweight fallback for constrained sessions"},
        ]
    elif tier == "balanced":
        chat = [
            {"name": "qwen2.5-coder:3b", "reason": "Smaller coding model for laptops and mini PCs"},
            {"name": "llama3.2:3b", "reason": "Balanced assistant model with modest footprint"},
            {"name": "phi4-mini", "reason": "Low-latency fallback"},
        ]
    else:
        chat = [
            {"name": "llama3.2:1b", "reason": "Very light assistant model for low-RAM machines"},
            {"name": "qwen2.5-coder:1.5b", "reason": "Basic local coding help on weak hardware"},
        ]
    return {"profile": profile, "recommended": common + chat}


def profile_json() -> str:
    return json.dumps(recommended_models(), indent=2)
