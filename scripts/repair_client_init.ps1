# repair_client_init.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = 'C:\Users\millh_y3006x1\Desktop\WholeHogWeb'
$blind = Join-Path $root 'blind-taste.html'
if (!(Test-Path $blind)) {
  $alt = Join-Path $root 'blindtaste.html'
  if (Test-Path $alt) { $blind = $alt } else { throw 'Blind Taste page not found.' }
}

$config = Join-Path $root 'supabase-config.js'
if (!(Test-Path $config)) { New-Item -ItemType File -Path $config -Force | Out-Null }

# Backups
$bakBlind  = "$blind.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
$bakConfig = "$config.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item $blind  $bakBlind  -Force
Copy-Item $config $bakConfig -Force

# 1) Write a known-good supabase-config.js that uses the UMD global and exposes window.supabase
$supaUrl = 'https://wiolulxxfyetvdpnfusq.supabase.co'
$supaKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc'

$configJs = @"
;(function(){
  try{
    // The CDN exposes a global named \`supabase\` (UMD). Use it to create a client.
    if (typeof supabase === 'undefined' || typeof supabase.createClient !== 'function') {
      console.error('[supabase-config] Supabase UMD not loaded yet.');
      return;
    }
    var client = supabase.createClient('$supaUrl', '$supaKey');
    // Expose the client globally for other scripts
    window.supabase = client;
    window.supabaseClient = client;
    console.log('[supabase-config] client ready:', typeof window.supabase.from === 'function');
  }catch(e){
    console.error('[supabase-config] init failed', e);
  }
})();
"@
Set-Content -LiteralPath $config -Encoding UTF8 -Value $configJs

# 2) Ensure blind-taste.html includes the CDN then config BEFORE any BT_SYNC block
$html = Get-Content -LiteralPath $blind -Raw -Encoding UTF8

$cdnTag = '<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>'
$cfgTag = '<script src="supabase-config.js"></script>'

# Remove any existing copies to avoid duplicates
$html = $html -replace [regex]::Escape($cdnTag), ''
$html = [regex]::Replace($html, '(?is)<script[^>]*\bsrc\s*=\s*["'']supabase-config\.js["''][^>]*>\s*</script>', '')

# Find BT_SYNC block (our Blind-Taste logic); we want CDN+config before it
$syncIdx = [regex]::Match($html, '(?is)<!--\s*BT_SYNC_START\s*-->').Index
if ($syncIdx -gt 0) {
  $prefix = $html.Substring(0,$syncIdx)
  $suffix = $html.Substring($syncIdx)
  $html = $prefix + $cdnTag + "`r`n" + $cfgTag + "`r`n" + $suffix
}
elseif ($html -match '(?is)</body\s*>') {
  # Otherwise, put them just before </body>
  $html = [regex]::Replace($html,'(?is)</body\s*>', ($cdnTag + "`r`n" + $cfgTag + "`r`n</body>"), 1)
}
else {
  $html += "`r`n$cdnTag`r`n$cfgTag"
}

Set-Content -LiteralPath $blind -Encoding UTF8 -Value $html

Write-Host "✅ Fixed Supabase client init. Backups: $([IO.Path]::GetFileName($bakBlind)), $([IO.Path]::GetFileName($bakConfig))" -ForegroundColor Green
Start-Process $blind
