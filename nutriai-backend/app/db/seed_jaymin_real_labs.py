"""Real Labcorp timeline for jaymin@nutriai.app (demo pitch)."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List

_DATA_PATH = Path(__file__).with_suffix(".json")
_PAYLOAD = json.loads(_DATA_PATH.read_text(encoding="utf-8"))
PATIENT_DEMOGRAPHICS: Dict[str, Any] = _PAYLOAD.get("demographics") or {}


def build_jaymin_real_lab_timeline(user_id: int) -> List[Dict[str, Any]]:
    rebuilt: List[Dict[str, Any]] = []
    for p in _PAYLOAD.get("panels") or []:
        item = dict(p)
        item["user_id"] = user_id
        item["id"] = int(item["id"]) % 1_000_000_000 + int(user_id) * 17
        rebuilt.append(item)
    return rebuilt
