(function(){
  "use strict";

  // --- Data helpers ---
  const getArr = k => { try { const v = localStorage.getItem(k); return v ? JSON.parse(v) : []; } catch { return []; } };
  const getMap = k => { try { const v = localStorage.getItem(k); return v ? JSON.parse(v) : {}; } catch { return {}; } };
  const norm = s => (s == null ? "" : String(s)).trim();
  const toInt = v => { const n = Number(v); return Number.isFinite(n) ? Math.trunc(n) : 0; };
  const csvField = x => { const s = (x == null ? "" : String(x)); return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };
  const pad2 = n => String(n).padStart(2, "0");

  // --- Category aliases ---
  const CAT = {
    meatSauce: ["meatSauce", "meat_sauce", "meat and sauce", "meat&sauce", "taste", "flavor"],
    skin: ["skin", "crackling"],
    moisture: ["moisture", "juiciness"],
    appearance: ["appearance", "visual", "presentation"],
    tenderness: ["tenderness", "texture"]
  };

  // --- Pick score by aliases ---
  function pickInt(scores, names){
    if (!scores || typeof scores!=="object") return 0;
    for (const name of names){
      if (scores[name] != null) return toInt(scores[name]);
      const want = name.toLowerCase().replace(/[ _&]/g,'');
      for (const k in scores){
        if (k && k.toLowerCase().replace(/[ _&]/g,'') === want) return toInt(scores[k]);
      }
    }
    return 0;
  }

  // --- Load and aggregate all localStorage data ---
  function loadData(){
    const teams = getArr('wh_Teams').map(t=>norm(t.name));
    const judges = getArr('wh_Judges').map(j=>norm(j.name));
    const onsite = getArr('onsiteScores');
    const blind = getArr('blindScores');
    const sauce = getArr('sauceScores');
    const divMap = getMap('landingTeamDivisions');
    const emailM = getMap('teamEmailMap');
    const onsiteTJ = {}, blindTJ = {}, sauceTJ = {}, teamTotals = { onsite:{}, blind:{}, sauce:{}, all:{} };

    // On-site aggregation
    onsite.forEach(r=>{
      const t = norm(r.team);
      const j = norm(r.judge);
      if (!t || !j) return;
      const sc = r.scores || {};
      const ms = pickInt(sc,CAT.meatSauce), sk = pickInt(sc,CAT.skin), mo = pickInt(sc,CAT.moisture),
            ap = pickInt(sc,CAT.appearance), te = pickInt(sc,CAT.tenderness), add = ms+sk+mo+ap+te;
      onsiteTJ[t] ||= {}; onsiteTJ[t][j] = { ms, sk, mo, ap, te, total:add };
      teamTotals.onsite[t] = (teamTotals.onsite[t]||0) + add;
      teamTotals.all[t] = (teamTotals.all[t]||0) + add;
    });

    // Blind aggregation
    blind.forEach(r=>{
      const t = norm(r.team), j = norm(r.judge);
      if (!t||!j) return;
      blindTJ[t] ||= {}; blindTJ[t][j] = toInt(r.score);
      teamTotals.blind[t] = (teamTotals.blind[t]||0) + toInt(r.score);
      teamTotals.all[t] = (teamTotals.all[t]||0) + toInt(r.score);
    });

    // Sauce aggregation
    sauce.forEach(r=>{
      const t = norm(r.team), j = norm(r.judge);
      if (!t||!j) return;
      sauceTJ[t] ||= {}; sauceTJ[t][j] = toInt(r.score);
      teamTotals.sauce[t] = (teamTotals.sauce[t]||0) + toInt(r.score);
      teamTotals.all[t] = (teamTotals.all[t]||0) + toInt(r.score);
    });

    return { teams, judges, onsite, blind, sauce, onsiteTJ, blindTJ, sauceTJ, teamTotals, divMap, emailM };
  }

  // --- Build grouped CSV report ---
  function buildGroupedReportCSV(){
    const D = loadData();
    if (!D.teams.length){ alert("No teams found in localStorage."); return; }

    let rows = [];
    rows.push(["Team","Division","Email","Judge","Meat & Sauce","Skin","Moisture","Appearance","Tenderness","On-site Total","Blind","Sauce","Judge Total"]);

    for (const team of D.teams){
      const division = D.divMap[team] || "";
      const email = D.emailM[team] || "";
      const jset = new Set();
      if (D.onsiteTJ[team]) Object.keys(D.onsiteTJ[team]).forEach(j=>jset.add(j));
      if (D.blindTJ [team]) Object.keys(D.blindTJ [team]).forEach(j=>jset.add(j));
      if (D.sauceTJ [team]) Object.keys(D.sauceTJ [team]).forEach(j=>jset.add(j));
      let teamJudges = Array.from(jset);

      for (const judge of teamJudges){
        const os = (D.onsiteTJ[team] && D.onsiteTJ[team][judge]) || {};
        const blind = (D.blindTJ[team] && D.blindTJ[team][judge]) || 0;
        const sauce = (D.sauceTJ[team] && D.sauceTJ[team][judge]) || 0;
        const osTotal = os.total || 0;
        const judgeTotal = osTotal + blind + sauce;
        rows.push([
          team, division, email, judge,
          os.ms||0, os.sk||0, os.mo||0, os.ap||0, os.te||0, osTotal,
          blind, sauce, judgeTotal
        ]);
      }
    }

    // CSV output
    const csv = rows.map(row=>row.map(csvField).join(",")).join("\r\n");
    const ts = new Date();
    const name = `wh-report_grouped_${ts.getFullYear()}${pad2(ts.getMonth()+1)}${pad2(ts.getDate())}-${pad2(ts.getHours())}${pad2(ts.getMinutes())}${pad2(ts.getSeconds())}.csv`;
    const blob = new Blob([csv],{type:"text/csv;charset=utf-8;"});
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = name;
    document.body.appendChild(a);
    a.click();
    setTimeout(()=>{ URL.revokeObjectURL(a.href); a.remove(); }, 100);
  }

  // --- Hotkey support (Ctrl+Alt+R) ---
  window.addEventListener("keydown", function(e){
    if (e.ctrlKey && e.altKey && e.key === "r"){
      e.preventDefault();
      buildGroupedReportCSV();
    }
  });

  // --- Wire export button(s) ---
  function bind(){
    const btn=document.getElementById("wh-build-report-btn");
    if (btn && !btn._whBound) {
      btn.addEventListener("click", buildGroupedReportCSV);
      btn._whBound = true;
    }
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", bind, { once:true });
  else bind();

  // Export builder for inline or external calls
  window.buildGroupedReportCSV = buildGroupedReportCSV;
})();
