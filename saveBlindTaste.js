import { supabase } from "./supabaseClient.js";
const \$ = (s)=>document.querySelector(s);

function scoreInputs(){ return Array.from(document.querySelectorAll("input[data-score], input.score-field")); }
function computeTotal(){
  let t=0; for (const f of scoreInputs()){ const n=Number((f.value??"").trim()); if(!Number.isNaN(n)) t+=n; }
  const total=\#score-total; if(total) total.value=String(t); return t;
}
async function duplicateExists(judgeId, chipNum){
  const {count,error}=await supabase.from("blind_taste").select("id",{count:"exact",head:true})
    .eq("judge_id", judgeId).eq("chip_number", chipNum);
  if(error){ console.error("dup check",error); alert("Warning: duplicate check failed."); return true; }
  return (count??0)>0;
}
function clearForm(){ const f=\#blind-taste-form; if(f) f.reset(); computeTotal(); }

async function saveBlindTaste(){
  const judgeId = (\#judge-select?.value||"").trim();
  const chipRaw = (\#chip-select?.value||"").trim();
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

  const btn=\#save-blind-taste; if(btn) btn.disabled=true;
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
