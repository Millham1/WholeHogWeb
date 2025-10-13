# wire-supabase.ps1  (PowerShell 5.1 compatible)
# Auto-detects your on-site scoring HTML file and wires landing + onsite to Supabase.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# === UPDATE ONLY IF YOUR PATH/KEYS CHANGE ===
$WebRoot    = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$ProjectUrl = "https://wiolulxxfyetvdpnfusq.supabase.co"
$AnonKey    = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc"

$LandingHtml = Join-Path $WebRoot 'landing.html'

function Read-Text($path){ if(-not (Test-Path $path)){ throw "File not found: $path" }; return [IO.File]::ReadAllText($path,[Text.Encoding]::UTF8) }
function Write-Text($path,$content){ $dir=Split-Path $path -Parent; if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }; [IO.File]::WriteAllText($path,$content,[Text.Encoding]::UTF8) }
function Backup-Once($path){ $bak="$path.bak"; if(-not (Test-Path $bak)){ Copy-Item $path $bak } }

function Ensure-Cdn($Path){
  $html = Read-Text $Path
  if($html -notmatch '@supabase/supabase-js@2'){
    $tag = "`r`n<!-- WHOLEHOG SUPABASE CDN START -->`r`n<script src=""https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2""></script>`r`n<!-- WHOLEHOG SUPABASE CDN END -->`r`n"
    $lower = $html.ToLowerInvariant()
    $pos = $lower.LastIndexOf('</body>')
    if($pos -ge 0){ $html = $html.Substring(0,$pos) + $tag + $html.Substring($pos) } else { $html = $html + $tag }
    Backup-Once $Path; Write-Text $Path $html
  }
}

function Patch-Block {
  param([string]$Path,[string]$Name,[string]$BlockHtml)
  $start = "<!-- WHOLEHOG $Name START -->"
  $end   = "<!-- WHOLEHOG $Name END -->"
  $html  = Read-Text $Path
  $lower = $html.ToLowerInvariant()
  $s = $lower.IndexOf($start.ToLowerInvariant())
  $e = $lower.IndexOf($end.ToLowerInvariant())
  if($s -ge 0 -and $e -gt $s){
    $pre = $html.Substring(0,$s); $post = $html.Substring($e + $end.Length)
    $html = $pre + $start + "`r`n" + $BlockHtml + "`r`n" + $end + $post
  } else {
    $injection = "`r`n$start`r`n$BlockHtml`r`n$end`r`n"
    $bp = $lower.LastIndexOf('</body>')
    if($bp -ge 0){ $html = $html.Substring(0,$bp) + $injection + $html.Substring($bp) } else { $html += $injection }
  }
  Backup-Once $Path; Write-Text $Path $html
}

function Find-OnsiteHtml($root,$landingPath){
  $candidates = @(
    'onsite.html','on-site.html','scoring.html','onsite.htm','on-site-scoring.html','on_site.html','index.html'
  )
  foreach($name in $candidates){
    $p = Join-Path $root $name
    if(Test-Path $p){ if($landingPath -and (Resolve-Path $p).Path -eq (Resolve-Path $landingPath).Path){ continue }; return $p }
  }
  # content-based search
  $best = $null; $bestScore = -1
  Get-ChildItem -Path $root -Filter *.html | ForEach-Object {
    if($landingPath -and (Resolve-Path $_.FullName).Path -eq (Resolve-Path $landingPath).Path){ return }
    try{
      $txt = Read-Text $_.FullName
      $score = 0
      if($txt -match 'On-?Site'){$score++}
      if($txt -match 'Scoring'){$score++}
      if($txt -match 'Suitable for Public'){$score++}
      if($txt -match 'Appearance'){$score++}
      if($txt -match 'Meat'){$score++}
      if($txt -match 'leaderboard'){$score++}
      if($score -gt $bestScore){ $bestScore=$score; $best=$_.FullName }
    } catch {}
  }
  if($best){ return $best }
  throw "Could not auto-detect your on-site scoring page. Put its filename here or rename it to onsite.html."
}

# ---- Blocks (no CSS/layout changes) ----
$InitBlock = "<script>(function(){if(!window.WHOLEHOG)window.WHOLEHOG={};if(!window.WHOLEHOG.sb){try{window.WHOLEHOG.sb=window.supabase.createClient('"+$ProjectUrl+"','"+$AnonKey+"');console.log('[WHOLEHOG] Supabase client ready.')}catch(e){console.error('[WHOLEHOG] Supabase init failed:',e)}}})();</script>"

