"""
main.py — Orchestrator: fetch → classify → build dashboard
Usage:
  python src/main.py                          # default: last 90 days
  python src/main.py --preset last_30_days   # Meta date preset
  python src/main.py --build-only             # Rebuild dashboard from existing data.json
"""

import sys
import os
import json
import logging
import argparse
from pathlib import Path
from datetime import datetime

# Load .env if present
try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).parent.parent / ".env")
except ImportError:
    pass

from fetch_meta import fetch_all, MetaAPIError, get_ig_username
from detect_influence import apply_classification
from build_dashboard import build as build_dashboard

# ── Logging ────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(Path(__file__).parent.parent / "data" / "last_run.log", mode="w"),
    ],
)
logger = logging.getLogger(__name__)

DATA_PATH = Path(__file__).parent.parent / "data" / "data.json"
DATA_PATH.parent.mkdir(parents=True, exist_ok=True)


def parse_args():
    p = argparse.ArgumentParser(description="Meta Influence Dashboard builder")
    p.add_argument("--preset", default="last_90d",
                   choices=["today","yesterday","last_3d","last_7d","last_14d",
                            "last_28d","last_30d","last_90d","this_month","last_month","maximum"],
                   help="Meta date preset for insights")
    p.add_argument("--build-only", action="store_true",
                   help="Skip API fetch, only rebuild dashboard from existing data.json")
    p.add_argument("--debug", action="store_true", help="Verbose debug logging")
    return p.parse_args()


def main():
    args = parse_args()
    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)

    logger.info("=" * 60)
    logger.info("Meta Influence Dashboard — starting run")
    logger.info(f"Date: {datetime.now().isoformat()}")
    logger.info("=" * 60)

    if args.build_only:
        logger.info("--build-only: skipping API fetch")
        if not DATA_PATH.exists():
            logger.error("No data.json found. Run without --build-only first.")
            sys.exit(1)
        with open(DATA_PATH) as f:
            records = json.load(f)
        output = build_dashboard(records)
        logger.info(f"Dashboard rebuilt → {output}")
        return

    token = os.environ.get("META_ACCESS_TOKEN", "").strip()
    if not token:
        logger.error("META_ACCESS_TOKEN not set. Add it to .env or export it.")
        sys.exit(1)

    # ── Step 1: Fetch from Meta API ────────────────────────
    logger.info("\n── Step 1/3: Fetching data from Meta API")
    try:
        records = fetch_all(token, date_preset=args.preset)
    except MetaAPIError as e:
        error_msg = str(e)
        logger.error(f"Meta API error: {error_msg}")

        # Write error marker for GitHub Actions issue creation
        error_path = DATA_PATH.parent / "last_error.json"
        with open(error_path, "w") as f:
            json.dump({"error": error_msg, "timestamp": datetime.now().isoformat()}, f)

        sys.exit(2)

    if not records:
        logger.warning("No records returned from Meta API.")
        sys.exit(0)

    # ── Step 2: Classify influence ─────────────────────────
    logger.info(f"\n── Step 2/3: Classifying {len(records)} ads")

    def enrich_username(ig_id: str) -> object:
        return get_ig_username(ig_id, token)

    records = apply_classification(records, enrich_usernames_fn=enrich_username)

    # Save data.json
    with open(DATA_PATH, "w") as f:
        json.dump(records, f, ensure_ascii=False, default=str, indent=2)
    logger.info(f"data.json saved ({DATA_PATH.stat().st_size // 1024}KB)")

    # ── Step 3: Build dashboard ────────────────────────────
    logger.info("\n── Step 3/3: Building dashboard")
    output = build_dashboard(records)

    # ── Summary ────────────────────────────────────────────
    influence = [r for r in records if r.get("is_influence")]
    creators = set(r.get("creator_handle") for r in influence if r.get("creator_handle"))

    logger.info("\n" + "=" * 60)
    logger.info("RUN COMPLETE")
    logger.info(f"  Total ads fetched    : {len(records)}")
    logger.info(f"  Influence detected   : {len(influence)} ({100*len(influence)//len(records) if records else 0}%)")
    logger.info(f"  Unique creators      : {len(creators)}")
    logger.info(f"  Dashboard            : {output}")
    logger.info("=" * 60)

    # Remove error marker on success
    error_path = DATA_PATH.parent / "last_error.json"
    if error_path.exists():
        error_path.unlink()


if __name__ == "__main__":
    main()
