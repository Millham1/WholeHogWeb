# fix-landing-judges-and-teams-v2.ps1  (PS 5.1 & 7)
param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Read-Text([string]$Path){
  if(-not (Test-Path $Path)){ throw "File not found: $Path" }
  [IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8)
}
function Write-Text([string]$Path,[string]$Content){
  $dir = Split-Path $Path -Parent
  if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path,$Content,[Text.Encoding]::UTF8)
}
function Backup-Once([string[]]$Files){
  $stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $bak = Join-Path $WebRoot ("BACKUP_landing_fix_" + $stamp)
  $did = $false
  foreach($f in $Files){
    $p = Join-Path $WebRoot $f
    if(Test-Path $p){
      if(-not $did){ New-Item -ItemType Directory -Force -Path $bak | Out-Null; $did=$true }
      Copy-Item $p (Join-Path $bak (Split-Path $p -Leaf)) -Force
    }
  }
  if($did){ Write-Host "Backup saved at: $bak" -ForegroundColor Yellow }
}

function LastIndexOfCI([string]$s,[string]$find,[int]$before){
  # case-insensitive LastIndexOf before position
  $low = $s.ToLower()
  $f   = $find.ToLower()
  $limit = [Math]::Min([Math]::Max($before,0), $s.Length)
  return $low.LastIndexOf($f, $limit-1)
}
function IndexOfCI([string]$s,[string]$find,[int]$start=0){
  $i = $s.ToLower().IndexOf($find.ToLower(), $start)
  return $i
}
function ContainsCI([string]$s,[string]$sub){
  return $s.ToLower().Contains($sub.ToLower())
}
function FindTagEnd([string]$s,[int]$start){
  return $s.IndexOf('>', $start)
}

# From a given <div ... class="...card..."> start, find its matching </div>
function FindDivRange([string]$html,[int]$divStart){
  if($divStart -lt 0){ return $null }
  $len = $html.Length
  $firstGT = FindTagEnd $html $divStart
  if($firstGT -lt 0){ return $null }
  $pos = $firstGT + 1
  $depth = 1
  while($pos -lt $len){
    $nextOpen  = IndexOfCI $html '<div'  $pos
    $nextClose = IndexOfCI $html '</div' $pos
    if($nextClose -lt 0 -and $nextOpen -lt 0){ break }

    $takeOpen = $false
    if($nextOpen -ge 0 -and $nextClose -ge 0){
      $takeOpen = ($nextOpen -lt $nextClose)
    } elseif($nextOpen -ge 0){
      $takeOpen = $true
    } else {
      $takeOpen = $false
    }

    if($takeOpen){
      $gt = FindTagEnd $html $nextOpen
      if($gt -lt 0){ break }
      $depth += 1
      $pos = $gt + 1
    } else {
      $gt = FindTagEnd $html $nextClose
      if($gt -lt 0){ break }
      $depth -= 1
      $pos = $gt + 1
      if($depth -eq 0){
        return @{ Start = $divStart; End = $pos; Length = ($pos - $divStart) }
      }
    }
  }
  return $null
}

if(-not (Test-Path $WebRoot)){ throw "Web root not found: $WebRoot" }

$LandingHtml = Join-Path $WebRoot 'landing.html'
$LandingJs   = Join-Path $WebRoot 'landing-sb.js'
$SbCfg       = Join-Path $WebRoot 'supabase-config.js'

$missing = @()
foreach($f in @($LandingHtml,$SbCfg)){ if(-not (Test-Path $f)){ $missing += $f } }
if($missing.Count){ throw ("Missing required file(s):`r`n" + ($missing -join "`r`n")) }

Backup-Once @('landing.html','landing-sb.js')

# ===== 1) Remove duplicate Teams card =====
$html = Read-Text $LandingHtml
$positions = @()
# find all <h2 ...>...</h2> containing 'team'
$searchPos = 0
while($true){
  $h2 = IndexOfCI $html '<h2' $searchPos
  if($h2 -lt 0){ break }
  $gt = FindTagEnd $html $h2
  if($gt -lt 0){ break }
  $endH2 = IndexOfCI $html '</h2>' $gt
  if($endH2 -lt 0){ break }
  $inner = $html.Substring($gt+1, $endH2 - ($gt+1))
  if(ContainsCI $inner 'team'){
    $positions += @($h2)
  }
  $searchPos = $endH2 + 5
}

