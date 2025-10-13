# landing_runtime_nav_fix.ps1
# Injects a runtime DOM script into landing.html that:
# - deduplicates "Go to Leaderboard"
# - builds a single centered row: On-Site, Blind Taste, Leaderboard (in that order)
# - places the row just under the banner (after <header>, else right after <body>)
# - preserves your existing button classes/styles (Leaderboard copies Blind Taste's class)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# Read
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

# Remove any previous WHOLEHOG containers / scripts we may have added
$html = [regex]::Replace($html,'(?is)<div[^>]*id\s*=\s*"(?:wholehog-nav|wholehog-leaderboard-btn)"[^>]*>[\s\S]*?</div>','')
$html = [regex]::Replace($html,'(?is)<!--\s*WHOLEHOG:.*?-->(?:(?!<!--\s*/WHOLEHOG\s*-->).)*?<!--\s*/WHOLEHOG\s*-->','')
$html = [regex]::Replace($html,'(?is)<script[^>]*id\s*=\s*"wholehog-nav-fix"[^>]*>[\s\S]*?</script>','')

# Runtime DOM fixer (robust: text-based match with href fallbacks; dedupes; centers row)
$runtime = @'
<script id="wholehog-nav-fix">
(function () {
  try {
    function norm(txt){ return (txt||"").replace(/\s+/g," ").trim(); }
    function hasText(a, re){ return re.test(norm(a.textContent||"")); }
    function hrefContains(a, words){
      var h = (a.getAttribute("href")||"").toLowerCase();
      return words.every(function(w){ return h.indexOf(w) !== -1; });
    }

    var links = Array.prototype.slice.call(document.querySelectorAll("a"));

    // Find anchors by visible text first, then by href patterns
    var on = links.find(function(a){ return hasText(a, /go\s*to\s*on\s*-?\s*site/i); }) ||
             links.find(function(a){ return hrefContains(a, ["on","site"]); });

    var bt = links.find(function(a){ return hasText(a, /go\s*to\s*blind\s*-?\s*taste/i); }) ||
             links.find(function(a){ return hrefContains(a, ["blind","taste"]); });

    // Collect ALL leaderboard anchors so we can dedupe
    var lbAll = links.filter(function(a){
      return hasText(a, /go\s*to\s*leader\s*-?\s*board/i) || hrefContains(a, ["leader"]);
    });

    // If none exists, create one by cloning Blind Taste’s class for visual match
    var lb = lbAll[0];
    if (!lb) {
      if (!bt) return; // need at least Blind Taste to infer styling/position
      lb = document.createElement("a");
      lb.setAttribute("href", "./leaderboard.html");
      lb.textContent = "Go to Leaderboard";
      var cls = bt.getAttribute("class") || (on ? on.getAttribute("class") : "") || "btn";
      lb.setAttribute("class", cls);
    }

    // Remove ALL leaderboard duplicates except the one we'll use
    lbAll.forEach(function(a){ if (a !== lb) a.remove(); });

    // Create (or reuse) a centered row right under the banner
    var row = document.getElementById("wholehog-nav");
    if (!row) {
      row = document.createElement("div");
      row.id = "wholehog-nav";
      // Centering container
      row.style.width = "100%";
      row.style.margin = "12px auto";
      row.style.display = "flex";
      row.style.justifyContent = "center";
      row.style.alignItems = "center";
      row.style.gap = "12px";
      row.style.flexWrap = "wrap";
      row.style.textAlign = "center";

      var header = document.querySelector("header");
      if (header && header.parentNode) {
        header.parentNode.insertBefore(row, header.nextSibling);
      } else if (document.body.firstChild) {
        document.body.insertBefore(row, document.body.firstChild.nextSibling);
      } else {
        document.body.appendChild(row);
      }
    } else {
      // If it existed, clear it to rebuild cleanly
      row.innerHTML = "";
    }

    // Helper to normalize each button so site CSS can't stack them full-width
    function normalizeButton(a){
      if (!a) return;
      a.style.display = "inline-flex";
      a.style.alignItems = "center";
      a.style.width = "auto";
      a.style.whiteSpace = "nowrap";
      a.style.float = "none";
    }

    // Move the three buttons into the row, in order: On-Site, Blind Taste, Leaderboard
    function move(a){
      if (a && a.parentNode !== row) {
        // detach from current location
        if (a.parentNode) a.parentNode.removeChild(a);
        row.appendChild(a);
      }
    }

    normalizeButton(on);
    normalizeButton(bt);
    normalizeButton(lb);

    move(on);
    move(bt);
    move(lb);
  } catch (e) {
    console && console.error && console.error("wholehog-nav-fix error:", e);
  }
})();
</script>
'@

# Insert the runtime block right before </body> (or append if no </body>)
if ($html -match '(?is)</body>') {
  $html = [regex]::Replace($html,'(?is)</body>',$runtime + "`r`n</body>",1)
} else {
  $html = $html + "`r`n" + $runtime
}

# Backup & write
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html

Write-Host "Injected runtime nav fix into landing.html (backup: $([IO.Path]::GetFileName($bak))). Now hard-refresh the page (Ctrl+F5)." -ForegroundColor Green
