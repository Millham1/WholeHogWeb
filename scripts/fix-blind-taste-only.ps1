param(
  [string]$Root = ".",
  [string]$HtmlFile = "blind-taste.html",
  [string]$SupabaseUrl = "https://YOUR-PROJECT.supabase.co",
  [string]$SupabaseAnonKey = "YOUR-ANON-KEY"
)

$Root     = Resolve-Path $Root
$htmlPath = Join-Path $Root $HtmlFile
$clientJs = Join-Path $Root "supabaseClient.js"
$saveJs   = Join-Path $Root "saveBlindTaste.js"
$chipFix  = Join-Path $Root "forceChipNumbersOnly.js"

if (-not (Test-Path $htmlPath)) { Write-Error "Not found: $htmlPath"; exit 1 }

# 1) Supabase client (double-quoted here-string to interpolate vars)
$clientContent = @"
import { createClient } from '@supabase/supabase-js';
export const supabase = createClient("$SupabaseUrl", "$SupabaseAnonKey");
"@
$clientContent | Set-Content -Path $clientJs -Encoding UTF8

# 2) Save logic (NO backticks; pure string concatenation)
$saveContent = @"
import { supabase } from "./supabaseClient.js";
const \$ = (s)=>document.querySelector(s);

function scoreInputs(){ return Array.from(document.querySelectorAll("input[data-score], input.score-field")); }
function computeTotal(){
  let t=0; for (const f of scoreInputs()){ const n=Number((f.value??"").trim()); if(!Number.isNaN(n)) t+=n; }
  const total=\$("#score-total"); if(total) total.value=String(t); return t;
}
async function duplicateExists(judgeId, chipNum){
  const {count,error}=await supabase.from("blind_taste").select("id",{count:"exact",head:true})
    .eq("judge_id", judgeId).eq("chip_number", chipNum);
  if(error){ console.error("dup check",error); alert("Warning: duplicate check failed."); return true; }
  return (count??0)>0;
}
function clearForm(){ const f=\$("#blind-taste-form"); if(f) f.reset(); computeTotal(); }

async function saveBlindTaste(){
  const judgeId = (\$("#judge-select")?.value||"").trim();
  const chipRaw = (\$("#chip-select")?.value||"").trim();
  const chipNum = Number(chipRaw);
  if(!judgeId){ alert("Please select a Judge."); return; }
  if(!chipRaw || Number.isNaN(chipNum) || chipNum<=0){ alert("Please select a valid Chip #."); return; }

  const total = computeTotal();
  const row = { judge_id: judgeId, chip_number: chipNum, score_total: total };
  for (const f of scoreInputs()){
    const nm=(f.name||f.id||"").toLowerCase(); const v=Number((f.value??"").trim());
    if(Number.isNaN(v)) continue;
    if(nm.includes("appear")) row.score_appearance=v;
    else if(nm.includes("tender")) row.score_tenderness=v;
    else if(nm.includes("flavor")||nm.includes("taste")) row.score_flavor=v;
  }

  if(await duplicateExists(judgeId, chipNum)){ alert("This Judge + Chip # is already saved."); return; }

  const btn=\$("#save-blind-taste"); if(btn) btn.disabled=true;
  const {data,error}=await supabase.from("blind_taste").insert([row]).select().single();
  if(btn) btn.disabled=false;

  if(error){
    console.error("insert",error);
    if (error.code==="23505") { alert("Duplicate Judge + Chip #."); }
    else { alert(error.message || "Save failed."); }
    return;
  }

  alert("Saved! Chip #" + data.chip_number + ", Judge " + data.judge_id + ".");
  clearForm();
}

document.addEventListener("DOMContentLoaded",()=>{
  scoreInputs().forEach(i=>{
    i.addEventListener("input", computeTotal, {passive:true});
    i.addEventListener("change", computeTotal, {passive:true});
  });
  const btn=document.getElementById("save-blind-taste");
  if(btn) btn.addEventListener("click",(e)=>{ e.preventDefault(); saveBlindTaste(); });
  computeTotal();
});
"@
$saveContent | Set-Content -Path $saveJs -Encoding UTF8

# 3) Chip label sanitizer (forces numbers-only display)
$chipFixContent = @"
(function(){
  function fix(){
    const sels=[...document.querySelectorAll("select")].filter(el=>{
      const id=(el.id||"").toLowerCase(), nm=(el.name||"").toLowerCase();
      return id.includes("chip")||nm.includes("chip");
    });
    for(const sel of sels){
      for(const opt of sel.options){
        const txt=String(opt.textContent||opt.label||"").trim();
        const m=txt.match(/^(\d{1,6})\b/); if(m){ const n=m[1]; opt.textContent=n; opt.label=n; opt.value=n; }
      }
    }
  }
  document.addEventListener("DOMContentLoaded", fix);
  window.addEventListener("load", fix);
  setTimeout(fix, 500);
})();
"@
$chipFixContent | Set-Content -Path $chipFix -Encoding UTF8

# 4) Inject the three scripts at end of blind-taste page (idempotent)
$html = Get-Content $htmlPath -Raw
$tagClient = '<script type="module" src="./' + (Split-Path $clientJs -Leaf) + '"></script>'
$tagSave   = '<script type="module" src="./' + (Split-Path $saveJs  -Leaf) + '"></script>'
$tagChip   = '<script src="./' + (Split-Path $chipFix -Leaf) + '"></script>'

$changed = $false
if ($html -notlike "*$tagClient*") { $html = ($html -match '</body>') ? ([regex]::Replace($html,'</body>',"`n  $tagClient`n</body>",'IgnoreCase')) : ($html + "`n$tagClient`n"); $changed=$true }
if ($html -notlike "*$tagSave*")   { $html = ($html -match '</body>') ? ([regex]::Replace($html,'</body>',"`n  $tagSave`n</body>",'IgnoreCase'))   : ($html + "`n$tagSave`n");   $changed=$true }
if ($html -notlike "*$tagChip*")   { $html = ($html -match '</body>') ? ([regex]::Replace($html,'</body>',"`n  $tagChip`n</body>",'IgnoreCase'))   : ($html + "`n$tagChip`n");   $changed=$true }
if ($changed) { $html | Set-Content -Path $htmlPath -Encoding UTF8 }

Write-Host "Updated only: $HtmlFile (scripts appended at end)."