if($positions.Count -gt 1){
  # keep first, remove rest
  $toRemoveRanges = @()
  for($i=1; $i -lt $positions.Count; $i++){
    $h2Pos = $positions[$i]
    # find the nearest preceding <div ...> whose class contains 'card'
    $divOpen = LastIndexOfCI $html '<div' $h2Pos
    if($divOpen -lt 0){ continue }
    $divGT = FindTagEnd $html $divOpen
    if($divGT -lt 0){ continue }
    $openTag = $html.Substring($divOpen, ($divGT - $divOpen + 1))
    if(-not (ContainsCI $openTag 'class') -or -not (ContainsCI $openTag 'card')){ continue }
    $range = FindDivRange $html $divOpen
    if($range -ne $null){ $toRemoveRanges += ,$range }
  }

  if($toRemoveRanges.Count -gt 0){
    # remove from the end to keep indexes valid
    $toRemoveRanges = $toRemoveRanges | Sort-Object { $_.Start } -Descending
    foreach($r in $toRemoveRanges){
      $html = $html.Remove($r.Start, $r.Length)
    }
    Write-Text $LandingHtml $html
    Write-Host "Removed duplicate Teams card(s); kept the first." -ForegroundColor Cyan
  } else {
    Write-Host "Found multiple 'Team' headers, but could not resolve their card containers." -ForegroundColor DarkGray
  }
} else {
  Write-Host "Zero or one Teams header found; nothing to remove." -ForegroundColor DarkGray
}

# ===== 2) Ensure Judges list container exists in the Judges card =====
$html = Read-Text $LandingHtml
# locate Judges <h2>
$h2Judge = $null
$searchPos = 0
while($true){
  $pos = IndexOfCI $html '<h2' $searchPos
  if($pos -lt 0){ break }
  $gt  = FindTagEnd $html $pos
  if($gt -lt 0){ break }
  $end = IndexOfCI $html '</h2>' $gt
  if($end -lt 0){ break }
  $inner = $html.Substring($gt+1, $end - ($gt+1))
  if(ContainsCI $inner 'judge'){
    $h2Judge = @{ H2Start=$pos; H2End=$end+5 }
    break
  }
  $searchPos = $end + 5
}

if($h2Judge -ne $null){
  # find card wrapper around the judge H2
  $divOpen = LastIndexOfCI $html '<div' $h2Judge.H2Start
  if($divOpen -ge 0){
    $divGT = FindTagEnd $html $divOpen
    if($divGT -ge 0){
      $openTag = $html.Substring($divOpen, ($divGT - $divOpen + 1))
      if(ContainsCI $openTag 'class' -and ContainsCI $openTag 'card'){
        $range = FindDivRange $html $divOpen
        if($range -ne $null){
          $cardHtml = $html.Substring($range.Start, $range.Length)
          if( (IndexOfCI $cardHtml 'id="judgesList"' 0) -lt 0 -and (IndexOfCI $cardHtml "id='judgesList'" 0) -lt 0 ){
            # insert a placeholder list div right after the H2
            $before = $html.Substring(0, $h2Judge.H2End)
            $after  = $html.Substring($h2Judge.H2End)
            $insert = "`r`n<div id=""judgesList""></div>"
            $html = $before + $insert + $after
            Write-Text $LandingHtml $html
            Write-Host "Inserted <div id=""judgesList""> container." -ForegroundColor Cyan
          } else {
            Write-Host "judgesList container already present." -ForegroundColor DarkGray
          }
        }
      }
    }
  }
} else {
  Write-Host "No Judges header found; skipped judges list injection." -ForegroundColor DarkGray
}

