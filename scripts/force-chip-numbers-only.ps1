param(
  [string]$Root = ".",
  # If your Blind Taste page is a different file, put it here (e.g. "blind-taste.html").
  [string]$HtmlFile = "index.html"
)

$Root = Resolve-Path $Root
$htmlPath = Join-Path $Root $HtmlFile
$jsPath   = Join-Path $Root "forceChipNumbersOnly.js"

# 1) Write the sanitizer JS (idempotent overwrite)
@'
/**
 * Force chip dropdowns to display numbers only.
 * Works even if a previous script set "123 - Team Name" etc.
 */
(function () {
  function sanitizeChipSelects() {
    var selects = Array.prototype.slice.call(document.querySelectorAll("select"))
      .filter(function (el) {
        var id = (el.id || "").toLowerCase();
        var name = (el.name || "").toLowerCase();
        return id.includes("chip") || name.includes("chip");
      });

    selects.forEach(function (sel) {
      // Keep placeholder as-is; sanitize subsequent options
      for (var i = 0; i < sel.options.length; i++) {
        var opt = sel.options[i];
        if (!opt) continue;
        // Try to capture the leading integer
        var txt = String(opt.textContent || opt.label || "").trim();
        var m = txt.match(/^(\d{1,6})\b/); // up to 6 digits; adjust if your chips are longer
        if (m) {
          var num = m[1];
          opt.textContent = num;
          opt.label = num;
          opt.value = num;
        }
      }
    });
  }

  // Run after DOM and again after load (in case other scripts run late)
  document.addEventListener("DOMContentLoaded", sanitizeChipSelects);
  window.addEventListener("load", sanitizeChipSelects);

  // Optional: small delay to catch very late renderers
  setTimeout(sanitizeChipSelects, 500);
})();
'@ | Set-Content -Path $jsPath -Encoding UTF8
Write-Host "[updated] forceChipNumbersOnly.js"

# 2) Ensure target HTML exists
if (-not (Test-Path $htmlPath)) {
  Write-Error "HTML file not found: $htmlPath"
  exit 1
}

# 3) Inject a script tag just before </body> (idempotent)
$html = Get-Content $htmlPath -Raw
$tag  = '<script src="./forceChipNumbersOnly.js"></script>'

if ($html -notlike "*$tag*") {
  if ($html -match '</body>') {
    $html = [regex]::Replace($html, '</body>', ("`n  $tag`n</body>"), 'IgnoreCase')
  } else {
    $html += "`n$tag`n"
  }
  $html | Set-Content -Path $htmlPath -Encoding UTF8
  Write-Host "[updated] injected sanitizer into $HtmlFile"
} else {
  Write-Host "[skip] sanitizer already present in $HtmlFile"
}

Write-Host "`nDone. Serve the site and reload the Blind Taste page; chip dropdowns will show numbers only."
