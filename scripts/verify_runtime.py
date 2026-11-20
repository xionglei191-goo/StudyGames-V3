r"""Run the save, economy, voice and shared-profile regressions in isolated saves.

Example: .local\ai-companion-venv\Scripts\python.exe scripts\verify_runtime.py --native --real-speech
Logs and save hashes stay under .local; no player save is created or restored here.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
GODOT_SUITES = (
    "test_state", "test_home_state", "test_creation_state", "test_shared_profile",
    "test_shared_outfit_flow", "test_character_voices", "test_progression_integrity",
    "test_ai_voice_lifecycle", "test_ai_voice_slow_response", "test_v4_overhaul", "test_v5_world_and_palace",
    "test_v6_home_school_immersion", "test_v7_level_exp_economy",
)
ENGINE_ERROR = re.compile(r"(?m)^(?:SCRIPT ERROR:|ERROR:|FATAL:)")


def protected_saves():
    paths = set()
    profiles = ROOT / ".local/shared-profiles"
    if profiles.exists():
        paths.update(profiles.rglob("progress.json"))
        paths.update(profiles.rglob("progress.json.bak"))
    userdata = Path(os.environ.get("APPDATA", Path.home() / ".local/share")) / "Godot/app_userdata/字母岛 · 我的第一天"
    for name in ("island-save-v1.json", "island-save-v1.json.bak"):
        candidate = userdata / name
        if candidate.is_file():
            paths.add(candidate)
    return {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(paths)}


def run_case(name, command, output, *, timeout=240, engine=False):
    env = os.environ.copy()
    env["PYTHONUTF8"] = "1"
    env["STUDYGAMES_NO_AUTO_SIDECAR"] = "1"
    start = time.monotonic()
    process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    timed_out = False
    try:
        raw, _ = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        if os.name == "nt":
            # Only this runner's child tree, never a discovered process or port.
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True, timeout=15,
                           creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        else:
            process.kill()
        raw, _ = process.communicate(timeout=15)
    log = raw.decode("utf-8", errors="replace")
    (output / (name + ".log")).write_text(log, encoding="utf-8")
    errors = ENGINE_ERROR.findall(log) if engine else []
    passed = process.returncode == 0 and not timed_out and not errors
    summary = [line for line in log.splitlines() if re.search(r"(?i)passed|failed|checks|failures|^PASS:|^Ran \d+|^OK$|BENCHMARK", line)]
    result = {"name":name, "passed":passed, "exit_code":process.returncode, "timed_out":timed_out,
              "engine_error_count":len(errors), "seconds":round(time.monotonic() - start, 3), "summary":summary[-5:]}
    print(f"{name}: {'PASS' if passed else 'FAIL'} ({result['seconds']}s)", flush=True)
    if not passed:
        print("\n".join(log.splitlines()[-20:]), flush=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--python", type=Path, dest="python_path")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--native", action="store_true", help="Also render and capture the native dialogue flow")
    parser.add_argument("--real-speech", action="store_true", help="Verify installed Piper/Vosk models offline in a separate cache")
    args = parser.parse_args()
    engine = args.godot or Path(os.environ.get("GODOT_PATH") or shutil.which("godot") or "F:/Tools/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe")
    python_path = args.python_path or ROOT / ".local/ai-companion-venv/Scripts/python.exe"
    if not python_path.is_file():
        python_path = Path(sys.executable)
    if not engine.is_file():
        parser.error("Godot was not found; pass --godot <executable>.")
    output = (args.output or ROOT / ".local/runtime-verification" / datetime.now().strftime("%Y%m%d-%H%M%S")).resolve()
    output.mkdir(parents=True, exist_ok=True)
    before = protected_saves()
    (output / "protected-saves.before.json").write_text(json.dumps(before, indent=2, ensure_ascii=False), encoding="utf-8")
    results = []
    for suite in GODOT_SUITES:
        results.append(run_case(suite, [str(engine), "--headless", "--path", str(ROOT / "game"), "--script", f"res://tests/{suite}.gd", "--", "--test-harness"], output, engine=True))
    results.append(run_case("speech_runtime", [str(python_path), "-m", "pytest", "services/ai_companion/tests/test_speech_runtime.py", "services/ai_companion/tests/test_companion_launcher.py", "-q", "--tb=short"], output))
    results.append(run_case("shared_web_native", [str(python_path), "-m", "unittest", "discover", "-s", "web", "-p", "test_*.py", "-q"], output))
    if args.real_speech:
        bootstrap = """
import os, sys
from pathlib import Path
os.environ['STUDYGAMES_TTS_MODE'] = 'offline'
for key in ('OPENAI_API_KEY','OPENAI_TTS_API_KEY','STUDYGAMES_CLOUD_TTS_KEY','DASHSCOPE_API_KEY'):
    os.environ.pop(key, None)
from services.ai_companion import speech_service, npc_companion, app
speech_service.CACHE_DIR = Path(sys.argv[1])
for module in (speech_service, npc_companion, app):
    module.load_dotenv_if_changed = lambda: {}
import pytest
raise SystemExit(pytest.main(['services/ai_companion/tests/test_ai_companion.py','-q','--tb=short']))
"""
        results.append(run_case("real_offline_speech", [str(python_path), "-c", bootstrap, str(output / "tts")], output, timeout=360))
    if args.native:
        results.append(run_case("native_voice_lifecycle", [str(engine), "--path", str(ROOT / "game"), "--script", "res://tests/test_ai_voice_lifecycle.gd", "--resolution", "1194x746", "--position", "60,70", "--audio-driver", "Dummy", "--", "--test-harness", "--capture-dir=" + str(output / "native")], output, engine=True))
    after = protected_saves()
    (output / "protected-saves.after.json").write_text(json.dumps(after, indent=2, ensure_ascii=False), encoding="utf-8")
    report = {"timestamp_utc":datetime.now(timezone.utc).isoformat(), "passed":all(r["passed"] for r in results) and before == after,
              "suite_count":len(results), "suites":results, "protected_save_files":len(before), "protected_saves_unchanged":before == after}
    (output / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Report: {output / 'report.json'}\nProtected saves unchanged: {before == after}", flush=True)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
