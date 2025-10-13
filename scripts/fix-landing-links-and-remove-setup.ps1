param(
  [string]$Root = ".",
  [string]$LandingFile = "landing.html"
)

$ErrorActionPreference = "Stop"

$rootPath    = Resolve-Path $Root
$landingPath = Join-Path $rootPath $LandingFile
if (!(Test-Path $landingPath)) { Write-Error "Landing file not found: $landingPath"; exit 1 }

# Read file
$text = Get-Content -Path $landingPath -Raw

# --- 1) Fix any links/buttons pointing to blind-taste*.html -> blind.html (case-insensitive) ---
# Covers href="blind-taste.html", onclick="location.href='blind-taste.html'", and variants
$text = $text -replace '(?i)blind[-\s]?taste\.html', 'blind.html'

# --- 2) Remove the Setup: Judges & Chips (local) card ---

# Primary removal via explicit markers
$beginMarker = '<!-- BEGIN JudgesChipsSetup -->'
$endMarker   = '<!-- END JudgesChipsSetup -->'

$beginIdx = $text.IndexOf($beginMarker)
$endIdx   = $text.IndexOf($endMarker)

if ($beginIdx -ge 0 -and $endIdx -ge 0 -and $endIdx -gt $beginIdx) {
  $afterEnd = $endIdx + $endMarker.Length
  $text = $text.Substring(0, $beginIdx) + $text.Substring($afterEnd)
}
else {
  # Fallback: remove the <section id="judges-chips-setup">…</section> block if present
  $low = $text.ToLowerInvariant()
  $idPos = $low.IndexOf('id="judges-chips-setup"')
  if ($idPos -ge 0) {
    # Find the start of the enclosing <section ...> before id
    $startSection = $low.LastIndexOf('<section', $idPos)
    if ($startSection -ge 0) {
      # Find the closing </section> after id
      $endSection = $low.IndexOf('</section>', $idPos)
      if ($endSection -ge 0) {
        $afterSection = $endSection + 10  # len('</section>') = 10

        # Optionally remove a script block immediately after (if it belongs to setup)
        $afterSlice = $text.Substring($afterSection)
        $afterLow   = $afterSlice.ToLowerInvariant()

        # Skip leading whitespace/newlines
        $trimmed = $afterLow.TrimStart()
        if ($trimmed.StartsWith("<script")) {
          # Find the first <script ...> ... </script> in afterSlice
          $scriptStartRel = $afterLow.IndexOf('<script')
          $scriptEndRel   = $afterLow.IndexOf('</script>')
          if ($scriptStartRel -ge 0 -and $scriptEndRel -ge 0 -and $scriptEndRel -gt $scriptStartRel) {
            $afterSection += ($scriptEndRel + 9)  # jump past '</script>'
          }
        }

        # Remove the section (and optional script)
        $text = $text.Substring(0, $startSection) + $text.Substring($afterSection)
      }
    }
  }
}

# --- Backup and write ---
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item $landingPath (Join-Path $rootPath ("landing.backup-" + $stamp + ".html")) -Force
$text | Set-Content -Path $landingPath -Encoding UTF8

Write-Host "✅ Updated ${LandingFile}:"
Write-Host "   • All Blind links now point to blind.html"
Write-Host "   • Removed 'Setup: Judges & Chips (local)' card (markers or fallback section removal)"
Write-Host ("Open: file:///" + ((Resolve-Path $landingPath).Path -replace '\\','/'))

