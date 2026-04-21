"""
build_dashboard.py — Generates docs/index.html from data.json + template
"""

import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from collections import defaultdict

logger = logging.getLogger(__name__)

DATA_PATH = Path(__file__).parent.parent / "data" / "data.json"
TEMPLATE_PATH = Path(__file__).parent.parent / "templates" / "dashboard.html.tpl"
OUTPUT_PATH = Path(__file__).parent.parent / "docs" / "index.html"


def _build_chart_data(records: list) -> list:
    """Aggregate spend + revenue by date_stop (day-level)."""
    by_date: dict = defaultdict(lambda: {"spend": 0.0, "revenue": 0.0})
    for r in records:
        date = r.get("date_stop") or r.get("date_start", "")
        if not date:
            continue
        by_date[date]["spend"] += r.get("spend", 0) or 0
        by_date[date]["revenue"] += r.get("revenue", 0) or 0

    return [
        {"date": d, "spend": round(v["spend"], 2), "revenue": round(v["revenue"], 2)}
        for d, v in sorted(by_date.items())
    ]


def _compute_top_creators(records: list, n: int = 10) -> list:
    creators: dict = {}
    for r in records:
        if not r.get("is_influence"):
            continue
        handle = r.get("creator_handle") or r.get("creator_ig_id") or "Inconnu"
        if handle not in creators:
            creators[handle] = {"handle": handle, "spend": 0.0, "revenue": 0.0, "reach": 0, "ads": 0}
        creators[handle]["spend"] += r.get("spend", 0) or 0
        creators[handle]["revenue"] += r.get("revenue", 0) or 0
        creators[handle]["reach"] += r.get("reach", 0) or 0
        creators[handle]["ads"] += 1

    for c in creators.values():
        c["roas"] = round(c["revenue"] / c["spend"], 2) if c["spend"] > 0 else 0

    ranked = sorted(creators.values(), key=lambda x: x["roas"], reverse=True)
    return ranked[:n]


def build(records=None) -> Path:
    if records is None:
        if not DATA_PATH.exists():
            raise FileNotFoundError(f"data.json not found at {DATA_PATH}")
        with open(DATA_PATH) as f:
            records = json.load(f)

    if not TEMPLATE_PATH.exists():
        raise FileNotFoundError(f"Template not found at {TEMPLATE_PATH}")

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    template = TEMPLATE_PATH.read_text(encoding="utf-8")
    last_updated = datetime.now(timezone.utc).strftime("%d/%m/%Y %H:%M UTC")
    chart_data = _build_chart_data(records)
    top_creators = _compute_top_creators(records)

    html = template.replace("__LAST_UPDATED__", last_updated)
    html = html.replace("__DATA_JSON__", json.dumps(records, ensure_ascii=False, default=str))
    html = html.replace("__TOP_CREATORS_JSON__", json.dumps(top_creators, ensure_ascii=False))
    html = html.replace("__CHART_DATA_JSON__", json.dumps(chart_data, ensure_ascii=False))

    OUTPUT_PATH.write_text(html, encoding="utf-8")
    logger.info(f"Dashboard written to {OUTPUT_PATH} ({OUTPUT_PATH.stat().st_size // 1024}KB)")
    logger.info(f"  Records: {len(records)} | Influence: {sum(1 for r in records if r.get('is_influence'))}")
    logger.info(f"  Creators detected: {len(top_creators)}")
    return OUTPUT_PATH