# ===== 3) Append small JS block to render judges + remove, if our marker not present =====
if(-not (Test-Path $LandingJs)){ New-Item -ItemType File -Path $LandingJs -Force | Out-Null }
$js = Read-Text $LandingJs
if($js -notmatch [regex]::Escape('/* WH JUDGES START */')){
  $addon = @'
/* WH JUDGES START */
(function(){
  "use strict";
  function qs(sel,root){ return (root||document).querySelector(sel); }
  function qsa(sel,root){ return Array.prototype.slice.call((root||document).querySelectorAll(sel)); }
  function headers(){
    var key = (window.WHOLEHOG && WHOLEHOG.sbAnonKey) || "";
    return { "apikey": key, "Authorization":"Bearer "+key, "Content-Type":"application/json", "Prefer":"return=representation" };
  }
  function base(){ return (window.WHOLEHOG && WHOLEHOG.sbProjectUrl) || ""; }
  function get(p){ return fetch(base()+p,{method:"GET",headers:headers()}).then(r=>r.json()); }
  function post(p,b){ return fetch(base()+p,{method:"POST",headers:headers(),body:JSON.stringify(b)}).then(r=>r.json()); }
  function del(p){ return fetch(base()+p,{method:"DELETE",headers:headers()}).then(r=>{ if(!r.ok) throw new Error("delete failed"); }); }

  function findJudgesCard(){
    var cards = qsa(".card");
    for(var i=0;i<cards.length;i++){
      var h2 = qs("h2", cards[i]);
      if(!h2) continue;
      if((h2.textContent||"").toLowerCase().indexOf("judge") !== -1) return cards[i];
    }
    return null;
  }
  function ensureInputAndButton(card){
    var inp = document.getElementById("judgeName") || qs('input[type="text"]', card);
    if(!inp){
      inp = document.createElement("input");
      inp.type = "text"; inp.id = "judgeName"; inp.placeholder = "Judge name";
      card.appendChild(inp);
    }
    inp.removeAttribute("disabled"); inp.disabled=false;

    var btn = document.getElementById("btnAddJudge");
    if(!btn){
      btn = document.createElement("button");
      btn.type="button"; btn.id="btnAddJudge"; btn.textContent="Add Judge";
      card.appendChild(btn);
    }
    return {inp:inp, btn:btn};
  }
  function ensureList(card){
    var list = document.getElementById("judgesList");
    if(!list){ list = document.createElement("div"); list.id="judgesList"; card.appendChild(list); }
    return list;
  }
  function renderJudges(rows){
    var list = document.getElementById("judgesList");
    if(!list) return;
    if(!rows || !rows.length){ list.innerHTML = '<div class="muted">No judges yet.</div>'; return; }
    var html = '<ul class="judge-list">';
    rows.forEach(function(r){
      html += '<li class="judge-row"><span class="name">'+(r.name||"(unnamed)")+'</span> '+
              '<button type="button" class="btn-remove" data-id="'+r.id+'">Remove</button></li>';
    });
    html += '</ul>';
    list.innerHTML = html;
  }
  function loadJudges(){
    get('/rest/v1/judges?select=id,name&order=name.asc').then(renderJudges).catch(()=>{});
  }
  function hookRemove(){
    var list = document.getElementById("judgesList");
    if(!list) return;
    list.addEventListener("click", function(ev){
      var t = ev.target;
      if(t && t.classList && t.classList.contains("btn-remove")){
        var id = t.getAttribute("data-id");
        if(!id) return;
        if(!confirm("Remove this judge?")) return;
        del('/rest/v1/judges?id=eq.'+encodeURIComponent(id)).then(loadJudges).catch(()=>alert('Could not remove judge.'));
      }
    });
  }

  document.addEventListener("DOMContentLoaded", function(){
    var card = findJudgesCard();
    if(card){
      var ui = ensureInputAndButton(card);
      ensureList(card);
      ui.btn.addEventListener("click", function(){
        var name = (ui.inp.value||"").trim();
        if(!name){ alert("Enter judge name"); return; }
        post('/rest/v1/judges', [{name:name}]).then(function(){ ui.inp.value=""; loadJudges(); })
          .catch(()=>alert("Could not add judge."));
      });
      hookRemove();
    }
    loadJudges();
  });
})();
/* WH JUDGES END */
'@
  $js = $js + "`r`n" + $addon + "`r`n"
  Write-Text $LandingJs $js
  Write-Host "Appended judge render/remove logic to landing-sb.js" -ForegroundColor Cyan
} else {
  Write-Host "Judge logic already present in landing-sb.js" -ForegroundColor DarkGray
}

# Ensure landing-sb.js is referenced in landing.html
$html = Read-Text $LandingHtml
if($html -notmatch 'landing-sb\.js'){
  $html = $html.Replace('</body>', "  <script src=""landing-sb.js""></script>`r`n</body>")
  Write-Text $LandingHtml $html
  Write-Host "Added <script src=""landing-sb.js""> to landing.html" -ForegroundColor Cyan
} else {
  Write-Host "landing-sb.js already referenced." -ForegroundColor DarkGray
}

Write-Host "`nDone. Ctrl+F5 the landing page." -ForegroundColor Green

