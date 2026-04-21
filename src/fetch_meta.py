"""
fetch_meta.py — Meta Marketing API data fetcher
Handles: ad account discovery, insights (level=ad), creative details, targeting
"""

import os
import json
import time
import logging
import hashlib
from datetime import datetime, timedelta
from pathlib import Path
import requests

logger = logging.getLogger(__name__)

API_VERSION = "v19.0"
BASE_URL = f"https://graph.facebook.com/{API_VERSION}"
RAW_DIR = Path(__file__).parent.parent / "data" / "raw"
RAW_DIR.mkdir(parents=True, exist_ok=True)

INSIGHTS_FIELDS = [
    "ad_id", "ad_name", "adset_id", "adset_name", "campaign_id", "campaign_name",
    "impressions", "reach", "clicks", "spend", "ctr", "cpm", "cpp",
    "video_avg_time_watched_actions", "video_play_actions",
    "actions", "action_values", "purchase_roas",
    "date_start", "date_stop",
    "account_id", "account_name",
]

CREATIVE_FIELDS = [
    "id", "name",
    "source_instagram_media_id", "effective_instagram_media_id",
    "branded_content_sponsor_page_id", "instagram_permalink_url",
    "instagram_actor_id", "thumbnail_url",
]

ADSET_FIELDS = [
    "id", "name", "targeting", "start_time", "end_time",
    "status", "campaign_id",
]


class MetaAPIError(Exception):
    pass


class RateLimitError(MetaAPIError):
    pass


def _get(url: str, params: dict, token: str, retries: int = 3) -> dict:
    params = {**params, "access_token": token}
    for attempt in range(retries):
        try:
            r = requests.get(url, params=params, timeout=30)
            if r.status_code == 429 or (r.status_code == 400 and "User request limit reached" in r.text):
                wait = 60 * (attempt + 1)
                logger.warning(f"Rate limit hit, waiting {wait}s...")
                time.sleep(wait)
                continue
            if r.status_code == 500:
                logger.warning(f"500 Server Error (attempt {attempt+1}/{retries}), retrying...")
                time.sleep(5 * (attempt + 1))
                continue
            r.raise_for_status()
            data = r.json()
            if "error" in data:
                err = data["error"]
                code = err.get("code", 0)
                if code in (4, 17, 32, 613):
                    wait = 60 * (attempt + 1)
                    logger.warning(f"API throttle (code {code}), waiting {wait}s...")
                    time.sleep(wait)
                    continue
                raise MetaAPIError(f"API error {code}: {err.get('message', str(err))}")
            return data
        except requests.exceptions.Timeout:
            logger.warning(f"Timeout on attempt {attempt + 1}/{retries}")
            time.sleep(10)
    raise MetaAPIError(f"Failed after {retries} attempts: {url}")


def _paginate(url: str, params: dict, token: str) -> list:
    results = []
    data = _get(url, params, token)
    results.extend(data.get("data", []))
    while "paging" in data and "next" in data["paging"]:
        next_url = data["paging"]["next"]
        r = requests.get(next_url, timeout=30)
        r.raise_for_status()
        data = r.json()
        if "error" in data:
            raise MetaAPIError(f"Pagination error: {data['error']}")
        results.extend(data.get("data", []))
        logger.debug(f"Paginated, total so far: {len(results)}")
        time.sleep(0.3)
    return results


def _cache_path(key: str) -> Path:
    h = hashlib.md5(key.encode()).hexdigest()[:8]
    return RAW_DIR / f"cache_{h}.json"


def _load_cache(key: str, max_age_hours: int = 12) -> object:
    p = _cache_path(key)
    if not p.exists():
        return None
    stat = p.stat()
    age_hours = (time.time() - stat.st_mtime) / 3600
    if age_hours > max_age_hours:
        logger.debug(f"Cache expired ({age_hours:.1f}h old): {p.name}")
        return None
    with open(p) as f:
        logger.debug(f"Cache hit: {p.name}")
        return json.load(f)


def _save_cache(key: str, data: object) -> None:
    p = _cache_path(key)
    with open(p, "w") as f:
        json.dump(data, f, indent=2)


def get_ad_accounts(token: str) -> list:
    """Return all ad accounts accessible by this token."""
    cache_key = f"ad_accounts_{token[:20]}"
    cached = _load_cache(cache_key, max_age_hours=24)
    if cached:
        return cached

    logger.info("Fetching ad accounts...")
    data = _get(f"{BASE_URL}/me/adaccounts", {
        "fields": "id,name,account_id,account_status,currency,timezone_name",
        "limit": 50,
    }, token)
    accounts = data.get("data", [])
    logger.info(f"Found {len(accounts)} ad account(s)")
    for acc in accounts:
        logger.info(f"  → {acc.get('name', 'Unknown')} ({acc.get('id')})")
    _save_cache(cache_key, accounts)
    return accounts


