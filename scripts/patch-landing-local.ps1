param(
  [Parameter(Mandatory=$true)]
  [string]$File
)

function Read-Utf8NoBom([string]$p){
  $enc = New-Object System.Text.UTF8Encoding($false)
  return [System.IO.File]::ReadAllText((Resolve-Path $p), $enc)
}
function Write-Utf8NoBom([string]$p, [string]$s){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $s, $enc)
}

if (!(Test-Path $File)) { throw "File not found: $File" }

# 1) Backup
$backupDir = Join-Path (Split-Path -Parent $File) "backup"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupPath = Join-Path $backupDir ("{0}_{1}" -f (Split-Path $File -Leaf), $stamp)
Copy-Item $File $backupPath -Force

# 2) Read file
$html = Read-Utf8NoBom $File

# 3) Remove <script src="landing-sb.js"></script> (with optional spaces/attrs)
$patSb = '(?is)\s*<script[^>]*\bsrc\s*=\s*["'']landing-sb\.js["''][^>]*>\s*</script>\s*'
$html = [regex]::Replace($html, $patSb, '')

# 4) Build the replacement WH_SYNC block (local-only, using your exact IDs).
$syncLines = @(
'<!-- WH_SYNC_START (local-only replacement) -->'
'<script>'
'(function(){'
'  const K = {'
'    teams: "wh_Teams",'
'    judges: "wh_Judges",'
'    selTeam: "selectedTeamName",'
'    selJudge: "selectedJudgeName",'
'    chipMap: "wh_chipByTeam",'
'    blindA: "blindEntries",'
'    blindB: "blindScores",'
'    onsite: "onsiteScores"'
'  };'
'  const $ = (s,r)=> (r||document).querySelector(s);'
'  function getList(k){ try { return JSON.parse(localStorage.getItem(k)||"[]"); } catch { return []; } }'
'  function setList(k,v){ localStorage.setItem(k, JSON.stringify(v)); }'
'  function getJSON(k,fb){ try { const v=localStorage.getItem(k); return v?JSON.parse(v):fb; } catch { return fb; } }'
'  function setJSON(k,v){ localStorage.setItem(k, JSON.stringify(v)); }'
''
'  function hasChip(team){'
'    if (!team) return false;'
'    const map = getJSON(K.chipMap, null);'
'    if (map && typeof map==="object" && String(map[team]||"").trim()!=="") return true;'
'    for (const key of [K.blindA, K.blindB, K.onsite]){'
'      const arr = getList(key);'
'      if (arr.some(r => ((r.team||r.teamName)||"")===team && String((r.chip||r.chip_number||"")).trim()!=="")) return true;'
'    }'
'    return false;'
'  }'
''
'  function renderTeams(){'
'    const ul = document.getElementById("whTeamsList");'
'    if (!ul) return;'
'    const teams = getList(K.teams);'
'    if (!teams.length){ ul.innerHTML = ""; return; }'
'    const anySite = teams.some(t => (t.site||"").trim()!=="");'
'    const head = `<li style="padding:6px 4px;border-bottom:2px solid #ddd;display:grid;grid-template-columns:160px 1fr ${anySite?"120px":""} 140px;gap:8px;font-weight:700;">'
'      <span>Affiliation</span><span>Team Name</span>${anySite?''<span>Site #</span>'':''}<span>Chip Entered</span></li>`;'
'    const rows = teams.map(t=>{'
'      const aff  = t.affiliation || "";'
'      const name = t.name || "";'
'      const site = (t.site||"").toString();'
'      const chip = hasChip(name) ? "Yes" : "No";'
'      return `<li style="padding:6px 4px;border-bottom:1px solid #eee;display:grid;grid-template-columns:160px 1fr ${anySite?"120px":""} 140px;gap:8px;align-items:center;">'
'        <span>${aff}</span><span>${name}</span>${anySite?''<span>${site}</span>'':''}<span><strong>${chip}</strong></span></li>`;'
'    }).join("");'
'    ul.innerHTML = head + rows;'
'  }'
''
'  function renderJudges(){'
'    const host = document.getElementById("judgesList");'
'    if (!host) return;'
'    const judges = getList(K.judges);'
'    if (!judges.length){ host.innerHTML = ""; return; }'
'    host.innerHTML = `<ul style="margin:8px 0 0; padding-left:16px;">${'
'      judges.map(j => `<li>${j.name||""}</li>`).join("")'
'    }</ul>`;'
'  }'
''
'  document.addEventListener("DOMContentLoaded", function(){'
'    // Remove "Current Entries" card if present'
'    const entriesCard = document.getElementById("entries-viewer");'
'    if (entriesCard && entriesCard.parentNode) entriesCard.parentNode.removeChild(entriesCard);'
''
'    // Wire Add Team'
'    const addTeamBtn = document.getElementById("whBtnAddTeam");'
'    if (addTeamBtn){'
'      addTeamBtn.addEventListener("click", function(ev){'
'        ev.preventDefault(); ev.stopImmediatePropagation();'
'        const nameEl = document.getElementById("whTeamName");'
'        const chipEl = document.getElementById("chip");'
'        const siteEl = document.getElementById("whSiteNumber");'
'        const legEl  = document.getElementById("legionFlag");'
'        const sonEl  = document.getElementById("sonsFlag");'
'        const name = String(nameEl && nameEl.value || "").trim();'
'        if (!name){ alert("Enter a team name."); return false; }'
'        const teams = getList(K.teams);'
'        let rec = teams.find(t => (t.name||"").toLowerCase() === name.toLowerCase());'
'        const aff = (legEl && legEl.checked ? "Legion" : "") + (sonEl && sonEl.checked ? ((legEl&&legEl.checked)?" & ":"")+"Sons" : "");'
'        const site = String(siteEl && siteEl.value || "").trim();'
'        if (rec){ rec.affiliation = aff; rec.site = site; }'
'        else { rec = { name, affiliation: aff, site, ts: new Date().toISOString() }; teams.push(rec); }'
'        setList(K.teams, teams);'
'        localStorage.setItem(K.selTeam, name);'
'        const chipVal = String(chipEl && chipEl.value || "").trim();'
'        if (chipVal){ const cmap = getJSON(K.chipMap, {}) || {}; cmap[name] = chipVal; setJSON(K.chipMap, cmap); }'
'        if (nameEl) nameEl.value = "";'
'        if (chipEl) chipEl.value = "";'
'        if (siteEl) siteEl.value = "";'
'        if (legEl)  legEl.checked = false;'
'        if (sonEl)  sonEl.checked = false;'
'        renderTeams();'
'        alert("Team saved locally: " + name);'
'        return false;'
'      }, true);'
'    }'
''
'    // Wire Add Judge'
'    const judgeForm = document.getElementById("judgeForm");'
'    if (judgeForm){'
'      judgeForm.addEventListener("submit", function(ev){'
'        ev.preventDefault(); ev.stopImmediatePropagation();'
'        const nameEl = document.getElementById("judgeName");'
'        const name = String(nameEl && nameEl.value || "").trim();'
'        if (!name){ alert("Enter a judge name."); return false; }'
'        const judges = getList(K.judges);'
'        if (!judges.some(j => (j.name||"").toLowerCase() === name.toLowerCase())){'
'          judges.push({ name, ts: new Date().toISOString() });'
'          setList(K.judges, judges);'
'        }'
'        localStorage.setItem(K.selJudge, name);'
'        if (nameEl) nameEl.value = "";'
'        renderJudges();'
'        alert("Judge saved locally: " + name);'
'        return false;'
'      }, true);'
'    }'
''
'    // First render'
'    renderTeams();'
'    renderJudges();'
'  });'
'})();'
'</script>'
'<!-- WH_SYNC_END -->'
)
$syncBlock = [string]::Join("`r`n", $syncLines)

# 5) Replace existing WH_SYNC block; if missing, inject before </body>
$patSyncBlock = '(?is)<!--\s*WH_SYNC_START\b.*?-->\s*<script[^>]*>.*?</script>\s*(<!--\s*WH_SYNC_END\s*-->)?'
if ([regex]::IsMatch($html, $patSyncBlock)) {
  $html = [regex]::Replace($html, $patSyncBlock, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $syncBlock }, 1)
} else {
  # inject before </body>
  if ([regex]::IsMatch($html, '(?is)</body\s*>')) {
    $html = [regex]::Replace($html, '(?is)</body\s*>', ($syncBlock + "`r`n</body>"), 1)
  } else {
    $html = $html + "`r`n" + $syncBlock
  }
}

# 6) Write back
Write-Utf8NoBom $File $html
Write-Host "✅ Patched $File"
Write-Host "• Backup at: $backupPath"
Write-Host "• Removed: <script src=`"landing-sb.js`"></script>"
Write-Host "• Replaced/Inserted: WH_SYNC block with local-only logic"
