param(
  [Parameter(Mandatory=$true)]
  [string]$Root
)

if (-not (Test-Path -LiteralPath $Root)) { Write-Error "Root not found: $Root"; exit 1 }

$files = @(
  "landing.html","onsite.html","blind.html","sauce.html","leaderboard.html","reports.html"
) | ForEach-Object { Join-Path $Root $_ } | Where-Object { Test-Path -LiteralPath $_ }

if (-not $files) { Write-Error "No target pages found in $Root"; exit 1 }

$rx = @{
  headClose   = '(?is)</head\s*>'
  supaScripts = '(?is)<script[^>]+src\s*=\s*["''][^"'']*(supabase|min\.js|supabase-config\.js)[^"'']*["''][^>]*>\s*</script>'
  # also catch inline “supabase” boot code blocks (best effort)
  supaInline  = '(?is)<script[^>]*>[^<]*supabase[^<]*</script>'
}

# Local-only stamp, before app scripts
$localFlag = @'
<script id="wh-local-only">
  // Force local-only mode (no Supabase)
  window.WH_LOCAL_ONLY = true;
  // Hard no-op any accidental Supabase references (safety)
  window.supabase = undefined;
  window.createClient = function(){ return {}; };
  console.warn("[wh] Local-only mode: Supabase disabled");
</script>
'@

# Safe guard: prevent "Cannot set properties of null (setting 'innerHTML')" crashes.
# If a script asks for a known leaderboard/onsite id that doesn't exist, create a placeholder.
$guard = @'
<script id="wh-safe-guard">
(function(){
  const knownIds = [
    // common containers used across your pages (non-destructive if they already exist)
    "onsite-leaders","onsite-leaderboard","onsite-leaders-card",
    "division-leaders","division-leaders-card",
    "blind-leaders","sauce-leaders","leaderboard-root","leaders"
  ];
  document.addEventListener('DOMContentLoaded', function(){
    knownIds.forEach(id=>{
      if (!document.getElementById(id)) {
        const holder = document.createElement('div');
        holder.id = id;
        holder.style.display = 'block'; // allow rendering if scripts target it
        holder.setAttribute('data-wh-autocreated','1');
        document.body.appendChild(holder);
      }
    });
  });
})();
</script>
'@

# Inline SVG favicon (stops /favicon.ico 404 without adding a file)
$favicon = @'
<link id="wh-favicon" rel="icon" href="data:image/svg+xml,%3Csvg xmlns=%27http://www.w3.org/2000/svg%27 viewBox=%270 0 64 64%27%3E%3Crect width=%2764%27 height=%2764%27 rx=%279%27 fill=%27%23e53935%27/%3E%3Ctext x=%2732%27 y=%2738%27 font-size=%2730%27 text-anchor=%27middle%27 fill=%27%23000%27 font-family=%27Arial,Helvetica,sans-serif%27%3EWH%3C/text%3E%3C/svg%3E">
'@

function InsertBeforeHeadClose([string]$html, [string]$block, [switch]$onlyIfMissing, [string]$idToCheck) {
  if ($onlyIfMissing -and $idToCheck) {
    if ($html -match "(?is)<(script|link)[^>]+id\s*=\s*['""]$([regex]::Escape($idToCheck))['""][^>]*>") {
      return $html
    }
  }
  if ($html -match $rx.headClose) {
    return [regex]::Replace($html, $rx.headClose, ($block + "`r`n</head>"), 'IgnoreCase,Singleline')
  }
  # If <head> missing (rare), prepend
  return $block + "`r`n" + $html
}

foreach ($path in $files) {
  $html = Get-Content -LiteralPath $path -Raw
  $bak  = "$path.bak_$(Get-Date -Format yyyyMMdd-HHmmss)"
  Copy-Item -LiteralPath $path -Destination $bak -Force
  Write-Host "Backup: $bak"

  $updated = $html
  $changed = $false

  # 1) Remove Supabase script tags (cdn + config)
  $tmp = [regex]::Replace($updated, $rx.supaScripts, '', 'IgnoreCase,Singleline')
  if ($tmp -ne $updated) { $updated = $tmp; $changed = $true }

  # 2) Remove inline Supabase boot blocks (best effort)
  $tmp = [regex]::Replace($updated, $rx.supaInline, '', 'IgnoreCase,Singleline')
  if ($tmp -ne $updated) { $updated = $tmp; $changed = $true }

  # 3) Ensure local-only stamp and favicon in <head>
  $before = $updated
  $updated = InsertBeforeHeadClose $updated $favicon -onlyIfMissing:$true -idToCheck 'wh-favicon'
  $updated = InsertBeforeHeadClose $updated $localFlag -onlyIfMissing:$true -idToCheck 'wh-local-only'
  if ($updated -ne $before) { $changed = $true }

  # 4) Add the null-guard script near the end of body; if no </body>, append
  if ($updated -notmatch '(?is)<script[^>]+id\s*=\s*["'']wh-safe-guard["'']') {
    if ($updated -match '(?is)</body\s*>') {
      $updated = [regex]::Replace($updated, '(?is)</body\s*>', ($guard + "`r`n</body>"), 'IgnoreCase,Singleline')
    } else {
      $updated = $updated + "`r`n" + $guard
    }
    $changed = $true
  }

  if ($changed) {
    Set-Content -LiteralPath $path -Value $updated -Encoding UTF8
    Write-Host "✅ Patched: $([IO.Path]::GetFileName($path))" -ForegroundColor Green
  } else {
    Write-Host "ℹ️ No changes needed: $([IO.Path]::GetFileName($path))" -ForegroundColor Yellow
  }
}

Write-Host "`nDone. Push changes and reload your GitHub Pages site." -ForegroundColor Cyan