def get_insights(account_id: str, token: str, date_preset: str = "last_90d") -> list:
    """Fetch ad-level insights for a given date preset."""
    cache_key = f"insights_{account_id}_{date_preset}"
    cached = _load_cache(cache_key, max_age_hours=4)
    if cached:
        logger.info(f"Using cached insights for {account_id} ({date_preset}): {len(cached)} ads")
        return cached

    logger.info(f"Fetching insights for account {account_id}, preset={date_preset}...")
    url = f"{BASE_URL}/{account_id}/insights"
    params = {
        "level": "ad",
        "fields": ",".join(INSIGHTS_FIELDS),
        "date_preset": date_preset,
        "limit": 500,
    }
    results = _paginate(url, params, token)
    logger.info(f"Fetched {len(results)} ad insights")
    _save_cache(cache_key, results)
    return results


def get_ads_list(account_id: str, token: str) -> list:
    """Fetch all ads with their creative IDs and adset IDs."""
    cache_key = f"ads_list_{account_id}"
    cached = _load_cache(cache_key, max_age_hours=6)
    if cached:
        return cached

    logger.info(f"Fetching ads list for {account_id}...")
    url = f"{BASE_URL}/{account_id}/ads"

    # Try with creative fields first, fall back to base fields on 500
    creative_subfields = ",".join(CREATIVE_FIELDS)
    for fields in [
        f"id,name,adset_id,campaign_id,status,created_time,creative{{{creative_subfields}}}",
        "id,name,adset_id,campaign_id,status,created_time,creative{id,name,instagram_permalink_url,thumbnail_url}",
        "id,name,adset_id,campaign_id,status,created_time",
    ]:
        try:
            results = _paginate(url, {"fields": fields, "limit": 500}, token)
            logger.info(f"Fetched {len(results)} ads (fields: {fields[:60]}...)")
            _save_cache(cache_key, results)
            return results
        except Exception as e:
            logger.warning(f"get_ads_list failed with fields ({fields[:60]}): {e} — trying fallback")

    logger.error(f"Could not fetch ads list for {account_id}, returning empty")
    return []


def get_adset(adset_id: str, token: str) -> dict:
    """Fetch a single adset with targeting details."""
    cache_key = f"adset_{adset_id}"
    cached = _load_cache(cache_key, max_age_hours=12)
    if cached:
        return cached

    try:
        data = _get(f"{BASE_URL}/{adset_id}", {
            "fields": ",".join(ADSET_FIELDS),
        }, token)
        _save_cache(cache_key, data)
        return data
    except MetaAPIError as e:
        logger.warning(f"Could not fetch adset {adset_id}: {e}")
        return {"id": adset_id, "error": str(e)}


def get_ig_username(ig_user_id: str, token: str) -> object:
    """Try to resolve an Instagram user ID to a username."""
    cache_key = f"iguser_{ig_user_id}"
    cached = _load_cache(cache_key, max_age_hours=48)
    if cached is not None:
        return cached.get("username")

    try:
        data = _get(f"{BASE_URL}/{ig_user_id}", {"fields": "username,name"}, token)
        username = data.get("username") or data.get("name")
        _save_cache(cache_key, {"username": username})
        return username
    except MetaAPIError:
        _save_cache(cache_key, {"username": None})
        return None


def get_brand_ig_accounts(account_id: str, token: str) -> set:
    """Get the brand's own Instagram account IDs to distinguish from creator accounts."""
    cache_key = f"brand_ig_{account_id}"
    cached = _load_cache(cache_key, max_age_hours=24)
    if cached:
        return set(cached)

    brand_ig_ids = set()
    try:
        # Try via owned pages (more reliable than ad account direct)
        pages_data = _get(f"{BASE_URL}/me/accounts", {"fields": "id,name,instagram_accounts", "limit": 50}, token)
        for page in pages_data.get("data", []):
            ig_accts = page.get("instagram_accounts") or {}
            for ig in ig_accts.get("data", []):
                brand_ig_ids.add(ig.get("id", ""))
        if brand_ig_ids:
            logger.info(f"Found brand IG accounts: {brand_ig_ids}")
    except Exception as e:
        logger.warning(f"Could not fetch brand IG accounts (non-fatal): {e}")

    _save_cache(cache_key, list(brand_ig_ids))
    return brand_ig_ids


def _parse_action_value(actions: list, action_type: str) -> float:
    for a in (actions or []):
        if a.get("action_type") == action_type:
            return float(a.get("value", 0))
    return 0.0


