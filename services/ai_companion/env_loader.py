"""Zero-dependency hot-reloading `.env` loader for StudyGames AI Safe Companion."""
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENV_PATH = ROOT / ".env"

_LAST_MTIME_NS: int = -1
_MANAGED_KEYS: set[str] = set()


def load_dotenv_if_changed(env_file: Path | None = None) -> dict[str, str]:
    """Load or hot-reload `<workspace>/.env` whenever its modification timestamp changes."""
    global _LAST_MTIME_NS
    target = env_file or ENV_PATH
    if not target.is_file():
        return {}
    try:
        mtime_ns = target.stat().st_mtime_ns
    except OSError:
        return {}
    if env_file is None and mtime_ns == _LAST_MTIME_NS:
        return {}

    parsed: dict[str, str] = {}
    try:
        raw = target.read_text(encoding="utf-8-sig")
    except OSError:
        return {}

    for line in raw.splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        if s.startswith("export "):
            s = s[7:].strip()
        if "=" not in s:
            continue
        k, v = s.split("=", 1)
        key = k.strip()
        val = v.strip()
        if len(val) >= 2 and ((val[0] == val[-1] == '"') or (val[0] == val[-1] == "'")):
            val = val[1:-1].strip()
        if key:
            parsed[key] = val

    if env_file is None:
        for old_k in list(_MANAGED_KEYS):
            if old_k not in parsed or not parsed[old_k]:
                os.environ.pop(old_k, None)
                _MANAGED_KEYS.discard(old_k)
        for k, v in parsed.items():
            if v:
                os.environ[k] = v
                _MANAGED_KEYS.add(k)
        _LAST_MTIME_NS = mtime_ns
    else:
        for k, v in parsed.items():
            if v:
                os.environ[k] = v
    return parsed
