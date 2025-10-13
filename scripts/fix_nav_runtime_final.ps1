# fix_nav_runtime_final.ps1
# Purpose:
#  - Remove any prior injected WHOLEHOG blocks/scripts
#  - Inject a tiny <style> and <script> that, on page load:
#     * finds your existing "Go to On-Site" and "Go to Blind Taste" buttons
#     * removes ALL duplicate "Go to Leaderboard" links
#     * creates ONE "Go to Leaderboard" that copies the same classes as Blind Taste
#     * groups all three into a single centered horizontal row near where they already were

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# Read current file
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

# Remove prior injected containers/scripts to avoid conflicts
$html = [regex]::Replace($html,'(?is)<div[^>]*id\s*=\s*"(?:wholehog-nav|wholehog-leaderboard-btn)"[^>]*>[\s\S]*?</div>','')
$html = [regex]::Replace($html,'(?is)<!--\s*WHOLEHOG:.*?-->(?:(?!<!--\s*/WHOLEHOG\s*-->).)*?<!--\s*/WHOLEHOG\s*-->','')
$html = [regex]::Replace($html,'(?is)<script[^>]*id\s*=\s*"wholehog-nav-(?:fix|builder)"[^>]*>[\s\S]*?</script>','')
$html = [regex]::Replace($html,'(?is)<style[^>]*id\s*=\s*"wholehog-nav-style"[^>]*>[\s\S]*?</style>','')

# Style: centers the row and ensures anchors sit side-by-side without changing your classes
$styleBlock = @'
<style id="wholehog-nav-style">
  #wholehog-nav{
    width:100%;
    margin:12px auto;
    display:flex;
    justify-content:center;
    align-items:center;
    gap:12px;
    flex-wrap:wrap;
    text-align:center;
  }
  #wholehog-nav a{
    display:inline-flex;
    align-items:center;
    white-space:nowrap;
    float:none !important;
    width:auto !important;
  }
</style>
'@

# Script: builds the centered row from your existing buttons, de-dupes leaderboard
$scriptBlock = @'
<script id="wholehog-nav-builder">
(function(){
  try{
    function norm(t){ return (t||"").replace(/\s+/g," ").trim().toLowerCase(); }
    function findByText(re){
      return Array.from(document.querySelectorAll("a")).find(a=> re.test(norm(a.textContent)));
    }
    function findByHref(parts){
      return Array.from(document.querySelectorAll("a[href]")).find(a=>{
        var h=(a.getAttribute("href")||"").toLowerCase();
        return parts.every(p=>h.indexOf(p)!==-1);
      });
    }
    // Find anchors
    var on = findByText(/go\s*to\s*on\s*-?\s*site/) || findByHref(["on","site"]);
    var bt = findByText(/go\s*to\s*blind\s*-?\s*taste/) || findByHref(["blind","taste"]);
    // Find/create leaderboard
    var lbList = Array.from(document.querySelectorAll("a")).filter(a =>
      /go\s*to\s*leader\s*-?\s*board/i.test(a.textContent) ||
      ((a.getAttribute("href")||"").toLowerCase().indexOf("leader") !== -1)
    );
    var lb = lbList[0];
    if(!lb){
      if(!bt){ return; } // need BT to copy styling if creating fresh
      lb = document.createElement("a");
      lb.href = "./leaderboard.html";
      lb.textContent = "Go to Leaderboard";
      var cls = bt.getAttribute("class") || (on && on.getAttribute("class")) || "";
      if(cls) lb.setAttribute("class", cls);
    }
    // Remove duplicates
    lbList.forEach(function(a){ if(a!==lb) a.remove(); });

    // Find lowest common ancestor of ON and BT (fall back to BT's parent)
    function ancestors(n){ var arr=[]; while(n){ arr.push(n); n=n.parentElement; } return arr; }
    var parent = document.body, anchorForPos = bt || on || lb;
    if (on && bt){
      var a1=ancestors(on), a2=ancestors(bt);
      parent = a1.find(x=>a2.indexOf(x)>=0) || (bt.parentElement||document.body);
    } else if (bt && bt.parentElement){ parent = bt.parentElement; }

    // Create or clear row, and place it just before the earliest of ON/BT within that parent
    var row = document.getElementById("wholehog-nav");
    if(!row){
      row = document.createElement("div");
      row.id = "wholehog-nav";
      var beforeNode=null;
      if(on && on.parentElement===parent && bt && bt.parentElement===parent){
        beforeNode = (on.compareDocumentPosition(bt)&Node.DOCUMENT_POSITION_FOLLOWING) ? on : bt;
      } else if(bt && parent.contains(bt)){ beforeNode = bt; }
      if(beforeNode) parent.insertBefore(row, beforeNode);
      else parent.insertBefore(row, parent.firstChild);
    } else {
      row.innerHTML="";
    }

    // helper to normalize layout without changing your classes
    function normalize(a){
      if(!a) return;
      a.style.display="inline-flex";
      a.style.alignItems="center";
      a.style.whiteSpace="nowrap";
      a.style.float="none";
      a.style.width="auto";
    }
    normalize(on); normalize(bt); normalize(lb);

    // Move in order: On-Site, Blind Taste, Leaderboard
    function move(a){ if(a && a.parentElement!==row){ row.appendChild(a); } }
    if(on) move(on);
    if(bt) move(bt);
    move(lb);
  }catch(e){ console && console.error && console.error("wholehog-nav-builder error:", e); }
})();
</script>
'@

# Inject style before </head> (or prepend to file)
if ($html -match '(?is)</head>') {
  $html = [regex]::Replace($html,'(?is)</head>',$styleBlock + "`r`n</head>",1)
} else {
  $html = $styleBlock + "`r`n" + $html
}

# Inject script before </body> (or append)
if ($html -match '(?is)</body>') {
  $html = [regex]::Replace($html,'(?is)</body>',$scriptBlock + "`r`n</body>",1)
} else {
  $html = $html + "`r`n" + $scriptBlock
}

# Backup + write
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html

Write-Host "✅ Injected centered-row runtime fix. Backup created: $([IO.Path]::GetFileName($bak)). Now hard-refresh landing.html (Ctrl+F5)." -ForegroundColor Green
