# Influence Paid Dashboard

Dashboard d'analyse des performances de contenus d'influence boostés en paid sur Meta (Facebook/Instagram). Données récupérées via la Marketing API, détection automatique des contenus influence par scoring, hébergé sur GitHub Pages.

## Features

- **Détection automatique** des contenus influence via un système de score (Partnership Ads, whitelisting, keywords, handles)
- **KPIs agrégés** : ROAS, spend, revenus, impressions, reach, CTR, créateurs uniques
- **Tableau tri-colonne** avec recherche live et filtres multiples
- **Top créateurs** par ROAS
- **Graphique** spend vs revenus par jour
- **Export CSV** du tableau filtré
- **Refresh quotidien** via GitHub Actions à 6h UTC

---

## Setup local

### 1. Prérequis

```bash
python3 --version   # Python 3.9+
```

### 2. Cloner et installer

```bash
git clone https://github.com/TON_USERNAME/meta-influence-dashboard.git
cd meta-influence-dashboard
pip install -r requirements.txt
```

### 3. Configurer le token Meta

```bash
cp .env.example .env
# Édite .env et ajoute ton META_ACCESS_TOKEN
```

Génère ton token dans **Business Manager → Paramètres d'entreprise → Utilisateurs système** avec les permissions `ads_read` et `pages_read_engagement`.

### 4. Lancer le pipeline

```bash
python src/main.py
# ou pour une autre période :
python src/main.py --preset last_30d
# ou juste rebuild le dashboard sans refaire les appels API :
python src/main.py --build-only
```

Le dashboard est généré dans `docs/index.html`. Ouvre-le directement dans ton navigateur.

---

## Comment ça marche

### Architecture

```
Meta API → fetch_meta.py → data/data.json
                                ↓
                    detect_influence.py (scoring)
                                ↓
                    build_dashboard.py → docs/index.html
```

### Système de scoring (0–100)

Chaque ad reçoit un `influence_score` basé sur ces signaux :

| Signal | Points | Critère |
|--------|--------|---------|
| Partnership Ad | +50 | `branded_content_sponsor_page_id` présent |
| Whitelisting / Dark Post | +40 | `source_instagram_media_id` présent |
| Organic post boosté | +30 | `effective_instagram_media_id` ≠ source |
| Compte IG tiers | +35 | `instagram_actor_id` ≠ comptes de la marque |
| Permalink créateur | +20 | URL pointe vers un compte IG externe |
| Keywords dans le nom | +20 max | `influencer`, `ugc`, `collab`, `@handle`… |
| Format créateur | +10 | `reel creator`, `ugc post`, handle `@xxx` |

**Seuil** : score ≥ 30 → `is_influence: true`

### Overrides manuels

Si une classification est incorrecte, édite `overrides.json` :

```json
{
  "overrides": {
    "123456789": true,
    "987654321": false
  }
}
```

Les overrides sont pris en compte au prochain `python src/main.py --build-only`.

---

## GitHub Actions

Le workflow `.github/workflows/refresh.yml` tourne chaque jour à 6h UTC :

1. Checkout du repo
2. `python src/main.py` (avec `META_ACCESS_TOKEN` depuis les secrets)
3. Commit et push de `data/data.json` + `docs/index.html` si changements
4. En cas d'erreur API → création automatique d'une GitHub Issue

### Déclencher manuellement

```bash
gh workflow run refresh.yml
gh run watch
```

---

## Variables d'environnement

| Variable | Description |
|----------|-------------|
| `META_ACCESS_TOKEN` | Token Meta Marketing API (ads_read + pages_read_engagement) |

---

## FAQ

**Le token expire — que faire ?**
Meta tokens système expirent rarement. Si le workflow échoue avec une erreur auth, génère un nouveau token dans Business Manager et mets à jour le secret GitHub : `gh secret set META_ACCESS_TOKEN`.

**Certains ads influence ne sont pas détectés ?**
Ajoute-les manuellement dans `overrides.json` avec `"ad_id": true`. Pour améliorer la détection globale, vérifie que le nom de tes adsets/campagnes contient des mots-clés comme `influencer`, `collab`, `@handle`, etc.

**Les créateurs s'affichent comme "unknown" ?**
Pour les posts organiques boostés (`effective_instagram_media_id`), le username n'est pas toujours récupérable via l'API sans permissions supplémentaires. Le média ID est tracé pour référence.

**Les données ne se rafraîchissent plus ?**
Vérifie que le secret `META_ACCESS_TOKEN` est valide dans Settings → Secrets. Consulte la dernière GitHub Issue créée automatiquement pour le détail de l'erreur.
