"""P1 evidence inventory and native Windows/Godot performance capture (stdlib only).

Examples:
  python -X utf8 scripts/verify_p1.py inventory
  python -X utf8 scripts/verify_p1.py performance --rooms landmark_A --repeats 2
  python -X utf8 scripts/verify_p1.py performance --pilot --duration 3 --warmup 2 --repeats 1 --rooms landmark_A
  python -X utf8 scripts/verify_p1.py summarize .local/p1-performance-YYYYMMDD-HHMMSS

The pilot flag never produces acceptance evidence. Native measurements are scoped to
the current machine/profile and are not claims about low-end hardware or other presets.
"""
from __future__ import annotations

import argparse
import csv
import ctypes
from ctypes import wintypes
import datetime as dt
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import statistics
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GODOT = Path(r"F:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe")
METRICS = (
    "wall_frame_ms", "engine_process_ms", "engine_physics_ms",
    "viewport_render_cpu_ms", "viewport_render_gpu_ms", "frame_setup_cpu_ms",
    "rendered_objects", "rendered_vertices_or_indices", "draw_calls",
    "engine_static_memory_bytes", "video_memory_bytes",
)
MEMORY_METRICS = ("working_set_bytes", "private_commit_bytes", "peak_working_set_bytes")
PROCESS_METRICS = (*MEMORY_METRICS, "process_cpu_percent_machine", "process_cpu_percent_single_core")
PROCESS_FIELDS = ("epoch", *PROCESS_METRICS, "process_cpu_time_seconds", "foreground_process_id", "game_is_foreground")


def write_json(path: Path, data: object) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def source_manifest() -> dict[str, str]:
    return {str(p.relative_to(ROOT)).replace("\\", "/"): digest(p)
            for p in sorted((ROOT / "game").rglob("*"))
            if p.is_file()
            and ".godot" not in p.relative_to(ROOT / "game").parts[:-1]
            and not p.name.endswith("-report.json")}


def powershell_json(script: str) -> object:
    proc = subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command",
                           "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; " + script],
                          capture_output=True, text=True, encoding="utf-8", timeout=30,
                          creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    if proc.returncode:
        return {"error": proc.stderr.strip()}
    try:
        return json.loads(proc.stdout.strip())
    except ValueError:
        return {"error": proc.stdout[:1000]}


def preflight() -> dict:
    hardware = powershell_json(
        "$cpu=@(Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors); "
        "$gpu=@(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,DriverDate,AdapterRAM); "
        "$os=Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber; "
        "$apps=@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match '^(Godot.*|AlphabetIsland.*|blender)\\.exe$'} "
        "| Select-Object ProcessId,Name,CommandLine); "
        "@{cpu=$cpu;gpu=$gpu;os=$os;other_render_processes=$apps}|ConvertTo-Json -Depth 5")
    return {"captured_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "platform": platform.platform(),
            "python": sys.version, "windows": hardware}


def gpu_conditions() -> dict:
    """Optional NVIDIA pre/post telemetry; not a continuous thermal trace."""
    fields = "name,driver_version,pstate,temperature.gpu,utilization.gpu,clocks.current.graphics,clocks.current.memory,power.draw"
    try:
        result = subprocess.run(["nvidia-smi", "--query-gpu=" + fields, "--format=csv,noheader,nounits"],
                                capture_output=True, text=True, encoding="utf-8", timeout=10,
                                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        return {"available": result.returncode == 0, "fields": fields.split(","),
                "raw_csv": result.stdout.strip(), "error": result.stderr.strip(),
                "epoch": time.time(), "scope": "pre_or_post_snapshot_only_not_continuous_throttling_verification"}
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"available": False, "reason": str(exc)}


