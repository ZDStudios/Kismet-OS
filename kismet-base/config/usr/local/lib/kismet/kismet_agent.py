#!/usr/bin/env python3
"""
Kismet Agent, adapted for the Kismet OS preview image.
Monitors hardware and file activity, exposes a local REST API, and works
with the Ollama bridge without forcing fragile build-time network installs.
"""

from __future__ import annotations

import configparser
import logging
import os
import signal
import subprocess
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

try:
    from flask import Flask, jsonify, request
    import psutil
    import inotify.adapters
    import inotify.constants
except ImportError as exc:
    print(f"Missing dependencies: {exc}. Install python3-flask python3-psutil python3-requests python3-inotify.")
    sys.exit(1)

from habit_tracker import HabitTracker
from hw_monitor import HardwareMonitor
from scheduler import PredictiveScheduler

AGENT_VERSION = "1.1.0-preview2"
API_HOST = "127.0.0.1"
API_PORT = 7731
CONFIG_PATH = Path("/etc/kismet/agent.conf")
AI_STACK_PATH = Path("/etc/kismet/ai-stack.json")
USER_DATA_DIR = Path.home() / ".kismet"
LOG_FILE = "/var/log/kismet-agent.log"
PID_FILE = "/run/kismet-agent.pid"
WATCH_DIR_CANDIDATES = [
    Path.home(),
    Path.home() / "Projects",
    Path.home() / "Documents",
    Path.home() / "Downloads",
]

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger("kismet-agent")

app = Flask("kismet-agent")

_state = {
    "started_at": datetime.now().isoformat(),
    "version": AGENT_VERSION,
    "status": "initialising",
    "habits_learned": 0,
    "tasks_automated": 0,
    "active_models": [],
    "recent_events": [],
    "insights": [],
}

tracker: HabitTracker | None = None
hw_mon: HardwareMonitor | None = None
scheduler: PredictiveScheduler | None = None
CONFIG = configparser.ConfigParser()


def load_config() -> None:
    CONFIG.clear()
    if CONFIG_PATH.exists():
        CONFIG.read(CONFIG_PATH)


def cfg(section: str, key: str, fallback: str = "") -> str:
    return CONFIG.get(section, key, fallback=fallback) if CONFIG.has_section(section) else fallback


def load_ai_stack() -> dict:
    try:
        import json
        return json.loads(AI_STACK_PATH.read_text(encoding="utf-8"))
    except Exception:
        return {
            "kernelAware": True,
            "preferredProvider": "hermes",
            "providerPriority": ["hermes", "opencode", "openclaw", "ollama"],
            "providers": {},
            "windowsCompatibility": {"enabled": True, "preferredRuntimes": ["lutris", "wine", "winetricks"]},
        }


def detect_profile() -> dict:
    cpu_model = "Unknown CPU"
    try:
        with open("/proc/cpuinfo", "r", encoding="utf-8") as handle:
            for line in handle:
                if line.lower().startswith("model name"):
                    cpu_model = line.split(":", 1)[1].strip()
                    break
    except OSError:
        pass
    mem_gib = round(psutil.virtual_memory().total / (1024 ** 3), 2)
    gpu_names: list[str] = []
    for candidate in Path("/sys/class/drm").glob("card*/device/uevent"):
        try:
            text = candidate.read_text(encoding="utf-8")
        except OSError:
            continue
        for line in text.splitlines():
            if line.startswith("DRIVER="):
                gpu_names.append(line.split("=", 1)[1])
    gpu_names = sorted(set(gpu_names))
    has_nvidia = any("nvidia" in gpu.lower() for gpu in gpu_names)
    if has_nvidia and mem_gib >= 32:
        tier = "workstation"
    elif has_nvidia or mem_gib >= 16:
        tier = "creator"
    elif mem_gib >= 8:
        tier = "balanced"
    else:
        tier = "light"
    return {
        "cpu": cpu_model,
        "memory_gib": mem_gib,
        "gpus": gpu_names,
        "tier": tier,
        "cpu_count": psutil.cpu_count() or 1,
    }


