
$ErrorActionPreference = 'Stop'

# --- FILES ---
$WebRoot     = 'C:\Users\millh_y3006x1\Desktop\WholeHogWeb'
$LandingHtml = Join-Path $WebRoot 'landing.html'
$IndexHtml   = Join-Path $WebRoot 'index.html'

# --- HELPERS ---
function Ensure-File($p){ if(-not (Test-Path $p)){ throw "File not found: $p" } }
function Read-Text($p){ return [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }
function Write-Text($p, [string]$text){
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $text, $utf8NoBom)
}
function Backup-Once($path){ $bak = "$path.bak"; if(-not (Test-Path $bak)){ Copy-Item $path $bak } }

# Insert or replace a marked block (ASCII markers)
function Inject-Or-Replace {
  param([string]$FilePath,[string]$Marker,[string]$Block)
  $content = Read-Text $FilePath
  $start = "<!-- WHOLEHOG-$Marker-START -->"
  $end   = "<!-- WHOLEHOG-$Marker-END -->"
  $payload = "$start`r`n$Block`r`n$end"

  $pattern = [System.Text.RegularExpressions.Regex]::Escape($start) + ".*?" + [System.Text.RegularExpressions.Regex]::Escape($end)
  $rx = New-Object System.Text.RegularExpressions.Regex($pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)

  if($rx.IsMatch($content)){
    $new = $rx.Replace($content, $payload, 1)
    Write-Text $FilePath $new
    return
  }

  $bodyRx = New-Object System.Text.RegularExpressions.Regex("</body>", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if($bodyRx.IsMatch($content)){
    $new = $bodyRx.Replace($content, "`r`n$payload`r`n</body>", 1)
    Write-Text $FilePath $new
  } else {
    Write-Text $FilePath ($content + "`r`n" + $payload + "`r`n")
  }
}

# Ensure <meta charset="utf-8"> exists (ASCII only)
function Ensure-Charset {
  param([string]$FilePath)
  $html = Read-Text $FilePath
  $hasMeta = [System.Text.RegularExpressions.Regex]::IsMatch($html, "<meta\s+charset=", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if(-not $hasMeta){
    $headRx = New-Object System.Text.RegularExpressions.Regex("<head[^>]*>", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if($headRx.IsMatch($html)){
      $html = $headRx.Replace($html, { param($m) $m.Value + "`r`n  <meta charset=""utf-8""/>" }, 1)
    } else {
      $html = "<meta charset=""utf-8""/>`r`n" + $html
    }
    Write-Text $FilePath $html
  }
}

# Replace mangled labels like "Appearance (2–40)" with ASCII "Appearance (2-40)"
function Fix-Labels {
  param([string]$FilePath)
  $html = Read-Text $FilePath
  $pairs = @(
    @{ p = "\bAppearance\s*\([^)]*\)"; r = "Appearance (2-40)" },
    @{ p = "\bColor\s*\([^)]*\)";      r = "Color (2-40)" },
    @{ p = "\bSkin\s*\([^)]*\)";       r = "Skin (4-80)" },
    @{ p = "\bMoisture\s*\([^)]*\)";   r = "Moisture (4-80)" },
    @{ p = "\bMeat\s*&\s*Sauce\s*\([^)]*\)"; r = "Meat & Sauce (4-80)" }
  )
  foreach($x in $pairs){
    $rx = New-Object System.Text.RegularExpressions.Regex($x.p, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $html = $rx.Replace($html, $x.r)
  }
  Write-Text $FilePath $html
}

# LANDING → store ids and navigate with query string
$LandingBridge = @'
<script>
(function () {
  try {
    function setHint(id, key){ if(id){ localStorage.setItem(key, id); } }

    // Hook your existing "Go to On-Site" button
    var go = document.getElementById("goOnsiteBtn");
    if(go && !go.dataset.whook){
      go.dataset.whook = "1";
      go.addEventListener("click", function(){
        var t = localStorage.getItem("wh_selected_team_id") || "";
        var j = localStorage.getItem("wh_selected_judge_id") || "";
        var qs = [];
        if(t) qs.push("teamId="+encodeURIComponent(t));
        if(j) qs.push("judgeId="+encodeURIComponent(j));
        location.href = "index.html" + (qs.length ? ("?"+qs.join("&")) : "");
      });
    }

    // If your Supabase inserts call .select().single(), set IDs afterward:
    // Example hooks (optional, safe if not found):
    document.addEventListener("wh:setTeamId", function(e){ setHint(e.detail, "wh_selected_team_id"); });
    document.addEventListener("wh:setJudgeId", function(e){ setHint(e.detail, "wh_selected_judge_id"); });
  } catch(e){ console.warn(e); }
})();
</script>
'@

# ONSITE ← read ids from query/localStorage and preselect after lists load
$OnsiteBridge = @'
<script>
(function () {
  try {
    function param(name){
      var m = location.search.match(new RegExp("[?&]"+name+"=([^&]+)"));
      return m ? decodeURIComponent(m[1]) : "";
    }
    var wantTeam  = param("teamId")  || localStorage.getItem("wh_selected_team_id")  || "";
    var wantJudge = param("judgeId") || localStorage.getItem("wh_selected_judge_id") || "";

    function trySelect(){
      var ts = document.getElementById("teamSelect");
      var js = document.getElementById("judgeSelect");
      var changed = false;
      if(ts && wantTeam && ts.querySelector('option[value="'+wantTeam+'"]')) { ts.value = wantTeam; changed = true; }
      if(js && wantJudge && js.querySelector('option[value="'+wantJudge+'"]')) { js.value = wantJudge; changed = true; }
      if(changed){
        if(ts) localStorage.setItem("wh_selected_team_id", ts.value||"");
        if(js) localStorage.setItem("wh_selected_judge_id", js.value||"");
      }
      return changed;
    }

    var tries = 0;
    (function tick(){
      if (trySelect() || tries > 40) return;
      tries++;
      setTimeout(tick, 50);
    })();

    window.addEventListener("change", function(ev){
      if(!ev.target) return;
      if(ev.target.id === "teamSelect"){ localStorage.setItem("wh_selected_team_id", ev.target.value||""); }
      if(ev.target.id === "judgeSelect"){ localStorage.setItem("wh_selected_judge_id", ev.target.value||""); }
    }, true);
  } catch(e){ console.warn(e); }
})();
</script>
'@

# --- APPLY CHANGES ---

if(-not (Test-Path $WebRoot)){ throw "Web root not found: $WebRoot" }

# landing.html
Ensure-File $LandingHtml
Backup-Once  $LandingHtml
Ensure-Charset $LandingHtml
Inject-Or-Replace -FilePath $LandingHtml -MarkerName 'LANDING-BRIDGE' -Block $LandingBridge

# index.html (on-site)
Ensure-File $IndexHtml
Backup-Once  $IndexHtml
Ensure-Charset $IndexHtml
Fix-Labels    $IndexHtml
Inject-Or-Replace -FilePath $IndexHtml -MarkerName 'ONSITE-BRIDGE' -Block $OnsiteBridge

Write-Host "`nDone. Refresh both pages (Ctrl+F5)." -ForegroundColor Green
Get-Item $LandingHtml, $IndexHtml | Select-Object FullName,Length,LastWriteTime | Format-Table -AutoSize

