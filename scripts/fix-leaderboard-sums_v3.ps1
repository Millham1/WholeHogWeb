param(
  [Parameter(Mandatory=$true)] [string]$LeaderboardPath
)

function Read-Utf8NoBom([string]$p){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::ReadAllText((Resolve-Path $p), $enc)
}
function Write-Utf8NoBom([string]$p,[string]$s){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p,$s,$enc)
}
function Backup([string]$p){
  if (!(Test-Path $p)) { throw "File not found: $p" }
  $bak = "$p.$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
  Copy-Item $p $bak -Force | Out-Null
  Write-Host "🔒 Backup: $bak"
  return $bak
}

if (!(Test-Path $LeaderboardPath)) { throw "File not found: $LeaderboardPath" }
Backup $LeaderboardPath | Out-Null

# Read file
$html = Read-Utf8NoBom $LeaderboardPath

# 1) Remove the two previous injected scripts by id (safe if absent)
$removePat = '(?is)\s*<script\b[^>]*\bid\s*=\s*["''](?:wh-force-sum-leaders|wh-sauce-leaders-script)["''][^>]*>.*?</script>\s*'
$html = [regex]::Replace($html, $removePat, '')

# 2) Inject a single clean sums-only renderer (no chip on On-site)
$cleanJs = @'
<script id="wh-sum-leaders-clean">
(function(){
  const $ = s => document.querySelector(s);
  const K = { onsite:"onsiteScores", blind:"blindScores", sauce:"sauceScores" };

  function sumNumbers(obj){
    let s = 0;
    if (!obj || typeof obj !== "object") return 0;
    for (const v of Object.values(obj)){
      const n = Number(v); if (Number.isFinite(n)) s += n;
    }
    return s;
  }

  // ---------- ONSITE (sum all judges' category points) ----------
  function buildOnsiteTotals(){
    const raw = JSON.parse(localStorage.getItem(K.onsite) || "[]");
    const byTeam = new Map();
    for (const r of raw){
      const team = (r.team || "").trim(); if (!team) continue;
      const s = r.scores || {};
      const add = (Number(s.appearance)||0) + (Number(s.tenderness)||0) + (Number(s.flavor)||0) + (Number(s.overall)||0);
      const agg = byTeam.get(team) || { team, total:0, cat:{appearance:0,tenderness:0,flavor:0,overall:0} };
      agg.total += add;
      agg.cat.appearance += Number(s.appearance)||0;
      agg.cat.tenderness += Number(s.tenderness)||0;
      agg.cat.flavor    += Number(s.flavor)||0;
      agg.cat.overall   += Number(s.overall)||0;
      byTeam.set(team, agg);
    }
    const ORDER = ["flavor","tenderness","appearance","overall"]; // tie-break order
    const rows = Array.from(byTeam.values()).sort((a,b)=>{
      if (b.total !== a.total) return b.total - a.total;
      for (const k of ORDER){ const d = (b.cat[k]||0) - (a.cat[k]||0); if (d) return d; }
      return 0;
    });
    return rows.map((row,i,arr)=>{
      let tie=""; if (i>0 && row.total === arr[i-1].total){
        for (const k of ORDER){ if ((row.cat[k]||0)!==(arr[i-1].cat[k]||0)){ tie=k; break; } }
      }
      return { team:row.team, total:row.total, tie };
    });
  }

  function renderOnsite(){
    const host = $("#onsite-list"); if (!host) return;
    const items = buildOnsiteTotals();
    if (!items.length){ host.innerHTML = '<div class="muted">No on-site scores yet.</div>'; return; }
    host.innerHTML = items.map(({team,total,tie})=>{
      const tieBadge = tie ? `<span class="badge" title="Tie broken on ${tie}">tie: ${tie}</span>` : "";
      return `
        <div class="row">
          <div>
            <div><strong>${team}</strong> ${tieBadge}</div>
            <div class="muted">on-site total (sum)</div>
          </div>
          <div class="score"