def recommend_models() -> dict:
    profile = detect_profile()
    tier = profile["tier"]
    base = [{"name": "nomic-embed-text", "reason": "Embeddings for local retrieval"}]
    if tier == "workstation":
        extra = [
            {"name": "qwen2.5-coder:14b", "reason": "Best local coding fit for a high-end workstation"},
            {"name": "llama3.1:8b", "reason": "Strong default assistant"},
            {"name": "deepseek-r1:14b", "reason": "Heavier reasoning option"},
        ]
    elif tier == "creator":
        extra = [
            {"name": "qwen2.5-coder:7b", "reason": "Primary coding model for capable desktops"},
            {"name": "llama3.1:8b", "reason": "General desktop assistant"},
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
    return {"profile": profile, "recommended": base + extra}


def integration_status() -> dict:
    import shutil
    stack = load_ai_stack()
    providers = {}
    for name in stack.get("providerPriority", []):
        provider = stack.get("providers", {}).get(name, {})
        command = provider.get("command", name)
        providers[name] = {
            **provider,
            "detected": bool(shutil.which(command)),
            "path": shutil.which(command),
        }
    windows_cfg = stack.get("windowsCompatibility", {})
    runtimes = []
    for name in windows_cfg.get("preferredRuntimes", []):
        runtimes.append({"name": name, "detected": bool(shutil.which(name)), "path": shutil.which(name)})
    return {
        "kernelAware": stack.get("kernelAware", True),
        "preferredProvider": stack.get("preferredProvider", "hermes"),
        "modelRecommendation": recommend_models(),
        "providers": providers,
        "windowsCompatibility": {
            **windows_cfg,
            "runtimes": runtimes,
        },
    }


@app.route("/status")
def api_status():
    return jsonify(
        {
            "agent": "kismet-agent",
            "version": _state["version"],
            "status": _state["status"],
            "uptime_seconds": int((datetime.now() - datetime.fromisoformat(_state["started_at"])).total_seconds()),
            "started_at": _state["started_at"],
            "habits_learned": _state["habits_learned"],
            "tasks_automated": _state["tasks_automated"],
            "active_models": _state["active_models"],
            "config_path": str(CONFIG_PATH),
        }
    )


@app.route("/hardware")
def api_hardware():
    return jsonify(hw_mon.snapshot() if hw_mon else {})


@app.route("/habits")
def api_habits():
    if not tracker:
        return jsonify({"error": "tracker not ready"}), 503
    limit = int(request.args.get("limit", 20))
    return jsonify(tracker.get_recent(limit))


@app.route("/habits/stats")
def api_habit_stats():
    if not tracker:
        return jsonify({"error": "tracker not ready"}), 503
    return jsonify(tracker.get_stats())


@app.route("/insights")
def api_insights():
    return jsonify(_state["insights"])


@app.route("/scheduler/tasks")
def api_tasks():
    return jsonify(scheduler.get_pending() if scheduler else [])


@app.route("/scheduler/run", methods=["POST"])
def api_run_task():
    data = request.get_json() or {}
    task = data.get("task")
    if not task:
        return jsonify({"error": "task required"}), 400
    if not scheduler:
        return jsonify({"error": "scheduler not ready"}), 503
    return jsonify(scheduler.run_now(task))


@app.route("/ollama/models")
def api_ollama_models():
    try:
        result = subprocess.run(["ollama", "list"], capture_output=True, text=True, timeout=10)
        if result.returncode != 0:
            return jsonify({"models": [], "error": result.stderr.strip()})
        lines = result.stdout.strip().splitlines()[1:]
        models = []
        for line in lines:
            parts = line.split()
            if parts:
                models.append({"name": parts[0], "size": parts[2] if len(parts) > 2 else "?"})
        return jsonify({"models": models})
    except FileNotFoundError:
        return jsonify({"models": [], "error": "ollama not installed"})
    except Exception as exc:
        return jsonify({"models": [], "error": str(exc)})


@app.route("/ollama/pull", methods=["POST"])
def api_ollama_pull():
    data = request.get_json() or {}
    model = data.get("model")
    if not model:
        return jsonify({"error": "model name required"}), 400
    threading.Thread(target=lambda: subprocess.run(["ollama", "pull", model]), daemon=True).start()
    return jsonify({"status": "pulling", "model": model})


@app.route("/events")
def api_events():
    limit = int(request.args.get("limit", 50))
    return jsonify(_state["recent_events"][-limit:])


@app.route("/recommendations/models")
def api_recommendations():
    return jsonify(recommend_models())


@app.route("/integration/stack")
def api_integration_stack():
    return jsonify(integration_status())


@app.route("/config")
def api_config():
    return jsonify({section: dict(CONFIG[section]) for section in CONFIG.sections()})


@app.route("/config", methods=["POST"])
def api_config_update():
    data = request.get_json() or {}
    for section, values in data.items():
        if not CONFIG.has_section(section):
            CONFIG.add_section(section)
        for key, value in values.items():
            CONFIG.set(section, key, str(value))
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_PATH, "w", encoding="utf-8") as handle:
        CONFIG.write(handle)
    return jsonify({"status": "saved"})


