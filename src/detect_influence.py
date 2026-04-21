"""
detect_influence.py — Influence content scoring & classification
Score 0–100 per ad based on multiple signals. Threshold ≥ 30 → is_influence: true
"""

import re
import json
import logging
import unicodedata
from pathlib import Path

logger = logging.getLogger(__name__)

OVERRIDES_PATH = Path(__file__).parent.parent / "overrides.json"

INFLUENCE_KEYWORDS = [
    "influ", "influence", "influencer", "influenceuse",
    "creator", "créateur", "creatrice", "créatrice",
    "ugc", "collab", "collaboration",
    "partner", "partnership", "partenariat",
    "ambassador", "ambassadeur", "ambassadrice",
    "whitelist", "whitelisting",
    "dark post", "darkpost",
    "branded", "branded content",
    "spark", "spark ad",
    "sponsored", "sponsorisé",
    "feat", "ft.",
    "avec @", "with @", "x @",
]

HANDLE_PATTERN = re.compile(r"@[\w.]+")
FORMAT_KEYWORDS = ["reel creator", "story collab", "ugc post", "creator reel", "creator story"]


def _normalize(text: str) -> str:
    if not text:
        return ""
    text = unicodedata.normalize("NFD", text.lower())
    return "".join(c for c in text if unicodedata.category(c) != "Mn")


def _load_overrides() -> dict:
    if OVERRIDES_PATH.exists():
        with open(OVERRIDES_PATH) as f:
            data = json.load(f)
            return data.get("overrides", {})
    return {}


