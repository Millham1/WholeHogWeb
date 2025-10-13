param(
  [Parameter(Mandatory=$true)]
  [string]$Path
)

if (-not (Test-Path -LiteralPath $Path)) {
  Write-Error "File not found: $Path"
  exit 1
}

# 1) Read and back up
$orig = Get-Content -LiteralPath $Path -Raw
$bak  = "$Path.bak_$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item -LiteralPath $Path -Destination $bak -Force
Write-Host "Backup created: $bak" -ForegroundColor Yellow

$updated = $orig
$changed = $false

# 2) Insert Email field after <input id="whTeamName" ... >
if ($updated -notmatch 'id=["'']whTeamEmail["'']') {
  $patternTeamNameInput = '(?is)(<input\b[^>]*\bid\s*=\s*["'']whTeamName["''][^>]*>)'
  if ($updated -match $patternTeamNameInput) {
    $emailField = @'
<!-- Team Email (optional) -->
<div style="margin-top:8px;">
  <label for="whTeamEmail" style="display:block;font-weight:600;margin-bottom:4px;">Email (optional)</label>
  <input id="whTeamEmail" type="email" inputmode="email"
         style="width:50%;padding:8px;border:1px solid #bbb;border-radius:8px;"
         placeholder="team@example.com" />
  <div id="whTeamEmailErr" style="display:none;color:#b91c1c;font-size:12px;margin-top:4px;">
    Please enter a valid email (e.g., name@host.com) or leave blank.
  </div>
</div>
'@

    $updated = [regex]::Replace($updated, $patternTeamNameInput, {
      param($m)
      $m.Groups[1].Value + "`r`n" + $emailField
    }, 1)
    $changed = $true
    Write-Host "✔ Inserted Email field after whTeamName input." -ForegroundColor Green
  } else {
    Write-Warning "Could not find <input id=""whTeamName""> to insert Email field after. Skipping field insertion."
  }
} else {
  Write-Host "ℹ️ Email field already present (id=""whTeamEmail"")." -ForegroundColor Yellow
}

# 3) Inject validator/hook script before </body>
if ($updated -notmatch 'id=["'']wh-team-email-hook["'']') {
  $validatorJs = @'
<script id="wh-team-email-hook">
(function(){
  function $(id){ return document.getElementById(id); }
  function isValidEmail(s){
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
  }
  function safeParseMap(k){
    try { var v = localStorage.getItem(k); return v ? JSON.parse(v) : {}; } catch(e){ return {}; }
  }
  function safeSaveMap(k, obj){
    try { localStorage.setItem(k, JSON.stringify(obj)); } catch(e){}
  }

  document.addEventListener('DOMContentLoaded', function(){
    var btn   = $('whBtnAddTeam');
    var name  = $('whTeamName');
    var email = $('whTeamEmail');
    var err   = $('whTeamEmailErr');

    if (!btn || !name) return;

    // Validate & persist email BEFORE other click handlers run
    btn.addEventListener('click', function(ev){
      if (!email) return;

      var teamName = (name.value || '').trim();
      var mail     = (email.value || '').trim();

      // If user typed an email, validate
      if (mail.length){
        if (!isValidEmail(mail)){
          if (err) err.style.display = 'block';
          ev.preventDefault();
          ev.stopImmediatePropagation();
          return;
        }
        // valid → save mapping
        var map = safeParseMap('teamEmails');
        if (teamName) { map[teamName] = mail; }
        safeSaveMap('teamEmails', map);
      } else {
        if (err) err.style.display = 'none';
      }

      // clear email box after successful add (let existing handler proceed)
      setTimeout(function(){
        try { if (email) email.value = ''; if (err) err.style.display = 'none'; } catch(_){}
      }, 0);
    }, true); // capture: true → run before other handlers
  });
})();
</script>
'@

  if ($updated -match '(?is)</body\s*>\s*</html\s*>') {
    $updated = [regex]::Replace($updated, '(?is)</body\s*>\s*</html\s*>', ($validatorJs + "`r`n</body></html>"), 1)
    $changed = $true
    Write-Host "✔ Injected email validation/save hook script." -ForegroundColor Green
  } else {
    Write-Warning "Could not find </body></html> to inject the validation script. Skipping script insertion."
  }
} else {
  Write-Host "ℹ️ Email validator script already present (id=""wh-team-email-hook"")." -ForegroundColor Yellow
}

# 4) Write back if changed
if ($changed) {
  Set-Content -LiteralPath $Path -Value $updated -Encoding UTF8
  Write-Host "✅ landing.html updated." -ForegroundColor Green
} else {
  Write-Host "ℹ️ No changes applied (already up to date)." -ForegroundColor Yellow
}