def push_insight(level: str, message: str) -> None:
    _state["insights"] = ([{"level": level, "message": message, "ts": datetime.now().isoformat()}] + _state["insights"])[:50]


def hardware_loop() -> None:
    global hw_mon
    hw_mon = HardwareMonitor()
    while True:
        try:
            snap = hw_mon.snapshot()
            cpu = snap.get("cpu", {})
            mem = snap.get("memory", {})
            if cpu.get("percent", 0) > 90:
                push_insight("warning", f"CPU is hot at {cpu.get('percent')}%")
            if mem.get("percent", 0) > 92:
                push_insight("critical", f"Memory pressure is high at {mem.get('percent')}%")
        except Exception as exc:
            log.warning("Hardware monitor error: %s", exc)
        time.sleep(5)


def inotify_loop() -> None:
    global tracker
    tracker = HabitTracker(USER_DATA_DIR / "habits.db")
    roots = [str(path) for path in WATCH_DIR_CANDIDATES if path.exists()]
    if not roots:
        roots = [str(Path.home())]
    notifier = inotify.adapters.InotifyTrees(roots)
    for event in notifier.event_gen(yield_nones=False):
        (_, type_names, path, filename) = event
        if not filename:
            continue
        record = {
            "path": os.path.join(path, filename),
            "events": list(type_names),
            "ts": datetime.now().isoformat(),
        }
        _state["recent_events"].append(record)
        _state["recent_events"] = _state["recent_events"][-500:]
        tracker.record(record)
        _state["habits_learned"] = tracker.get_total_count()


def scheduler_loop() -> None:
    global scheduler
    scheduler = PredictiveScheduler(USER_DATA_DIR / "scheduler.db")
    while True:
        try:
            for task in scheduler.get_due_tasks():
                result = scheduler.execute(task)
                if result.get("status") == "completed":
                    _state["tasks_automated"] += 1
        except Exception as exc:
            log.warning("Scheduler error: %s", exc)
        time.sleep(60)


def ollama_warmup() -> None:
    time.sleep(20)
    warmup_models = [m.strip() for m in cfg("ollama", "warmup_models", "").split(",") if m.strip()]
    for model in warmup_models:
        try:
            subprocess.Popen(["ollama", "run", model, "--keepalive", cfg("ollama", "keep_alive", "30m")], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            _state["active_models"].append(model)
        except FileNotFoundError:
            log.info("Ollama not installed yet, skipping warmup")
            return
        except Exception as exc:
            log.warning("Warmup error for %s: %s", model, exc)


def handle_signal(signum, _frame) -> None:
    log.info("Received signal %s, shutting down", signum)
    try:
        os.remove(PID_FILE)
    except FileNotFoundError:
        pass
    sys.exit(0)


def ensure_dirs() -> None:
    USER_DATA_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)


def write_pid() -> None:
    Path(PID_FILE).write_text(str(os.getpid()), encoding="utf-8")


def main() -> None:
    ensure_dirs()
    load_config()
    write_pid()
    _state["status"] = "running"
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)
    threads = [
        threading.Thread(target=hardware_loop, daemon=True, name="hardware"),
        threading.Thread(target=inotify_loop, daemon=True, name="inotify"),
        threading.Thread(target=scheduler_loop, daemon=True, name="scheduler"),
        threading.Thread(target=ollama_warmup, daemon=True, name="ollama-warmup"),
    ]
    for thread in threads:
        thread.start()
    app.run(host=API_HOST, port=API_PORT, threaded=True, use_reloader=False)


if __name__ == "__main__":
    main()
