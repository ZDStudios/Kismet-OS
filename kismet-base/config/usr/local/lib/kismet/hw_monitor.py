#!/usr/bin/env python3
"""Hardware monitor for the Kismet preview agent."""

from __future__ import annotations

import glob
import os
import subprocess
from datetime import datetime
from pathlib import Path

import psutil


class HardwareMonitor:
    def __init__(self):
        self._gpu_type = self._detect_gpu_type()

    def snapshot(self) -> dict:
        return {
            "ts": datetime.now().isoformat(),
            "cpu": self._cpu(),
            "memory": self._memory(),
            "disks": self._disks(),
            "temperatures": self._temperatures(),
            "gpu": self._gpu(),
            "battery": self._battery(),
            "processes_top5": self._top_processes(),
            "load_avg": list(os.getloadavg()),
        }

    def _cpu(self) -> dict:
        freq = psutil.cpu_freq()
        return {
            "percent": psutil.cpu_percent(interval=0.3),
            "count_physical": psutil.cpu_count(logical=False),
            "count_logical": psutil.cpu_count(logical=True),
            "freq_mhz_current": round(freq.current, 1) if freq else None,
            "freq_mhz_max": round(freq.max, 1) if freq else None,
            "model": self._cpu_model(),
            "governor": self._cpu_governor(),
        }

    def _cpu_model(self) -> str:
        try:
            with open("/proc/cpuinfo", "r", encoding="utf-8") as handle:
                for line in handle:
                    if "model name" in line:
                        return line.split(":", 1)[1].strip()
        except OSError:
            pass
        return "Unknown CPU"

    def _cpu_governor(self) -> str | None:
        path = Path("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")
        try:
            return path.read_text(encoding="utf-8").strip()
        except OSError:
            return None

    def _memory(self) -> dict:
        vm = psutil.virtual_memory()
        swp = psutil.swap_memory()
        return {
            "total_gb": round(vm.total / 1e9, 1),
            "available_gb": round(vm.available / 1e9, 1),
            "used_gb": round(vm.used / 1e9, 1),
            "percent": vm.percent,
            "swap_total_gb": round(swp.total / 1e9, 1),
            "swap_used_gb": round(swp.used / 1e9, 1),
            "swap_percent": swp.percent,
        }

    def _disks(self) -> list[dict]:
        disks = []
        for part in psutil.disk_partitions():
            if "loop" in part.device or "tmpfs" in part.fstype:
                continue
            try:
                usage = psutil.disk_usage(part.mountpoint)
            except PermissionError:
                continue
            disks.append({
                "device": part.device,
                "mountpoint": part.mountpoint,
                "fstype": part.fstype,
                "total_gb": round(usage.total / 1e9, 1),
                "used_gb": round(usage.used / 1e9, 1),
                "free_gb": round(usage.free / 1e9, 1),
                "percent": usage.percent,
            })
        return disks

    def _temperatures(self) -> dict:
        try:
            temps = psutil.sensors_temperatures()
        except Exception:
            return {}
        result = {}
        for name, entries in temps.items():
            result[name] = [{"label": entry.label or name, "current": entry.current, "high": entry.high, "critical": entry.critical} for entry in entries]
        return result

    def _detect_gpu_type(self) -> str:
        try:
            result = subprocess.run(["lspci"], capture_output=True, text=True, timeout=3)
            out = result.stdout.lower()
            if "nvidia" in out:
                return "nvidia"
            if "amd" in out or "radeon" in out:
                return "amd"
            if "intel" in out:
                return "intel"
        except Exception:
            pass
        return "unknown"

    def _gpu(self) -> dict:
        if self._gpu_type == "nvidia":
            return self._nvidia_gpu()
        if self._gpu_type == "amd":
            return self._amd_gpu()
        return {"type": self._gpu_type, "available": False}

    def _nvidia_gpu(self) -> dict:
        try:
            result = subprocess.run([
                "nvidia-smi",
                "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu",
                "--format=csv,noheader,nounits",
            ], capture_output=True, text=True, timeout=5)
            parts = [part.strip() for part in result.stdout.strip().split(",")]
            if result.returncode == 0 and len(parts) >= 5:
                return {
                    "type": "nvidia",
                    "available": True,
                    "name": parts[0],
                    "util_percent": int(parts[1]),
                    "mem_used_mb": int(parts[2]),
                    "mem_total_mb": int(parts[3]),
                    "temp_c": int(parts[4]),
                }
        except Exception:
            pass
        return {"type": "nvidia", "available": False}

    def _amd_gpu(self) -> dict:
        cards = list(Path("/sys/class/drm").glob("card*/device"))
        if not cards:
            return {"type": "amd", "available": False}
        info = {"type": "amd", "available": True}
        card = cards[0]
        try:
            busy = card / "gpu_busy_percent"
            total = card / "mem_info_vram_total"
            used = card / "mem_info_vram_used"
            if busy.exists():
                info["util_percent"] = int(busy.read_text(encoding="utf-8").strip())
            if total.exists() and used.exists():
                info["mem_total_mb"] = int(total.read_text(encoding="utf-8").strip()) // 1_000_000
                info["mem_used_mb"] = int(used.read_text(encoding="utf-8").strip()) // 1_000_000
        except OSError:
            pass
        return info

    def _battery(self) -> dict | None:
        try:
            battery = psutil.sensors_battery()
        except Exception:
            return None
        if not battery:
            return None
        return {"percent": round(battery.percent, 1), "plugged_in": battery.power_plugged}

    def _top_processes(self) -> list[dict]:
        processes = sorted(psutil.process_iter(["pid", "name", "cpu_percent", "memory_percent"]), key=lambda proc: proc.info.get("cpu_percent", 0) or 0, reverse=True)
        return [{"pid": proc.info["pid"], "name": proc.info["name"], "cpu_pct": round(proc.info.get("cpu_percent", 0) or 0, 1), "mem_pct": round(proc.info.get("memory_percent", 0) or 0, 1)} for proc in processes[:5]]