def score_ad(record: dict) -> dict:
    """
    Compute influence_score (0–100) and matched_signals list for one ad record.
    Returns a dict with: influence_score, is_influence, signals, creator_handle, creator_ig_id
    """
    score = 0
    signals = []
    creator_handle = None
    creator_ig_id = None

    brand_ig_ids = set(record.get("_brand_ig_ids", []))

    # ── Signal 1: Partnership Ads / Branded Content (+50) ──────────────────
    if record.get("branded_content_sponsor_page_id"):
        score += 50
        signals.append("Partnership Ad (branded_content_sponsor_page_id)")
        logger.debug(f"  [+50] branded_content_sponsor_page_id present")

    source_ig_media = record.get("source_instagram_media_id")
    effective_ig_media = record.get("effective_instagram_media_id")
    if source_ig_media and not record.get("branded_content_sponsor_page_id"):
        score += 40
        signals.append(f"Source IG media (whitelisting/dark post): {source_ig_media}")
        logger.debug(f"  [+40] source_instagram_media_id: {source_ig_media}")
    elif effective_ig_media and effective_ig_media != source_ig_media and not record.get("branded_content_sponsor_page_id"):
        score += 30
        signals.append(f"Effective IG media (boosted organic): {effective_ig_media}")
        logger.debug(f"  [+30] effective_instagram_media_id: {effective_ig_media}")

    # Check object_story_spec for instagram_actor_id ≠ brand page
    object_story = record.get("object_story_spec") or {}
    ig_actor_in_story = None
    if isinstance(object_story, dict):
        ig_actor_in_story = (
            object_story.get("instagram_actor_id")
            or (object_story.get("link_data") or {}).get("instagram_actor_id")
            or (object_story.get("video_data") or {}).get("instagram_actor_id")
        )
    direct_actor = record.get("instagram_actor_id")
    actor_id = ig_actor_in_story or direct_actor

    if actor_id and brand_ig_ids and actor_id not in brand_ig_ids:
        if not record.get("branded_content_sponsor_page_id") and not source_ig_media:
            score += 35
        signals.append(f"IG actor is 3rd party: {actor_id}")
        creator_ig_id = actor_id
        logger.debug(f"  [+35] instagram_actor_id {actor_id} ≠ brand")
    elif actor_id:
        creator_ig_id = actor_id

    # ── Signal 2: Instagram permalink pointing to creator account (+30) ────
    permalink = record.get("instagram_permalink", "")
    if permalink:
        # Only extract username from profile-style URLs, not post/reel shortcodes
        # Profile: instagram.com/username/ — Post: instagram.com/p/SHORTCODE/ or /reel/SHORTCODE/
        profile_match = re.search(r"instagram\.com/([\w.]+)/?$", permalink)
        is_post_url = bool(re.search(r"instagram\.com/(p|reel|tv|stories)/", permalink))
        if profile_match and not is_post_url:
            ig_handle = profile_match.group(1)
            if ig_handle not in ("p", "reel", "tv", "stories", "explore", "accounts"):
                creator_handle = f"@{ig_handle}"
                if score < 30:
                    score += 20
                    signals.append(f"IG permalink to creator: {creator_handle}")
                    logger.debug(f"  [+20] IG permalink creator: {creator_handle}")
                else:
                    signals.append(f"IG permalink: {creator_handle}")
        elif is_post_url:
            # Still a signal (organic post being boosted) but no extractable username
            signals.append(f"IG boosted post (permalink)")

    # ── Signal 3a: "Influence" dans le nom d'adset/campagne — convention de nommage (+40) ──
    # Si "influence" apparaît dans le NOM D'ADSET ou CAMPAGNE, c'est intentionnel → signal fort.
    STRONG_WORDS = ["influence", "influencer", "influenceuse", "influenceur"]
    adset_name_norm = _normalize(record.get("adset_name", ""))
    campaign_name_norm = _normalize(record.get("campaign_name", ""))
    strong_hit = None
    for w in STRONG_WORDS:
        if w in adset_name_norm:
            strong_hit = f"'{w}' dans adset: {record.get('adset_name','')}"
            break
        if w in campaign_name_norm:
            strong_hit = f"'{w}' dans campagne: {record.get('campaign_name','')}"
            break
    if strong_hit:
        score += 40
        signals.append(f"Convention de nommage influence (+40): {strong_hit}")
        logger.debug(f"  [+40] {strong_hit}")

    # ── Signal 3b: Keywords dans tous les noms (+20 max) ──────────────────
    names_to_check = [
        record.get("ad_name", ""),
        record.get("adset_name", ""),
        record.get("campaign_name", ""),
        record.get("creative_name", ""),
    ]
    combined_name = " ".join(n for n in names_to_check if n)
    normalized = _normalize(combined_name)

    keyword_hits = []
    for kw in INFLUENCE_KEYWORDS:
        if strong_hit and _normalize(kw) in adset_name_norm:
            continue  # already counted above
        if _normalize(kw) in normalized:
            keyword_hits.append(kw)

    handles_in_name = HANDLE_PATTERN.findall(combined_name)
    if handles_in_name:
        keyword_hits.append(f"handle(s): {', '.join(handles_in_name)}")
        if not creator_handle:
            creator_handle = handles_in_name[0]

    if keyword_hits:
        kw_score = min(20, 5 * len(keyword_hits))
        score += kw_score
        signals.append(f"Keywords (+{kw_score}): {', '.join(keyword_hits[:5])}")
        logger.debug(f"  [+{kw_score}] keywords: {keyword_hits[:5]}")

    # ── Signal 3c: Nom de créateur en fin de nom d'ad ou d'adset ──────────
    # Ex: US_Picta_Web_TOFU_Influence_juliagrace → @juliagrace
    #     260401_influence_video_amymarch → @amymarch
    KNOWN_TAGS = {"tofu", "mofu", "bofu", "broad", "retargeting", "prospecting",
                  "static", "video", "gif", "reel", "story", "web", "app",
                  "android", "ios", "fr", "us", "uk", "de", "eu", "cvs",
                  "influence", "influencer", "influenceuse", "influenceur",
                  "ugc", "collab", "partner", "prints", "woodprint", "woodwall",
                  "boostresolution", "hook", "screenshot", "notegoogleplay"}

    def _extract_creator(name):
        parts = name.replace("-", "_").split("_")
        for part in reversed(parts):
            p = part.lower().strip()
            if len(p) >= 3 and p.isalpha() and p not in KNOWN_TAGS:
                return p
        return None

    if not creator_handle:
        for field in ["ad_name", "adset_name"]:
            found = _extract_creator(record.get(field, ""))
            if found:
                creator_handle = f"@{found}"
                signals.append(f"Creator name in {field}: {found}")
                logger.debug(f"  Creator from {field}: {found}")
                break

    # ── Signal 4: Creator format patterns (+10) ─────────────────────────────
    format_hits = [f for f in FORMAT_KEYWORDS if f in normalized]
    if format_hits:
        score += 10
        signals.append(f"Creator format: {', '.join(format_hits)}")
        logger.debug(f"  [+10] format keywords: {format_hits}")
    elif handles_in_name:
        score += 10
        signals.append(f"@handle in ad name")
        logger.debug(f"  [+10] @handle in name")

    score = min(100, score)
    is_influence = score >= 30

    return {
        "influence_score": score,
        "is_influence": is_influence,
        "signals": signals,
        "creator_handle": creator_handle,
        "creator_ig_id": creator_ig_id,
        "confidence_label": _confidence_label(score),
    }