$LandingBlock = @"
<script>
(function(){
  var SB=(window.WHOLEHOG&&window.WHOLEHOG.sb)?window.WHOLEHOG.sb:null; if(!SB){console.error('[WHOLEHOG] Supabase not initialized on landing.');return;}
  function pick(a){for(var i=0;i<a.length;i++){var el=document.getElementById(a[i]);if(el)return el;}return null;}
  var elTeamName=pick(['teamName','team-name','team_name','teamInput','teamNameInput']);
  var elSite    =pick(['site','site-number','site_number','siteInput','siteNo']);
  var elAddTeam =pick(['btnAddTeam','addTeam','saveTeam','team-save','btn-team-add']);
  var elTeamList=pick(['teamList','teams-list','teams','teamsList','teamsView']);
  var elJudgeName=pick(['judgeName','judge-name','judge_name','inputJudge','judgeNameInput']);
  var elAddJudge =pick(['btnAddJudge','addJudge','saveJudge','judge-save','btn-judge-add']);
  var elJudgeList=pick(['judgeList','judges-list','judges','judgesList','judgesView']);
  var elGoOnsite=pick(['btnGoOnsite','goOnsite','gotoOnsite','toOnsite','go-onsite']);
  function escapeHtml(s){return (s==null?'':String(s)).replace(/[&<>"]/g,function(c){return({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;'}[c]);});}
  function renderTeams(rows){ if(!elTeamList)return; var h=[]; for(var i=0;i<rows.length;i++){var t=rows[i]; h.push('<div style="display:flex;justify-content:space-between;padding:4px 6px;border-bottom:1px solid #eee;"><span>'+escapeHtml(t.name)+'</span><span style="opacity:.7">Site '+escapeHtml(t.site_number||'')+'</span></div>');} elTeamList.innerHTML=h.join(''); }
  function renderJudges(rows){ if(!elJudgeList)return; var h=[]; for(var i=0;i<rows.length;i++){var g=rows[i]; h.push('<div style="padding:4px 6px;border-bottom:1px solid #eee;">'+escapeHtml(g.name)+'</div>');} elJudgeList.innerHTML=h.join(''); }
  async function loadTeams(){ var r=await SB.from('teams').select('id,name,site_number').order('site_number',{ascending:true}); if(r.error){console.error(r.error);return;} renderTeams(r.data||[]); }
  async function loadJudges(){ var r=await SB.from('judges').select('id,name').order('name',{ascending:true}); if(r.error){console.error(r.error);return;} renderJudges(r.data||[]); }
  async function addTeam(){ var name=elTeamName?elTeamName.value.trim():''; var site=elSite?elSite.value.trim():''; if(!name||!site){alert('Enter Team Name and Site #');return;} var r=await SB.from('teams').insert([{name:name,site_number:site}]); if(r.error){alert('Add team failed: '+r.error.message);return;} if(elTeamName)elTeamName.value=''; if(elSite)elSite.value=''; loadTeams(); }
  async function addJudge(){ var name=elJudgeName?elJudgeName.value.trim():''; if(!name){alert('Enter Judge Name');return;} var r=await SB.from('judges').insert([{name:name}]); if(r.error){alert('Add judge failed: '+r.error.message);return;} if(elJudgeName)elJudgeName.value=''; loadJudges(); }
  if(elAddTeam) elAddTeam.addEventListener('click',addTeam);
  if(elAddJudge)elAddJudge.addEventListener('click',addJudge);
  if(elGoOnsite)elGoOnsite.addEventListener('click',function(){window.location.href='onsite.html';});
  loadTeams(); loadJudges(); window.addEventListener('focus',function(){loadTeams();loadJudges();});
})();
</script>
"@

$OnsiteBlock = @"
<script>
(function(){
  var SB=(window.WHOLEHOG&&window.WHOLEHOG.sb)?window.WHOLEHOG.sb:null; if(!SB){console.error('[WHOLEHOG] Supabase not initialized on onsite.');return;}
  function pick(a){for(var i=0;i<a.length;i++){var el=document.getElementById(a[i]);if(el)return el;}return null;}
  function checked(id){var el=document.getElementById(id);return !!(el&&el.checked);}
  var selTeam =pick(['selTeam','teamSelect','team-select']);
  var selJudge=pick(['selJudge','judgeSelect','judge-select']);
  var selSuit =pick(['suitable','suitableSelect','publicOk','suitableForPublic']);
  var btnSave =pick(['btnSave','saveEntry','save-entry']);
  var board   =pick(['leaderboard','board','lb']);
  var ids={appearance:['appearance','sc_appearance'],color:['color','sc_color'],skin:['skin','sc_skin'],moisture:['moisture','sc_moisture'],meat_sauce:['meatSauce','meat_sauce','sc_meat']};
  function getScore(list){for(var i=0;i<list.length;i++){var el=document.getElementById(list[i]);if(el){var v=parseInt(el.value,10);if(!isNaN(v))return v;}}return null;}
  async function loadTeams(){ var r=await SB.from('teams').select('id,name,site_number').order('site_number',{ascending:true}); if(r.error){console.error(r.error);return;} if(!selTeam)return; var cur=selTeam.value; selTeam.innerHTML='<option value=""">Select team...</option>'+(r.data||[]).map(function(t){return '<option value="'+t.id+'">'+t.name+' (Site '+(t.site_number||'')+')</option>';}).join(''); if(cur) selTeam.value=cur; }
  async function loadJudges(){ var r=await SB.from('judges').select('id,name').order('name',{ascending:true}); if(r.error){console.error(r.error);return;} if(!selJudge)return; var cur=selJudge.value; selJudge.innerHTML='<option value=""">Select judge...</option>'+(r.data||[]).map(function(j){return '<option value="'+j.id+'">'+j.name+'</option>';}).join(''); if(cur) selJudge.value=cur; }
  async function saveEntry(){
    if(!selTeam||!selJudge||!selSuit){alert('Missing form controls');return;}
    var payload={team_id:selTeam.value,judge_id:selJudge.value,suitable:(selSuit.value||''),appearance:getScore(ids.appearance),color:getScore(ids.color),skin:getScore(ids.skin),moisture:getScore(ids.moisture),meat_sauce:getScore(ids.meat_sauce),completeness:{siteClean:checked('cln'),knives:checked('knv'),sauce:checked('sau'),drinks:checked('drk'),thermometers:checked('thr')}};
    if(!payload.team_id||!payload.judge_id||!payload.suitable){alert('Select Team, Judge, and Suitable for Public Consumption.');return;}
    var r=await SB.from('entries').insert([payload]).select('id'); if(r.error){alert('Save failed: '+r.error.message);return;} refreshBoard();
  }
  function esc(s){return (s==null?'':String(s)).replace(/[&<>"]/g,function(c){return({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;'}[c]);});}
  async function refreshBoard(){
    if(!board) return;
    var r=await SB.from('v_leaderboard').select('team_name,site_number,total_points,tie_meat_sauce,tie_skin,tie_moisture')
      .order('total_points',{ascending:false}).order('tie_meat_sauce',{ascending:false}).order('tie_skin',{ascending:false}).order('tie_moisture',{ascending:false});
    if(r.error){console.error(r.error);return;}
    var rows=r.data||[]; var h=['<div style=""display:grid;grid-template-columns:2fr 1fr 1fr;gap:8px;font-weight:bold;padding:4px 0;border-bottom:1px solid #ddd;""><div>Team</div><div>Site</div><div>Total</div></div>'];
    for(var i=0;i<rows.length;i++){var x=rows[i]; h.push('<div style=""display:grid;grid-template-columns:2fr 1fr 1fr;gap:8px;padding:4px 0;border-bottom:1px solid #f0f0f0;""><div>'+esc(x.team_name)+'</div><div>'+esc(x.site_number||"")+'</div><div style=""font-weight:600;text-align:right"">'+(x.total_points||0)+'</div></div>');}
    board.innerHTML=h.join('');
  }
  if(btnSave) btnSave.addEventListener('click',saveEntry);
  loadTeams(); loadJudges(); refreshBoard();
  window.addEventListener('focus',function(){loadTeams();loadJudges();refreshBoard();});
  setInterval(refreshBoard,10000);
})();
</script>
"@

# ---- Do work ----
if(-not (Test-Path $LandingHtml)){ throw "landing.html not found at $LandingHtml" }
$OnsiteHtml = $null
try{
  $OnsiteHtml = Join-Path $WebRoot 'onsite.html'
  if(-not (Test-Path $OnsiteHtml)){ $OnsiteHtml = Find-OnsiteHtml -root $WebRoot -landingPath $LandingHtml }
} catch { throw $_ }

Write-Host ("Detected on-site page: {0}" -f $OnsiteHtml) -ForegroundColor Cyan

# Patch landing.html
Ensure-Cdn   -Path $LandingHtml
Patch-Block  -Path $LandingHtml -Name 'INIT'    -BlockHtml $InitBlock
Patch-Block  -Path $LandingHtml -Name 'LANDING' -BlockHtml $LandingBlock
Write-Host "Updated: landing.html" -ForegroundColor Green

# Patch onsite page
Ensure-Cdn   -Path $OnsiteHtml
Patch-Block  -Path $OnsiteHtml  -Name 'INIT'   -BlockHtml $InitBlock
Patch-Block  -Path $OnsiteHtml  -Name 'ONSITE' -BlockHtml $OnsiteBlock
Write-Host ("Updated: {0}" -f (Split-Path $OnsiteHtml -Leaf)) -ForegroundColor Green

Write-Host "Done. Open landing.html, add a Team & Judge, then open the on-site page and save a score." -ForegroundColor Yellow




