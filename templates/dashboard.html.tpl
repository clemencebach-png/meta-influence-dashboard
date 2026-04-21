<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Influence Paid Dashboard</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,300;0,9..144,600;1,9..144,300;1,9..144,600&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<style>
/* ─── Reset ─────────────────────────────────────────────── */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

/* ─── Design tokens ──────────────────────────────────────── */
:root {
  --cream: #F5F0E8;
  --ivory: #FAF7F2;
  --paper: #EFEBE1;
  --ink: #1A1714;
  --ink-muted: #5A5248;
  --ink-faint: #9B9189;
  --red: #C0392B;
  --red-light: #E8D5D3;
  --gold: #A8893A;
  --gold-light: #F0E8CC;
  --border: #D8D0C4;
  --shadow: 0 1px 3px rgba(26,23,20,.08), 0 4px 12px rgba(26,23,20,.04);
  --shadow-lg: 0 2px 8px rgba(26,23,20,.10), 0 12px 32px rgba(26,23,20,.06);
  --font-display: 'Fraunces', Georgia, serif;
  --font-mono: 'JetBrains Mono', 'Courier New', monospace;
  --r: 6px;
}

body {
  background: var(--cream);
  color: var(--ink);
  font-family: var(--font-mono);
  font-size: 13px;
  line-height: 1.6;
  min-height: 100vh;
}

/* ─── Noise overlay ──────────────────────────────────────── */
body::before {
  content: '';
  position: fixed;
  inset: 0;
  pointer-events: none;
  z-index: 9999;
  opacity: .025;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='300' height='300'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.65' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='300' height='300' filter='url(%23n)' opacity='1'/%3E%3C/svg%3E");
}

/* ─── Layout ─────────────────────────────────────────────── */
.page { max-width: 1400px; margin: 0 auto; padding: 40px 24px 80px; }

header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  padding-bottom: 32px;
  border-bottom: 1px solid var(--border);
  margin-bottom: 36px;
  flex-wrap: wrap;
  gap: 16px;
}

.header-left h1 {
  font-family: var(--font-display);
  font-size: 32px;
  font-weight: 600;
  letter-spacing: -0.5px;
  color: var(--ink);
}

.header-left h1 em {
  font-style: italic;
  color: var(--red);
}

.header-meta {
  font-size: 11px;
  color: var(--ink-muted);
  margin-top: 4px;
}

.header-actions { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }

/* ─── Buttons ─────────────────────────────────────────────── */
.btn {
  font-family: var(--font-mono);
  font-size: 11px;
  font-weight: 600;
  padding: 7px 14px;
  border-radius: var(--r);
  border: 1px solid var(--border);
  background: var(--ivory);
  color: var(--ink);
  cursor: pointer;
  letter-spacing: .05em;
  text-transform: uppercase;
  transition: all .15s;
}
.btn:hover { background: var(--paper); border-color: var(--ink-faint); }
.btn-primary { background: var(--red); color: white; border-color: var(--red); }
.btn-primary:hover { background: #a93226; border-color: #a93226; }

/* ─── Filters bar ─────────────────────────────────────────── */
.filters {
  background: var(--ivory);
  border: 1px solid var(--border);
  border-radius: var(--r);
  padding: 16px 20px;
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  align-items: center;
  margin-bottom: 32px;
  box-shadow: var(--shadow);
}

.filter-group { display: flex; flex-direction: column; gap: 4px; }
.filter-label { font-size: 10px; color: var(--ink-faint); text-transform: uppercase; letter-spacing: .08em; }

select, input[type="text"], input[type="number"] {
  font-family: var(--font-mono);
  font-size: 12px;
  background: var(--cream);
  border: 1px solid var(--border);
  border-radius: 4px;
  padding: 6px 10px;
  color: var(--ink);
  outline: none;
  transition: border-color .15s;
}
select:focus, input:focus { border-color: var(--red); }

.filter-sep { width: 1px; height: 32px; background: var(--border); margin: 0 4px; }

/* ─── KPIs grid ───────────────────────────────────────────── */
.kpis {
  display: grid;
  grid-template-columns: 2fr 1fr 1fr 1fr 1fr 1fr;
  gap: 16px;
  margin-bottom: 32px;
}

@media (max-width: 900px) {
  .kpis { grid-template-columns: repeat(3, 1fr); }
  .kpi-hero { grid-column: span 3; }
}

.kpi {
  background: var(--ivory);
  border: 1px solid var(--border);
  border-radius: var(--r);
  padding: 20px 22px;
  box-shadow: var(--shadow);
  animation: fadeUp .4s ease both;
}

.kpi-hero {
  background: var(--ink);
  color: var(--cream);
  border-color: var(--ink);
}

.kpi-label {
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: .1em;
  color: var(--ink-faint);
  margin-bottom: 8px;
}
.kpi-hero .kpi-label { color: rgba(245,240,232,.5); }

.kpi-value {
  font-family: var(--font-mono);
  font-size: 28px;
  font-weight: 600;
  line-height: 1;
  letter-spacing: -1px;
}
.kpi-hero .kpi-value { font-size: 52px; color: var(--cream); }
.kpi-hero .kpi-value span.unit { font-size: 28px; color: rgba(245,240,232,.6); }

.kpi-sub {
  font-size: 11px;
  color: var(--ink-faint);
  margin-top: 4px;
}
.kpi-hero .kpi-sub { color: rgba(245,240,232,.45); }

/* Staggered animation */
.kpi:nth-child(1) { animation-delay: 0s; }
.kpi:nth-child(2) { animation-delay: .05s; }
.kpi:nth-child(3) { animation-delay: .10s; }
.kpi:nth-child(4) { animation-delay: .15s; }
.kpi:nth-child(5) { animation-delay: .20s; }
.kpi:nth-child(6) { animation-delay: .25s; }

/* ─── Two-column section ──────────────────────────────────── */
.row2 {
  display: grid;
  grid-template-columns: 1fr 340px;
  gap: 20px;
  margin-bottom: 32px;
}
@media (max-width: 900px) { .row2 { grid-template-columns: 1fr; } }

/* ─── Cards ───────────────────────────────────────────────── */
.card {
  background: var(--ivory);
  border: 1px solid var(--border);
  border-radius: var(--r);
  box-shadow: var(--shadow);
  overflow: hidden;
  animation: fadeUp .5s ease .3s both;
}

.card-header {
  padding: 16px 20px 12px;
  border-bottom: 1px solid var(--border);
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.card-title {
  font-family: var(--font-display);
  font-size: 16px;
  font-weight: 600;
}

.card-body { padding: 16px 20px; }

/* ─── Chart ───────────────────────────────────────────────── */
.chart-wrap { position: relative; height: 220px; }

/* ─── Top creators ────────────────────────────────────────── */
.creator-list { display: flex; flex-direction: column; gap: 0; }
.creator-row {
  display: grid;
  grid-template-columns: 24px 1fr auto;
  gap: 10px;
  align-items: center;
  padding: 10px 0;
  border-bottom: 1px solid var(--border);
}
.creator-row:last-child { border-bottom: none; }
.creator-rank {
  font-family: var(--font-mono);
  font-size: 11px;
  color: var(--ink-faint);
  font-weight: 600;
}
.creator-name {
  font-family: var(--font-mono);
  font-size: 12px;
  font-weight: 600;
  color: var(--ink);
}
.creator-meta {
  font-size: 11px;
  color: var(--ink-faint);
}
.creator-roas {
  font-family: var(--font-mono);
  font-size: 14px;
  font-weight: 600;
  color: var(--red);
  text-align: right;
}
.creator-roas-label { font-size: 10px; color: var(--ink-faint); }

/* ─── Table wrapper ───────────────────────────────────────── */
.table-wrap {
  background: var(--ivory);
  border: 1px solid var(--border);
  border-radius: var(--r);
  box-shadow: var(--shadow);
  overflow: hidden;
  animation: fadeUp .5s ease .4s both;
}

.table-header {
  padding: 16px 20px;
  border-bottom: 1px solid var(--border);
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 10px;
}

.table-title {
  font-family: var(--font-display);
  font-size: 18px;
  font-weight: 600;
}

.table-count {
  font-size: 11px;
  color: var(--ink-faint);
  background: var(--paper);
  padding: 3px 8px;
  border-radius: 20px;
  border: 1px solid var(--border);
}

.table-scroll { overflow-x: auto; }

table {
  width: 100%;
  border-collapse: collapse;
  font-size: 12px;
}

thead tr {
  background: var(--paper);
  border-bottom: 2px solid var(--border);
}

th {
  padding: 10px 14px;
  text-align: left;
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: .08em;
  color: var(--ink-muted);
  white-space: nowrap;
  cursor: pointer;
  user-select: none;
  font-weight: 600;
}
th:hover { color: var(--ink); }
th.sorted-asc::after { content: ' ↑'; color: var(--red); }
th.sorted-desc::after { content: ' ↓'; color: var(--red); }

td {
  padding: 10px 14px;
  border-bottom: 1px solid var(--border);
  vertical-align: middle;
}
tr:last-child td { border-bottom: none; }
tr:hover td { background: var(--paper); }

.td-name {
  max-width: 240px;
}
.td-name-text {
  font-weight: 600;
  color: var(--ink);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  display: block;
}
.td-name-sub {
  font-size: 11px;
  color: var(--ink-faint);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  display: block;
}

.td-num { font-family: var(--font-mono); text-align: right; }
.td-roas { font-family: var(--font-mono); font-weight: 600; text-align: right; }
.roas-high { color: var(--red); }
.roas-med { color: var(--gold); }
.roas-low { color: var(--ink-muted); }

.badge {
  display: inline-block;
  padding: 2px 7px;
  border-radius: 20px;
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: .05em;
}
.badge-influence { background: var(--red-light); color: var(--red); }
.badge-non { background: var(--paper); color: var(--ink-faint); border: 1px solid var(--border); }
.badge-status-active { background: #d4edda; color: #155724; }
.badge-status-other { background: var(--paper); color: var(--ink-faint); }

.td-thumb { width: 40px; }
.thumb-img {
  width: 36px;
  height: 36px;
  object-fit: cover;
  border-radius: 4px;
  border: 1px solid var(--border);
}
.thumb-placeholder {
  width: 36px;
  height: 36px;
  background: var(--paper);
  border-radius: 4px;
  border: 1px solid var(--border);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
}

.td-confidence { max-width: 200px; }
.confidence-score {
  font-family: var(--font-mono);
  font-size: 11px;
  font-weight: 600;
  display: inline-block;
  padding: 1px 6px;
  border-radius: 4px;
}
.conf-high { background: var(--red-light); color: var(--red); }
.conf-med { background: var(--gold-light); color: var(--gold); }
.conf-low { background: var(--paper); color: var(--ink-faint); border: 1px solid var(--border); }
.conf-none { background: var(--paper); color: var(--ink-faint); border: 1px solid var(--border); }

.signals-text {
  font-size: 10px;
  color: var(--ink-faint);
  margin-top: 2px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 200px;
}

.td-creator { font-family: var(--font-mono); font-size: 12px; font-weight: 600; color: var(--red); }

.td-targeting { max-width: 180px; font-size: 11px; color: var(--ink-muted); }

.permalink-link { color: var(--red); text-decoration: none; font-size: 10px; }
.permalink-link:hover { text-decoration: underline; }

.no-results {
  padding: 60px 20px;
  text-align: center;
  color: var(--ink-faint);
}
.no-results em {
  font-family: var(--font-display);
  font-size: 18px;
  font-style: italic;
  display: block;
  margin-bottom: 8px;
}

/* ─── Footer ──────────────────────────────────────────────── */
footer {
  margin-top: 60px;
  padding-top: 24px;
  border-top: 1px solid var(--border);
  display: flex;
  justify-content: space-between;
  align-items: center;
  color: var(--ink-faint);
  font-size: 11px;
  flex-wrap: wrap;
  gap: 8px;
}

/* ─── Animations ──────────────────────────────────────────── */
@keyframes fadeUp {
  from { opacity: 0; transform: translateY(16px); }
  to   { opacity: 1; transform: translateY(0); }
}
</style>
</head>
<body>
<div class="page">

  <header>
    <div class="header-left">
      <h1>Influence <em>Paid</em> Dashboard</h1>
      <div class="header-meta">
        Données Meta Marketing API · Dernière mise à jour : <strong id="last-updated">__LAST_UPDATED__</strong>
      </div>
    </div>
    <div class="header-actions">
      <div class="filter-group">
        <span class="filter-label">Période</span>
        <select id="filter-preset" onchange="applyFilters()">
          <option value="all">Toutes les données</option>
          <option value="7">7 derniers jours</option>
          <option value="30" selected>30 derniers jours</option>
          <option value="90">90 derniers jours</option>
        </select>
      </div>
      <button class="btn btn-primary" onclick="exportCSV()">↓ Export CSV</button>
    </div>
  </header>

  <!-- Filters -->
  <div class="filters">
    <div class="filter-group">
      <span class="filter-label">Type</span>
      <select id="filter-type" onchange="applyFilters()">
        <option value="influence">Influence seulement</option>
        <option value="all">Tous les ads</option>
        <option value="non">Non-influence</option>
      </select>
    </div>
    <div class="filter-sep"></div>
    <div class="filter-group">
      <span class="filter-label">ROAS min</span>
      <input type="number" id="filter-roas" placeholder="0" step="0.1" min="0" oninput="applyFilters()" style="width:80px">
    </div>
    <div class="filter-sep"></div>
    <div class="filter-group">
      <span class="filter-label">Statut</span>
      <select id="filter-status" onchange="applyFilters()">
        <option value="all">Tous</option>
        <option value="ACTIVE">Actif</option>
        <option value="PAUSED">Pausé</option>
      </select>
    </div>
    <div class="filter-sep"></div>
    <div class="filter-group">
      <span class="filter-label">Créateur</span>
      <select id="filter-creator" onchange="applyFilters()">
        <option value="all">Tous</option>
      </select>
    </div>
    <div class="filter-sep"></div>
    <div class="filter-group">
      <span class="filter-label">Recherche</span>
      <input type="text" id="filter-search" placeholder="Nom, campagne…" oninput="applyFilters()" style="width:180px">
    </div>
  </div>

  <!-- KPIs -->
  <div class="kpis" id="kpis-grid">
    <div class="kpi kpi-hero">
      <div class="kpi-label">ROAS moyen</div>
      <div class="kpi-value" id="kpi-roas">—<span class="unit">x</span></div>
      <div class="kpi-sub" id="kpi-roas-sub">Retour sur dépense publicitaire</div>
    </div>
    <div class="kpi">
      <div class="kpi-label">Spend total</div>
      <div class="kpi-value" id="kpi-spend">—</div>
      <div class="kpi-sub">Budget dépensé</div>
    </div>
    <div class="kpi">
      <div class="kpi-label">Revenus</div>
      <div class="kpi-value" id="kpi-revenue">—</div>
      <div class="kpi-sub" id="kpi-revenue-sub">Générés via ads</div>
    </div>
    <div class="kpi">
      <div class="kpi-label">Impressions</div>
      <div class="kpi-value" id="kpi-impressions">—</div>
      <div class="kpi-sub" id="kpi-reach-sub">Reach : —</div>
    </div>
    <div class="kpi">
      <div class="kpi-label">CTR moyen</div>
      <div class="kpi-value" id="kpi-ctr">—</div>
      <div class="kpi-sub" id="kpi-clicks-sub">— clics</div>
    </div>
    <div class="kpi">
      <div class="kpi-label">Créateurs</div>
      <div class="kpi-value" id="kpi-creators">—</div>
      <div class="kpi-sub" id="kpi-ads-sub">— contenus boostés</div>
    </div>
  </div>

  <!-- Chart + Top Creators -->
  <div class="row2">
    <div class="card">
      <div class="card-header">
        <span class="card-title">Évolution Spend <em style="font-style:italic;color:var(--red)">vs</em> Revenus</span>
      </div>
      <div class="card-body">
        <div class="chart-wrap">
          <canvas id="spendRevenueChart"></canvas>
        </div>
      </div>
    </div>
    <div class="card">
      <div class="card-header">
        <span class="card-title">Top Créateurs</span>
      </div>
      <div class="card-body" style="padding:8px 16px">
        <div class="creator-list" id="top-creators-list"></div>
      </div>
    </div>
  </div>

  <!-- Table -->
  <div class="table-wrap">
    <div class="table-header">
      <span class="table-title">Contenus boostés</span>
      <span class="table-count" id="table-count">0 ads</span>
    </div>
    <div class="table-scroll">
      <table id="ads-table">
        <thead>
          <tr>
            <th class="td-thumb"></th>
            <th data-col="ad_name">Contenu</th>
            <th data-col="creator_handle">Créateur</th>
            <th data-col="roas" class="sorted-desc">ROAS</th>
            <th data-col="spend">Spend</th>
            <th data-col="revenue">Revenus</th>
            <th data-col="impressions">Impressions</th>
            <th data-col="reach">Reach</th>
            <th data-col="ctr">CTR</th>
            <th data-col="purchases">Achats</th>
            <th data-col="video_avg_watch">Vidéo moy.</th>
            <th data-col="status">Statut</th>
            <th data-col="influence_score">Confiance</th>
            <th>Ciblage</th>
          </tr>
        </thead>
        <tbody id="table-body"></tbody>
      </table>
      <div class="no-results" id="no-results" style="display:none">
        <em>Aucun résultat</em>
        Modifiez les filtres pour afficher des données.
      </div>
    </div>
  </div>

  <footer>
    <span>Influence Paid Dashboard · Généré automatiquement</span>
    <span id="footer-stats"></span>
  </footer>
</div>

<script>
// ── Raw data injected by build_dashboard.py ────────────────
const RAW_DATA = __DATA_JSON__;
const TOP_CREATORS = __TOP_CREATORS_JSON__;
const CHART_DATA = __CHART_DATA_JSON__;

// ── State ──────────────────────────────────────────────────
let sortCol = 'roas';
let sortDir = 'desc';
let filteredData = [];

// ── Formatting helpers ─────────────────────────────────────
const fmt = {
  num: n => n == null ? '—' : new Intl.NumberFormat('fr-FR').format(Math.round(n)),
  eur: n => n == null ? '—' : new Intl.NumberFormat('fr-FR', {style:'currency', currency:'EUR', maximumFractionDigits:0}).format(n),
  pct: n => n == null ? '—' : (+n).toFixed(2) + '%',
  roas: n => n == null || n === 0 ? '—' : (+n).toFixed(2) + 'x',
  sec: n => n == null || n === 0 ? '—' : (+n).toFixed(1) + 's',
};

function roasClass(r) {
  if (!r || r === 0) return 'roas-low';
  if (r >= 3) return 'roas-high';
  if (r >= 1.5) return 'roas-med';
  return 'roas-low';
}

function confClass(score) {
  if (score >= 70) return 'conf-high';
  if (score >= 40) return 'conf-med';
  if (score >= 30) return 'conf-low';
  return 'conf-none';
}

function formatTargeting(t) {
  if (!t || typeof t !== 'object') return '—';
  const parts = [];
  if (t.age_min || t.age_max) parts.push(`${t.age_min||''}–${t.age_max||''}ans`);
  const genders = t.genders;
  if (genders) parts.push(genders.includes(1) && genders.includes(2) ? 'Tous' : genders.includes(1) ? 'H' : 'F');
  const geo = (t.geo_locations || {});
  const countries = (geo.countries || []).join(', ');
  if (countries) parts.push(countries);
  return parts.join(' · ') || '—';
}

// ── Filters ────────────────────────────────────────────────
function getDaysAgo(n) {
  const d = new Date(); d.setDate(d.getDate() - n); return d.toISOString().slice(0,10);
}

function applyFilters() {
  const type = document.getElementById('filter-type').value;
  const roasMin = parseFloat(document.getElementById('filter-roas').value) || 0;
  const status = document.getElementById('filter-status').value;
  const creator = document.getElementById('filter-creator').value;
  const search = document.getElementById('filter-search').value.toLowerCase().trim();
  const preset = document.getElementById('filter-preset').value;

  let data = RAW_DATA;

  // Date preset
  if (preset !== 'all') {
    const cutoff = getDaysAgo(parseInt(preset));
    data = data.filter(d => (d.date_stop || d.date_start || '') >= cutoff);
  }

  // Type
  if (type === 'influence') data = data.filter(d => d.is_influence);
  else if (type === 'non') data = data.filter(d => !d.is_influence);

  // ROAS min
  if (roasMin > 0) data = data.filter(d => (d.roas || 0) >= roasMin);

  // Status
  if (status !== 'all') data = data.filter(d => d.status === status);

  // Creator
  if (creator !== 'all') data = data.filter(d => (d.creator_handle || '') === creator);

  // Search
  if (search) {
    data = data.filter(d =>
      (d.ad_name || '').toLowerCase().includes(search) ||
      (d.campaign_name || '').toLowerCase().includes(search) ||
      (d.adset_name || '').toLowerCase().includes(search) ||
      (d.creator_handle || '').toLowerCase().includes(search)
    );
  }

  filteredData = data;
  sortAndRender();
  updateKPIs(data);
}

// ── Sort ───────────────────────────────────────────────────
function sortAndRender() {
  const sorted = [...filteredData].sort((a, b) => {
    let av = a[sortCol] ?? '', bv = b[sortCol] ?? '';
    if (typeof av === 'string') av = av.toLowerCase();
    if (typeof bv === 'string') bv = bv.toLowerCase();
    if (av < bv) return sortDir === 'asc' ? -1 : 1;
    if (av > bv) return sortDir === 'asc' ? 1 : -1;
    return 0;
  });
  renderTable(sorted);
}

document.querySelectorAll('th[data-col]').forEach(th => {
  th.addEventListener('click', () => {
    const col = th.dataset.col;
    if (sortCol === col) sortDir = sortDir === 'asc' ? 'desc' : 'asc';
    else { sortCol = col; sortDir = 'desc'; }
    document.querySelectorAll('th').forEach(t => t.classList.remove('sorted-asc','sorted-desc'));
    th.classList.add('sorted-' + sortDir);
    sortAndRender();
  });
});

// ── KPIs ───────────────────────────────────────────────────
function updateKPIs(data) {
  if (!data.length) {
    ['kpi-roas','kpi-spend','kpi-revenue','kpi-impressions','kpi-ctr','kpi-creators']
      .forEach(id => document.getElementById(id).textContent = '—');
    return;
  }
  const spend = data.reduce((s,d) => s + (d.spend||0), 0);
  const revenue = data.reduce((s,d) => s + (d.revenue||0), 0);
  const impressions = data.reduce((s,d) => s + (d.impressions||0), 0);
  const reach = data.reduce((s,d) => s + (d.reach||0), 0);
  const clicks = data.reduce((s,d) => s + (d.clicks||0), 0);
  const purchases = data.reduce((s,d) => s + (d.purchases||0), 0);
  const roas = spend > 0 ? revenue / spend : 0;
  const ctr = impressions > 0 ? (clicks / impressions * 100) : 0;
  const creators = new Set(data.filter(d=>d.creator_handle).map(d=>d.creator_handle)).size;
  const influenceAds = data.filter(d=>d.is_influence).length;

  document.getElementById('kpi-roas').innerHTML = roas > 0 ? roas.toFixed(2) + '<span class="unit">x</span>' : '—';
  document.getElementById('kpi-spend').textContent = fmt.eur(spend);
  document.getElementById('kpi-revenue').textContent = fmt.eur(revenue);
  document.getElementById('kpi-impressions').textContent = fmt.num(impressions);
  document.getElementById('kpi-ctr').textContent = fmt.pct(ctr);
  document.getElementById('kpi-creators').textContent = creators || '—';
  document.getElementById('kpi-reach-sub').textContent = `Reach : ${fmt.num(reach)}`;
  document.getElementById('kpi-clicks-sub').textContent = `${fmt.num(clicks)} clics`;
  document.getElementById('kpi-ads-sub').textContent = `${influenceAds} contenus influence`;
  document.getElementById('kpi-revenue-sub').textContent = `${fmt.num(purchases)} achats`;
  document.getElementById('table-count').textContent = `${data.length} ad${data.length>1?'s':''}`;
}

// ── Table ──────────────────────────────────────────────────
function renderTable(data) {
  const tbody = document.getElementById('table-body');
  const noResults = document.getElementById('no-results');

  if (!data.length) {
    tbody.innerHTML = '';
    noResults.style.display = '';
    return;
  }
  noResults.style.display = 'none';

  tbody.innerHTML = data.map(d => {
    const thumb = d.thumbnail_url
      ? `<img class="thumb-img" src="${escHtml(d.thumbnail_url)}" loading="lazy" alt="">`
      : `<div class="thumb-placeholder">🎬</div>`;

    const rClass = roasClass(d.roas);
    const signals = (d.signals || []).slice(0, 3).join(' · ');
    const permalink = d.instagram_permalink
      ? `<a class="permalink-link" href="${escHtml(d.instagram_permalink)}" target="_blank" rel="noopener">↗ IG</a>`
      : '';

    return `<tr>
      <td class="td-thumb">${thumb}</td>
      <td class="td-name">
        <span class="td-name-text" title="${escHtml(d.ad_name)}">${escHtml(d.ad_name||'—')}</span>
        <span class="td-name-sub">${escHtml(d.campaign_name||'')}${permalink ? ' · ' + permalink : ''}</span>
      </td>
      <td class="td-creator">${escHtml(d.creator_handle||'—')}</td>
      <td class="td-roas ${rClass}">${fmt.roas(d.roas)}</td>
      <td class="td-num">${fmt.eur(d.spend)}</td>
      <td class="td-num">${fmt.eur(d.revenue)}</td>
      <td class="td-num">${fmt.num(d.impressions)}</td>
      <td class="td-num">${fmt.num(d.reach)}</td>
      <td class="td-num">${fmt.pct(d.ctr)}</td>
      <td class="td-num">${fmt.num(d.purchases)}</td>
      <td class="td-num">${fmt.sec(d.video_avg_watch)}</td>
      <td><span class="badge ${d.status==='ACTIVE'?'badge-status-active':'badge-status-other'}">${d.status||'—'}</span></td>
      <td class="td-confidence">
        <span class="confidence-score ${confClass(d.influence_score)}">${d.influence_score||0}</span>
        <div class="signals-text" title="${escHtml(signals)}">${escHtml(signals||'—')}</div>
      </td>
      <td class="td-targeting">${escHtml(formatTargeting(d.targeting))}</td>
    </tr>`;
  }).join('');
}

function escHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
    .replace(/"/g,'&quot;').replace(/'/g,'&#39;');
}

// ── Top Creators ───────────────────────────────────────────
function renderTopCreators() {
  const el = document.getElementById('top-creators-list');
  if (!TOP_CREATORS.length) {
    el.innerHTML = '<div style="color:var(--ink-faint);font-size:12px;padding:16px 0">Aucun créateur détecté</div>';
    return;
  }
  el.innerHTML = TOP_CREATORS.slice(0,10).map((c, i) => `
    <div class="creator-row">
      <span class="creator-rank">${i+1}</span>
      <div>
        <div class="creator-name">${escHtml(c.handle||'Inconnu')}</div>
        <div class="creator-meta">${fmt.eur(c.spend)} spend · ${fmt.num(c.reach)} reach · ${c.ads} ad${c.ads>1?'s':''}</div>
      </div>
      <div style="text-align:right">
        <div class="creator-roas">${fmt.roas(c.roas)}</div>
        <div class="creator-roas-label">ROAS</div>
      </div>
    </div>
  `).join('');
}

// ── Chart ──────────────────────────────────────────────────
function initChart() {
  const ctx = document.getElementById('spendRevenueChart').getContext('2d');
  const labels = CHART_DATA.map(d => d.date);
  const spend = CHART_DATA.map(d => d.spend);
  const revenue = CHART_DATA.map(d => d.revenue);

  new Chart(ctx, {
    type: 'line',
    data: {
      labels,
      datasets: [
        {
          label: 'Revenus',
          data: revenue,
          borderColor: '#C0392B',
          backgroundColor: 'rgba(192,57,43,.08)',
          tension: 0.4,
          fill: true,
          pointRadius: 3,
          pointHoverRadius: 5,
        },
        {
          label: 'Spend',
          data: spend,
          borderColor: '#A8893A',
          backgroundColor: 'rgba(168,137,58,.05)',
          tension: 0.4,
          fill: false,
          borderDash: [4, 3],
          pointRadius: 2,
          pointHoverRadius: 4,
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: 'index', intersect: false },
      plugins: {
        legend: {
          labels: {
            font: { family: "'JetBrains Mono', monospace", size: 11 },
            color: '#5A5248',
            boxWidth: 12,
          }
        },
        tooltip: {
          backgroundColor: '#1A1714',
          titleFont: { family: "'JetBrains Mono', monospace", size: 11 },
          bodyFont: { family: "'JetBrains Mono', monospace", size: 11 },
          callbacks: {
            label: ctx => ` ${ctx.dataset.label}: ${new Intl.NumberFormat('fr-FR',{style:'currency',currency:'EUR',maximumFractionDigits:0}).format(ctx.raw)}`
          }
        }
      },
      scales: {
        x: {
          ticks: { font: { family: "'JetBrains Mono', monospace", size: 10 }, color: '#9B9189', maxTicksLimit: 10 },
          grid: { color: 'rgba(216,208,196,.4)' }
        },
        y: {
          ticks: {
            font: { family: "'JetBrains Mono', monospace", size: 10 },
            color: '#9B9189',
            callback: v => new Intl.NumberFormat('fr-FR',{style:'currency',currency:'EUR',notation:'compact',maximumFractionDigits:0}).format(v)
          },
          grid: { color: 'rgba(216,208,196,.4)' }
        }
      }
    }
  });
}

// ── Creator filter dropdown ────────────────────────────────
function populateCreatorFilter() {
  const handles = [...new Set(RAW_DATA.filter(d=>d.creator_handle && d.is_influence).map(d=>d.creator_handle))].sort();
  const sel = document.getElementById('filter-creator');
  handles.forEach(h => {
    const opt = document.createElement('option');
    opt.value = h; opt.textContent = h;
    sel.appendChild(opt);
  });
}

// ── Export CSV ─────────────────────────────────────────────
function exportCSV() {
  const cols = ['ad_id','ad_name','creator_handle','campaign_name','adset_name','status',
    'date_start','date_stop','roas','spend','revenue','impressions','reach','clicks',
    'ctr','cpm','purchases','video_avg_watch','influence_score','is_influence','signals'];
  const header = cols.join(',');
  const rows = filteredData.map(d =>
    cols.map(c => {
      let v = d[c];
      if (Array.isArray(v)) v = v.join('; ');
      if (v === null || v === undefined) v = '';
      v = String(v).replace(/"/g,'""');
      return `"${v}"`;
    }).join(',')
  );
  const csv = [header, ...rows].join('\n');
  const blob = new Blob(['\ufeff' + csv], {type:'text/csv;charset=utf-8'});
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a'); a.href = url;
  a.download = `influence-dashboard-${new Date().toISOString().slice(0,10)}.csv`;
  a.click(); URL.revokeObjectURL(url);
}

// ── Footer stats ───────────────────────────────────────────
function updateFooterStats() {
  const total = RAW_DATA.length;
  const influence = RAW_DATA.filter(d=>d.is_influence).length;
  document.getElementById('footer-stats').textContent =
    `${total} ads · ${influence} influence · Score ≥ 30`;
}

// ── Init ───────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  populateCreatorFilter();
  applyFilters();
  renderTopCreators();
  initChart();
  updateFooterStats();
});
</script>
</body>
</html>