class ProcessMemory:
    """GetProcessMemoryInfo: RSS is WorkingSetSize; private commit is PrivateUsage."""
    class Counters(ctypes.Structure):
        _fields_ = [
            ("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD),
            ("PeakWorkingSetSize", ctypes.c_size_t), ("WorkingSetSize", ctypes.c_size_t),
            ("QuotaPeakPagedPoolUsage", ctypes.c_size_t), ("QuotaPagedPoolUsage", ctypes.c_size_t),
            ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t), ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
            ("PagefileUsage", ctypes.c_size_t), ("PeakPagefileUsage", ctypes.c_size_t),
            ("PrivateUsage", ctypes.c_size_t),
        ]

    def __init__(self, pid: int):
        self.pid = pid
        self.kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        self.psapi = ctypes.WinDLL("psapi", use_last_error=True)
        self.user = ctypes.WinDLL("user32", use_last_error=True)
        self.user.GetForegroundWindow.argtypes = []
        self.user.GetForegroundWindow.restype = wintypes.HWND
        self.user.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
        self.user.GetWindowThreadProcessId.restype = wintypes.DWORD
        self.kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        self.kernel.OpenProcess.restype = wintypes.HANDLE
        self.kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        self.psapi.GetProcessMemoryInfo.argtypes = [wintypes.HANDLE, ctypes.POINTER(self.Counters), wintypes.DWORD]
        self.psapi.GetProcessMemoryInfo.restype = wintypes.BOOL
        self.kernel.GetProcessTimes.argtypes = [wintypes.HANDLE, *([ctypes.POINTER(wintypes.FILETIME)] * 4)]
        self.kernel.GetProcessTimes.restype = wintypes.BOOL
        self.handle = self.kernel.OpenProcess(0x0400 | 0x0010, False, pid)
        if not self.handle:
            raise OSError(ctypes.get_last_error(), "OpenProcess failed")
        self.previous_cpu_seconds = None
        self.previous_wall = None

    def sample(self) -> dict:
        info = self.Counters()
        info.cb = ctypes.sizeof(info)
        if not self.psapi.GetProcessMemoryInfo(self.handle, ctypes.byref(info), info.cb):
            raise OSError(ctypes.get_last_error(), "GetProcessMemoryInfo failed")
        created, exited, kernel, user = (wintypes.FILETIME() for _ in range(4))
        if not self.kernel.GetProcessTimes(self.handle, ctypes.byref(created), ctypes.byref(exited), ctypes.byref(kernel), ctypes.byref(user)):
            raise OSError(ctypes.get_last_error(), "GetProcessTimes failed")
        cpu_seconds = ((kernel.dwHighDateTime << 32) + kernel.dwLowDateTime +
                       (user.dwHighDateTime << 32) + user.dwLowDateTime) / 10_000_000
        now = time.monotonic()
        cpu_percent = float("nan") if self.previous_wall is None else max(
            0.0, (cpu_seconds - self.previous_cpu_seconds) / (now - self.previous_wall) * 100)
        self.previous_cpu_seconds, self.previous_wall = cpu_seconds, now
        foreground_pid = wintypes.DWORD()
        foreground_window = self.user.GetForegroundWindow()
        if foreground_window:
            self.user.GetWindowThreadProcessId(foreground_window, ctypes.byref(foreground_pid))
        return {"epoch": time.time(), "working_set_bytes": info.WorkingSetSize,
                "private_commit_bytes": info.PrivateUsage, "peak_working_set_bytes": info.PeakWorkingSetSize,
                "process_cpu_percent_machine": cpu_percent / (os.cpu_count() or 1),
                "process_cpu_percent_single_core": cpu_percent, "process_cpu_time_seconds": cpu_seconds,
                "foreground_process_id": foreground_pid.value, "game_is_foreground": int(foreground_pid.value == self.pid)}

    def close(self) -> None:
        if self.handle:
            self.kernel.CloseHandle(self.handle)
            self.handle = None


def percentile(values: list[float], p: float) -> float:
    ordered = sorted(values)
    index = (len(ordered) - 1) * p
    left, right = math.floor(index), math.ceil(index)
    return ordered[left] + (ordered[right] - ordered[left]) * (index - left)