def _parse_roas(purchase_roas, action_values, spend: float) -> float:
    if purchase_roas:
        for r in purchase_roas:
            if r.get("action_type") == "omni_purchase":
                return float(r.get("value", 0))
            if r.get("action_type") == "purchase":
                return float(r.get("value", 0))
    if action_values and spend > 0:
        revenue = _parse_action_value(action_values, "omni_purchase")
        if revenue == 0:
            revenue = _parse_action_value(action_values, "purchase")
        if revenue > 0:
            return revenue / spend
    return 0.0


def _parse_video_watch(video_avg) -> float:
    for item in (video_avg or []):
        if item.get("action_type") in ("video_avg_time_watched_actions", "video_view"):
            return float(item.get("value", 0))
    return 0.0


def merge_data(insights: list, ads: list, token: str) -> list:
    """Merge insights with creative + adset data into one record per ad."""
    ads_by_id = {a["id"]: a for a in ads}
    adset_cache: dict = {}
    merged = []

    for row in insights:
        ad_id = row.get("ad_id") or row.get("id", "")
        ad_info = ads_by_id.get(ad_id, {})
        creative = ad_info.get("creative", {})
        adset_id = row.get("adset_id") or ad_info.get("adset_id", "")

        # Fetch adset once
        if adset_id and adset_id not in adset_cache:
            logger.debug(f"Fetching adset {adset_id}")
            adset_cache[adset_id] = get_adset(adset_id, token)
            time.sleep(0.1)
        adset = adset_cache.get(adset_id, {})

        spend = float(row.get("spend", 0) or 0)
        actions = row.get("actions", []) or []
        action_values = row.get("action_values", []) or []
        purchases = _parse_action_value(actions, "omni_purchase") or _parse_action_value(actions, "purchase")
        revenue = _parse_action_value(action_values, "omni_purchase") or _parse_action_value(action_values, "purchase")
        roas = _parse_roas(row.get("purchase_roas"), action_values, spend)

        record = {
            "ad_id": ad_id,
            "ad_name": row.get("ad_name", ad_info.get("name", "")),
            "adset_id": adset_id,
            "adset_name": row.get("adset_name", adset.get("name", "")),
            "campaign_id": row.get("campaign_id", ad_info.get("campaign_id", "")),
            "campaign_name": row.get("campaign_name", ""),
            "status": ad_info.get("status", "UNKNOWN"),
            "date_start": row.get("date_start", ""),
            "date_stop": row.get("date_stop", ""),
            "adset_start": adset.get("start_time", ""),
            "adset_end": adset.get("end_time", ""),
            "impressions": int(row.get("impressions", 0) or 0),
            "reach": int(row.get("reach", 0) or 0),
            "clicks": int(row.get("clicks", 0) or 0),
            "spend": spend,
            "ctr": float(row.get("ctr", 0) or 0),
            "cpm": float(row.get("cpm", 0) or 0),
            "purchases": purchases,
            "revenue": revenue,
            "roas": roas,
            "video_avg_watch": _parse_video_watch(row.get("video_avg_time_watched_actions")),
            "creative_id": creative.get("id", ""),
            "creative_name": creative.get("name", ""),
            "thumbnail_url": creative.get("thumbnail_url") or creative.get("image_url", ""),
            "instagram_permalink": creative.get("instagram_permalink_url", ""),
            "instagram_actor_id": creative.get("instagram_actor_id", ""),
            "source_instagram_media_id": creative.get("source_instagram_media_id", ""),
            "effective_instagram_media_id": creative.get("effective_instagram_media_id", ""),
            "branded_content_sponsor_page_id": creative.get("branded_content_sponsor_page_id", ""),
            "object_story_spec": creative.get("object_story_spec", {}),
            "targeting": adset.get("targeting", {}),
            "account_id": row.get("account_id", ""),
        }
        merged.append(record)

    logger.info(f"Merged {len(merged)} records")
    return merged


def fetch_all(token: str, date_preset: str = "last_90d") -> list:
    """Main entry: auto-discover accounts and fetch everything."""
    accounts = get_ad_accounts(token)
    if not accounts:
        raise MetaAPIError("No ad accounts found for this token")

    all_records = []
    for account in accounts:
        account_id = account["id"]
        logger.info(f"\n=== Processing account: {account.get('name')} ({account_id}) ===")

        try:
            insights = get_insights(account_id, token, date_preset)
            if not insights:
                logger.info("No insights found for this account/period")
                continue

            ads = get_ads_list(account_id, token)
            brand_ig_ids = get_brand_ig_accounts(account_id, token)
            logger.info(f"Brand IG IDs: {brand_ig_ids or '(none detected)'}")

            merged = merge_data(insights, ads, token)
            # Attach brand IG IDs for scoring
            for rec in merged:
                rec["_brand_ig_ids"] = list(brand_ig_ids)

            all_records.extend(merged)
        except MetaAPIError as e:
            logger.error(f"Error processing account {account_id}: {e}")
            continue

    logger.info(f"\nTotal records fetched: {len(all_records)}")
    return all_records
