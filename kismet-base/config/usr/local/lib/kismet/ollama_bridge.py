#!/usr/bin/env python3
"""Kismet Ollama bridge for the preview image."""

from __future__ import annotations

import configparser
import logging
import subprocess
import sys
import threading
import time
from pathlib import Path

from flask import Flask, jsonify, request
import requests

CONFIG_FILE = Path("/etc/kismet/agent.conf")
OLLAMA_HOST = "http://127.0.0.1:11434"
BRIDGE_PORT = 7732

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s", handlers=[logging.StreamHandler(sys.stdout)])
log = logging.getLogger("kismet-ollama")
app = Flask("kismet-ollama-bridge")


def _cfg() -> configparser.ConfigParser:
    cfg = configparser.ConfigParser()
    if CONFIG_FILE.exists():
        cfg.read(CONFIG_FILE)
    return cfg


def _ollama_api(path: str, method: str = "GET", payload: dict | None = None, timeout: int = 30):
    url = f"{OLLAMA_HOST}{path}"
    try:
        if method == "POST":
            return requests.post(url, json=payload, timeout=timeout)
        return requests.get(url, timeout=timeout)
    except requests.ConnectionError:
        return None


def _available_models() -> list[str]:
    response = _ollama_api("/api/tags")
    if response and response.status_code == 200:
        return [model["name"] for model in response.json().get("models", [])]
    return []


def _routing_table() -> dict[str, list[str]]:
    return {
        "code": ["qwen2.5-coder:7b", "llama3.1:8b", "phi3:mini"],
        "general": ["llama3.1:8b", "mistral:7b", "phi3:mini"],
        "fast": ["phi3:mini", "llama3.2:3b", "tinyllama"],
        "embed": ["nomic-embed-text"],
    }


def _route_model(task_type: str) -> str:
    available = _available_models()
    for candidate in _routing_table().get(task_type, _routing_table()["general"]):
        if any(candidate.split(":")[0] in model for model in available):
            return candidate
    return available[0] if available else "phi3:mini"


def warmup_models() -> None:
    time.sleep(15)
    cfg = _cfg()
    warmup = cfg.get("ollama", "warmup_models", fallback="")
    for model in [item.strip() for item in warmup.split(",") if item.strip()]:
        try:
            subprocess.Popen(["ollama", "run", model, "--keepalive", cfg.get("ollama", "keep_alive", fallback="30m")], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as exc:
            log.warning("Warmup failed for %s: %s", model, exc)


@app.route("/health")
def health():
    response = _ollama_api("/api/tags")
    return jsonify({"bridge": "running", "ollama": "up" if response and response.status_code == 200 else "down"})


@app.route("/models")
def models():
    response = _ollama_api("/api/tags")
    if not response:
        return jsonify({"error": "Ollama not running"}), 503
    return jsonify(response.json())


@app.route("/generate", methods=["POST"])
def generate():
    data = request.get_json() or {}
    prompt = data.get("prompt", "")
    if not prompt:
        return jsonify({"error": "prompt required"}), 400
    model = data.get("model") or _route_model(data.get("task_type", "general"))
    response = _ollama_api("/api/generate", "POST", {"model": model, "prompt": prompt, "stream": False}, timeout=300)
    if not response:
        return jsonify({"error": "Ollama unreachable"}), 503
    return jsonify({"model": model, "response": response.json()})


@app.route("/pull", methods=["POST"])
def pull_model():
    data = request.get_json() or {}
    model = data.get("model")
    if not model:
        return jsonify({"error": "model required"}), 400
    threading.Thread(target=lambda: subprocess.run(["ollama", "pull", model]), daemon=True).start()
    return jsonify({"status": "pulling", "model": model})


@app.route("/route")
def route_info():
    return jsonify(_routing_table())


def main() -> None:
    threading.Thread(target=warmup_models, daemon=True).start()
    app.run(host="127.0.0.1", port=BRIDGE_PORT, threaded=True, use_reloader=False)


if __name__ == "__main__":
    main()