def stats(values: list[float], zero_means_unavailable: bool = False) -> dict:
    values = [v for v in values if math.isfinite(v)]
    if not values or (zero_means_unavailable and not any(v > 0 for v in values)):
        return {"available": False, "n": len(values), "p50": None, "p95": None, "p99": None,
                "reason": "all_zero_timer_or_no_samples"}
    return {"available": True, "n": len(values), "p50": percentile(values, .50),
            "p95": percentile(values, .95), "p99": percentile(values, .99),
            "mean": statistics.fmean(values), "min": min(values), "max": max(values)}


def read_csv(path: Path) -> list[dict[str, float]]:
    with path.open(encoding="utf-8", newline="") as stream:
        return [{key: float(value) for key, value in row.items()} for row in csv.DictReader(stream)]


def summarize(output: Path) -> dict:
    raw_path = output / "raw-report.json"
    raw = json.loads(raw_path.read_text(encoding="utf-8")) if raw_path.exists() else {}
    wrapper = json.loads((output / "run-metadata.json").read_text(encoding="utf-8"))
    memories = read_csv(output / "process-memory.csv") if (output / "process-memory.csv").exists() else []
    stages = []
    for stage in raw.get("stages", []):
        rows = read_csv(output / stage["frame_csv"])
        memory_rows = [r for r in memories if stage["sample_started_utc"] <= r["epoch"] <= stage["sample_ended_utc"]]
        metrics = {name: stats([r[name] for r in rows],
                   zero_means_unavailable=name in ("viewport_render_gpu_ms", "viewport_render_cpu_ms", "frame_setup_cpu_ms"))
                   for name in METRICS}
        metrics.update({name: stats([r[name] for r in memory_rows]) for name in PROCESS_METRICS})
        os_focus_rows = [r for r in memory_rows if "game_is_foreground" in r]
        os_focus = {"available": bool(os_focus_rows), "samples": len(os_focus_rows),
                    "foreground_samples": sum(bool(r["game_is_foreground"]) for r in os_focus_rows),
                    "background_samples": sum(not bool(r["game_is_foreground"]) for r in os_focus_rows),
                    "method": "Windows GetForegroundWindow/GetWindowThreadProcessId, read-only at 0.25s interval"}
        stages.append({**stage, "metrics": metrics, "process_memory_samples": len(memory_rows), "windows_focus_observation": os_focus})
    pairs = []
    keys = sorted({(s["room"], s["repetition"]) for s in stages})
    for room, repetition in keys:
        group = [s for s in stages if s["room"] == room and s["repetition"] == repetition]
        off = next((s for s in group if not s["environment_enabled"]), None)
        on = next((s for s in group if s["environment_enabled"]), None)
        if not off or not on:
            pairs.append({"room": room, "repetition": repetition, "comparable": False, "reason": "missing_pair"})
            continue
        matched_fields = ("window_size", "render_texture_size", "camera_size", "weather", "day_phase", "paired_structure_signature", "geometry")
        mismatches = [name for name in matched_fields if name not in on or name not in off or on[name] != off[name]]
        def actors_match(a: object, b: object) -> bool:
            if not isinstance(a, list) or not isinstance(b, list) or len(a) != len(b):
                return False
            for left_actor, right_actor in zip(a, b):
                if any(left_actor.get(k) != right_actor.get(k) for k in ("id", "kind", "action", "visible")):
                    return False
                left_transform, right_transform = left_actor.get("transform", []), right_actor.get("transform", [])
                if len(left_transform) != 12 or len(right_transform) != 12 or not all(
                    math.isclose(left, right, rel_tol=0, abs_tol=.001) for left, right in zip(left_transform, right_transform)):
                    return False
            return True
        if not actors_match(off.get("actor_layout_before"), on.get("actor_layout_before")):
            mismatches.append("resident_actor_start_layout")
        if not actors_match(off.get("actor_layout_before"), off.get("actor_layout_after")) or not actors_match(on.get("actor_layout_before"), on.get("actor_layout_after")):
            mismatches.append("resident_actor_layout_changed_during_sample")
        if any(stage.get(boundary, {}).get("spawn_failures") for stage in (off, on) for boundary in ("start_world_status", "end_world_status")):
            mismatches.append("resident_actor_spawn_failures")
        for field in ("foliage_count", "water_count", "rain_instances"):
            if off.get("start_world_status", {}).get(field) != on.get("start_world_status", {}).get(field):
                mismatches.append(field)
        off_focus, on_focus = off["windows_focus_observation"], on["windows_focus_observation"]
        focus_fraction_delta = None
        if off_focus["samples"] and on_focus["samples"]:
            focus_fraction_delta = abs(off_focus["foreground_samples"] / off_focus["samples"] - on_focus["foreground_samples"] / on_focus["samples"])
            if focus_fraction_delta > .05:
                mismatches.append("windows_foreground_fraction_differs_over_5_percent_points")
        def camera_numbers(stage: dict) -> list[float]:
            return [float(v) for v in re.findall(r"[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?", stage["camera_transform"])]
        a_camera, b_camera = camera_numbers(off), camera_numbers(on)
        if len(a_camera) != len(b_camera) or not all(math.isclose(a, b, rel_tol=0, abs_tol=.001) for a, b in zip(a_camera, b_camera)):
            mismatches.append("camera_transform")
        delta = {}
        for metric in (*METRICS, *PROCESS_METRICS):
            a, b = off["metrics"][metric], on["metrics"][metric]
            delta[metric] = {q: b[q] - a[q] if a["available"] and b["available"] else None for q in ("p50", "p95", "p99")}
        pairs.append({"room": room, "repetition": repetition, "off": off["id"], "on": on["id"],
                      "comparable": not mismatches and not off["failures"] and not on["failures"],
                      "mismatched_fields": mismatches, "camera_numeric_absolute_tolerance": .001,
                      "windows_foreground_fraction_absolute_delta": focus_fraction_delta,
                      "windows_foreground_fraction_tolerance": .05, "on_minus_off": delta})
    reasons = list(raw.get("failures", []))
    if not raw.get("complete"):
        reasons.append("native_run_incomplete")
    if wrapper.get("pilot"):
        reasons.append("pilot_run_is_not_acceptance")
    if raw.get("sample_seconds_requested", 0) < 60 or raw.get("warmup_seconds_requested", 0) < 10:
        reasons.append("insufficient_warmup_or_sample_duration")
    if not wrapper.get("source_files_unchanged"):
        reasons.append("source_changed_during_capture")
    if wrapper.get("returncode") != 0:
        reasons.append("engine_nonzero_exit")
    if wrapper.get("memory_process_id") != raw.get("hardware", {}).get("process_id"):
        reasons.append("memory_pid_does_not_match_native_engine")
    if wrapper.get("runtime_error_lines"):
        reasons.append("engine_logged_runtime_errors")
    if wrapper.get("conflicting_processes"):
        reasons.append("other_godot_game_editor_or_blender_processes_present")
    if not stages or not all(s["process_memory_samples"] >= 10 for s in stages):
        reasons.append("insufficient_process_memory_samples")
    if stages and not all(s["metrics"]["viewport_render_gpu_ms"]["available"] for s in stages):
        reasons.append("root_viewport_gpu_timer_unavailable")
    if stages and not all(s["windows_focus_observation"]["available"] for s in stages):
        reasons.append("windows_foreground_observation_unavailable")
    if stages and any(not s.get("background_fixture") and s["windows_focus_observation"]["background_samples"] for s in stages):
        reasons.append("windows_observed_background_during_foreground_required_capture")
    if not pairs or not all(p["comparable"] for p in pairs):
        reasons.append("off_on_pair_not_comparable")
    summary = {"schema_version": 1, "kind": "p1_current_hardware_performance_evidence",
               "formal_record_valid": not reasons, "invalid_reasons": reasons,
               "hardware": raw.get("hardware", {}), "wrapper": wrapper,
               "stages": stages, "pairs": pairs,
               "metric_definitions": {
                   "engine_process_ms": "Diagnostic Performance.TIME_PROCESS monitor: this engine publishes the preceding one-second interval maximum, held between updates. Not per-frame CPU timing; prior screenshot/setup work can remain cached.",
                   "engine_physics_ms": "Diagnostic Performance.TIME_PHYSICS_PROCESS monitor: preceding one-second interval maximum, not per-frame physics timing.",
                   "viewport_render_cpu_ms": "Measured root-viewport render CPU time only, excluding other engine subsystems and other viewports.",
                   "process_cpu_percent_machine": "Windows cumulative process kernel+user CPU time delta divided by elapsed wall time and logical processor count.",
                   "engine_monitor_implementation_source": "https://github.com/godotengine/godot/blob/ed1daf0bf/main/main.cpp#L4723-L4761"},
               "limitations": [
                   "One actual machine and current GL Compatibility settings; no low/standard/high preset acceptance.",
                   "Static camera and stationary player. Does not measure gameplay travel or word-story animation.",
                   "Environment off disables foliage deformation, water overlay and rain display while retaining actors, weather lighting/fog and resident resources. The delta is not total weather cost or asset-unloading memory savings.",
                   "Viewport GPU/CPU timers cover the root viewport only; they are not whole-process GPU time.",
                   "Rendered primitives monitor counts vertices/indices across passes, not triangles.",
                   "scene_mesh_triangles counts visible-in-tree mesh geometry, including off-camera meshes; excludes MultiMesh and repeated render passes.",
                   "Godot monitor updates can lag. Recorder overhead is present in both modes.",
                   "TIME_PROCESS and TIME_PHYSICS_PROCESS are cached one-second maxima in this engine. Their sampled quantiles are diagnostics, not per-frame CPU distributions or CPU budget acceptance; screenshot/setup spikes may remain cached.",
                   "GPU timer all-zero values are reported unavailable; CPU timings are not substituted for GPU.",
                   "Working set is resident process memory; private commit and engine static memory are separate metrics.",
                   "If background fixture is enabled, it overrides focus-pause only inside the profiler; this is not foreground user experience or normal game background behavior.",
                   "Requested NO_FOCUS does not prove background operation. Per-stage Windows foreground PID observations report actual foreground/background samples separately from Godot's focus flag.",
                   "Windows compositor occlusion is not separately measured. Do not minimize the capture window or overlap competing render tests.",
                   "This records performance; device-class budgets require designated target hardware and acceptance thresholds.",
               ]}
    write_json(output / "summary.json", summary)
    hw = summary["hardware"]
    lines = ["# P1 原生性能记录", "", f"正式记录有效：{'是' if summary['formal_record_valid'] else '否'}",
             f"限制原因：{', '.join(reasons) or '无'}", "",
             f"CPU：{hw.get('cpu', '未记录')}；GPU：{hw.get('gpu', '未记录')}；图形接口：{hw.get('graphics_api', '未记录')}。",
             f"引擎：{hw.get('engine', {}).get('string', '未记录')}；系统：{hw.get('os', '未记录')} {hw.get('os_version', '')}。",
             "GPU 驱动及完整硬件信息见 hardware-preflight.json；源文件清单、原生窗口/内容分辨率和样本均保存在 JSON/CSV 中。", "",
             "| 场景 | 动态 | 帧耗时 p50/p95/p99 ms | GPU 根视口 p50/p95 ms | Draw calls p50 | 进程 RSS p50 MiB |",
             "|---|---|---:|---:|---:|---:|"]
    for stage in stages:
        m = stage["metrics"]
        def value(metric: str, q: str = "p50", divisor: float = 1) -> str:
            v = m[metric][q]
            return "不可用" if v is None else f"{v/divisor:.3f}"
        frame = "/".join(value("wall_frame_ms", q) for q in ("p50", "p95", "p99"))
        gpu = "/".join(value("viewport_render_gpu_ms", q) for q in ("p50", "p95"))
        lines.append(f"| {stage['id']} | {'开' if stage['environment_enabled'] else '关'} | {frame} | "
                     f"{gpu} | {value('draw_calls')} | {value('working_set_bytes', divisor=1048576)} |")
    lines += ["", "| 场景 | process 峰值监视器 p50/p95 ms（诊断） | 根视口渲染 CPU p50/p95 ms | Windows 进程 CPU 整机 p50/p95 % | 三角形（可见场景树） | Windows 实际前台/后台样本 |",
              "|---|---:|---:|---:|---:|---:|"]
    for stage in stages:
        m = stage["metrics"]
        def pair(metric: str) -> str:
            return "/".join("不可用" if m[metric][q] is None else f"{m[metric][q]:.3f}" for q in ("p50", "p95"))
        focus = stage["windows_focus_observation"]
        geometry = stage.get("geometry", {})
        lines.append(f"| {stage['id']} | {pair('engine_process_ms')} | {pair('viewport_render_cpu_ms')} | "
                     f"{pair('process_cpu_percent_machine')} | {geometry.get('scene_mesh_triangles', '见 JSON')} | "
                     f"{focus['foreground_samples']}/{focus['background_samples']} |")
    lines += ["", "| 同场景配对 | 可比 | 开启−关闭帧时 p50/p95 ms | 开启−关闭根视口 GPU p50/p95 ms | 开启−关闭 draw calls p50 |",
              "|---|---|---:|---:|---:|"]
    for paired in pairs:
        def delta_value(metric: str, quantiles: tuple[str, ...] = ("p50", "p95")) -> str:
            values = paired.get("on_minus_off", {}).get(metric, {})
            return "/".join("不可用" if values.get(q) is None else f"{values[q]:+.3f}" for q in quantiles)
        lines.append(f"| {paired['room']} r{paired['repetition']} | {'是' if paired['comparable'] else '否'} | "
                     f"{delta_value('wall_frame_ms')} | {delta_value('viewport_render_gpu_ms')} | {delta_value('draw_calls', ('p50',))} |")
    lines += ["", "## 测量边界", "", *[f"- {text}" for text in summary["limitations"]], ""]
    (output / "summary.md").write_text("\n".join(lines), encoding="utf-8")
    return summary