def _confidence_label(score: int) -> str:
    if score >= 70:
        return "Haute"
    if score >= 40:
        return "Moyenne"
    if score >= 30:
        return "Faible"
    return "Non-influence"


def apply_classification(records: list, enrich_usernames_fn=None) -> list:
    """
    Score all records, apply manual overrides, optionally resolve IG usernames.
    enrich_usernames_fn: optional callable(ig_user_id) -> username
    """
    overrides = _load_overrides()
    classified = []

    influence_count = 0
    for rec in records:
        ad_id = rec.get("ad_id", "")
        result = score_ad(rec)

        # Apply manual override
        if ad_id in overrides:
            original = result["is_influence"]
            result["is_influence"] = overrides[ad_id]
            result["signals"].append(f"[OVERRIDE] Manual: {'influence' if overrides[ad_id] else 'non-influence'} (was: {original})")
            logger.info(f"Override applied for ad {ad_id}: {overrides[ad_id]}")

        # Try to resolve creator username if we have an IG ID
        if result["creator_ig_id"] and not result["creator_handle"] and enrich_usernames_fn:
            username = enrich_usernames_fn(result["creator_ig_id"])
            if username:
                result["creator_handle"] = f"@{username}"

        rec.update(result)
        rec.pop("_brand_ig_ids", None)  # Don't expose internal field

        if result["is_influence"]:
            influence_count += 1
            logger.info(
                f"[INFLUENCE score={result['influence_score']:3d}] {rec.get('ad_name', ad_id)[:60]}"
                f" | creator={result['creator_handle'] or 'unknown'}"
                f" | signals: {'; '.join(result['signals'])}"
            )
        else:
            logger.debug(
                f"[non-influence score={result['influence_score']:3d}] {rec.get('ad_name', ad_id)[:60]}"
            )

        classified.append(rec)

    total = len(classified)
    logger.info(f"\n=== Classification summary ===")
    logger.info(f"Total ads: {total}")
    logger.info(f"Influence: {influence_count} ({100*influence_count//total if total else 0}%)")
    logger.info(f"Non-influence: {total - influence_count}")

    return classified


def get_top_creators(records: list, n: int = 10) -> list:
    """Aggregate top N creators by ROAS from classified influence records."""
    creators: dict = {}
    for rec in records:
        if not rec.get("is_influence"):
            continue
        handle = rec.get("creator_handle") or rec.get("creator_ig_id") or "Unknown"
        if handle not in creators:
            creators[handle] = {"handle": handle, "spend": 0, "revenue": 0, "reach": 0, "ads": 0}
        creators[handle]["spend"] += rec.get("spend", 0)
        creators[handle]["revenue"] += rec.get("revenue", 0)
        creators[handle]["reach"] += rec.get("reach", 0)
        creators[handle]["ads"] += 1

    for c in creators.values():
        c["roas"] = round(c["revenue"] / c["spend"], 2) if c["spend"] > 0 else 0

    ranked = sorted(creators.values(), key=lambda x: x["roas"], reverse=True)
    return ranked[:n]