def performance(args: argparse.Namespace) -> int:
    if os.name != "nt":
        raise SystemExit("The native process-memory collector currently requires Windows.")
    if not args.godot.is_file():
        raise SystemExit(f"Godot executable does not exist: {args.godot}")
    if args.godot.name.lower().endswith("_console.exe"):
        sibling = args.godot.with_name(args.godot.name[:-12] + ".exe")
        if not sibling.is_file():
            raise SystemExit("Use the actual Godot executable, not its small console process wrapper.")
        args.godot = sibling
    if not args.pilot and (args.duration < 60 or args.warmup < 10):
        raise SystemExit("Formal runs require duration >= 60 and warmup >= 10. Use --pilot for tool checks.")
    output = (args.output or ROOT / ".local" / ("p1-performance-" + dt.datetime.now().strftime("%Y%m%d-%H%M%S"))).resolve()
    output.mkdir(parents=True, exist_ok=False)
    hardware = preflight()
    write_json(output / "hardware-preflight.json", hardware)
    apps = hardware.get("windows", {}).get("other_render_processes", []) or []
    conflicts = [p for p in apps if re.search(r"^(Godot.*|AlphabetIsland.*|blender)\.exe$", p.get("Name", ""), re.I)]
    if conflicts and not args.allow_conflicts:
        write_json(output / "preflight-rejected.json", {"reason": "other game/editor/Blender process present", "processes": conflicts})
        raise SystemExit(f"Other game/editor/Blender process present. Stop it before measuring. Evidence: {output}")
    before = source_manifest()
    write_json(output / "source-manifest-before.json", before)
    command = [str(args.godot), "--path", str(ROOT / "game"), "--script", "res://tests/test_p1_performance.gd",
               "--", "--test-harness", f"--p1-output={output.as_posix()}", f"--p1-duration={args.duration}",
               f"--p1-warmup={args.warmup}", f"--p1-repeats={args.repeats}", f"--p1-rooms={args.rooms}",
               f"--p1-width={args.width}", f"--p1-height={args.height}", f"--p1-weather={args.weather}",
               f"--p1-day-phase={args.day_phase}", f"--p1-motion-seconds={args.motion_seconds}",
               f"--p1-motion-fps={args.motion_fps}"]
    if args.allow_background:
        command.append("--p1-allow-background")
    metadata = {"command": command, "pilot": args.pilot, "conflicting_processes": conflicts,
                "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
                "memory_sample_interval_s": .25, "output": str(output), "gpu_conditions_before": gpu_conditions()}
    write_json(output / "run-metadata.json", metadata)
    timeout = args.timeout or (len(args.rooms.split(",")) * (args.repeats * 2 * (args.duration + args.warmup + 30) + args.motion_seconds + 15) + 150)
    stdout_path, stderr_path = output / "godot.stdout.log", output / "godot.stderr.log"
    rows, memory_errors = [], []
    started = time.monotonic()
    last_progress = None
    returncode, timed_out = None, False
    startupinfo = None
    if args.allow_background:
        # Windows honors this for the process's first ShowWindow call.
        # Request no startup activation; actual OS focus is observed because a
        # renderer/driver may still activate its initial window on this machine.
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = 4  # SW_SHOWNOACTIVATE
    with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
        process = subprocess.Popen(command, cwd=ROOT, stdout=stdout, stderr=stderr,
                                   creationflags=subprocess.CREATE_NO_WINDOW, startupinfo=startupinfo)
        metadata["memory_process_id"] = process.pid
        write_json(output / "run-metadata.json", metadata)
        memory = ProcessMemory(process.pid)
        try:
            while process.poll() is None:
                if time.monotonic() - started > timeout:
                    timed_out = True
                    process.terminate()  # Only the profiler's own child.
                    break
                try:
                    rows.append(memory.sample())
                except OSError as exc:
                    memory_errors.append(str(exc))
                progress_path = output / "progress.json"
                try:
                    progress = json.loads(progress_path.read_text(encoding="utf-8"))
                    key = (progress.get("stage"), progress.get("phase"))
                    if key != last_progress:
                        print(f"{key[0] or 'startup'}: {key[1]}", flush=True)
                        last_progress = key
                except (OSError, ValueError):
                    pass
                time.sleep(.25)
            returncode = process.wait(timeout=15)
        finally:
            memory.close()
            if process.poll() is None:
                process.kill()
                process.wait(timeout=15)
    with (output / "process-memory.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=PROCESS_FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    after = source_manifest()
    write_json(output / "source-manifest-after.json", after)
    logs = stdout_path.read_text(encoding="utf-8", errors="replace") + "\n" + stderr_path.read_text(encoding="utf-8", errors="replace")
    metadata.update({"returncode": returncode, "timed_out": timed_out, "elapsed_s": time.monotonic() - started,
                     "ended_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "memory_errors": memory_errors,
                     "source_files_unchanged": before == after,
                     "gpu_conditions_after": gpu_conditions(),
                     "runtime_error_lines": [line for line in logs.splitlines() if re.search(r"SCRIPT ERROR|ERROR:", line)]})
    write_json(output / "run-metadata.json", metadata)
    summary = summarize(output)
    print(json.dumps({"output": str(output), "formal_record_valid": summary["formal_record_valid"],
                      "invalid_reasons": summary["invalid_reasons"], "stages": len(summary["stages"])}, ensure_ascii=False), flush=True)
    return 0 if summary["formal_record_valid"] or (args.pilot and returncode == 0 and not metadata["runtime_error_lines"]) else 1


def inventory() -> int:
    evidence = []
    candidates = list((ROOT / "build/logs").glob("*.stdout.log"))
    candidates += list((ROOT / "docs/verification/v0.5.0").glob("*report.json"))
    candidates += list((ROOT / ".local/validation").glob("*report.json"))
    candidates += list((ROOT / "game/actors/p1").glob("*report.json"))
    for path in sorted(candidates):
        text = path.read_text(encoding="utf-8", errors="replace")
        details = {}
        if path.suffix == ".json":
            try:
                parsed = json.loads(text)
                for key in ("status", "result", "version", "scope", "production_save_unchanged"):
                    if key in parsed:
                        details[key] = parsed[key]
                checks = parsed.get("checks")
                if isinstance(checks, int):
                    details["check_count"] = checks
                elif isinstance(checks, list):
                    details["check_count"] = len(checks)
                    details["failed_check_count"] = sum(
                        isinstance(c, dict) and (c.get("passed") is False or c.get("pass") is False) for c in checks)
                failures = parsed.get("failures")
                if isinstance(failures, list):
                    details["failure_count"] = len(failures)
            except (ValueError, AttributeError):
                pass
        stderr = path.with_name(path.name.replace(".stdout.log", ".stderr.log"))
        error_lines = []
        if stderr != path and stderr.is_file():
            error_lines = [line for line in stderr.read_text(encoding="utf-8", errors="replace").splitlines()
                           if re.search(r"SCRIPT ERROR|ERROR:", line)]
        evidence.append({"path": path.relative_to(ROOT).as_posix(), "sha256": digest(path),
                         "modified_utc": dt.datetime.fromtimestamp(path.stat().st_mtime, dt.timezone.utc).isoformat(),
                         "report_summary": details, "paired_stderr_runtime_errors": error_lines,
                         "result_lines": [line[:1500] for line in text.splitlines()
                                          if re.search(r"RESULT|PASS:|FAIL:|checks=|checks,|_REPORT|RELEASE_SMOKE", line)][-4:]
                                          if path.suffix != ".json" else [],
                         "boundary": "Historical evidence only; compare its source/profile and date before reusing for P1."})
    print(json.dumps({"kind": "p1_evidence_inventory", "files": evidence}, ensure_ascii=False, indent=2))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="mode", required=True)
    sub.add_parser("inventory")
    summary = sub.add_parser("summarize")
    summary.add_argument("output", type=Path)
    perf = sub.add_parser("performance")
    perf.add_argument("--godot", type=Path, default=DEFAULT_GODOT)
    perf.add_argument("--output", type=Path)
    perf.add_argument("--duration", type=float, default=60)
    perf.add_argument("--warmup", type=float, default=10)
    perf.add_argument("--repeats", type=int, choices=range(1, 5), default=2)
    perf.add_argument("--rooms", default="landmark_A,village,school")
    perf.add_argument("--width", type=int, default=1440)
    perf.add_argument("--height", type=int, default=900)
    perf.add_argument("--weather", choices=["clear", "cloudy", "light_rain", "mist"], default="clear")
    perf.add_argument("--day-phase", choices=["dawn", "day", "dusk", "night"], default="day")
    perf.add_argument("--timeout", type=float)
    perf.add_argument("--motion-seconds", type=float, default=0, help="Optional native frame sequence after the last on sample in each room, outside timing.")
    perf.add_argument("--motion-fps", type=float, default=4)
    perf.add_argument("--allow-background", action="store_true", help="Native NO_FOCUS benchmark window with test-only focus-pause override, recorded as background comparison.")
    perf.add_argument("--pilot", action="store_true")
    perf.add_argument("--allow-conflicts", action="store_true", help="Allows a diagnostic run only; invalidates formal evidence.")
    args = parser.parse_args()
    if args.mode == "performance":
        return performance(args)
    if args.mode == "inventory":
        return inventory()
    result = summarize(args.output.resolve())
    print(json.dumps({"formal_record_valid": result["formal_record_valid"], "invalid_reasons": result["invalid_reasons"]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
