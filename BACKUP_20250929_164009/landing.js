(function(){
  // Simple localStorage model
  const KEY_TEAMS  = "wholehog:teams";
  const KEY_JUDGES = "wholehog:judges";

  /** @type {{name:string,site:string}[]} */
  let teams  = [];
  /** @type {{name:string}[]} */
  let judges = [];

  function load(){
    try { teams  = JSON.parse(localStorage.getItem(KEY_TEAMS)  || "[]"); } catch{ teams=[]; }
    try { judges = JSON.parse(localStorage.getItem(KEY_JUDGES) || "[]"); } catch{ judges=[]; }
  }
  function save(){
    localStorage.setItem(KEY_TEAMS,  JSON.stringify(teams));
    localStorage.setItem(KEY_JUDGES, JSON.stringify(judges));
  }

  function renderTeams(){
    const host = document.getElementById("teamList");
    host.innerHTML = "";
    teams
      .slice()
      .sort((a,b)=>a.name.localeCompare(b.name))
      .forEach((t,i)=>{
        const row = document.createElement("div");
        row.className = "pill";
        const left = document.createElement("div");
        left.innerHTML = `<b>${escapeHtml(t.name)}</b> <small>• Site ${escapeHtml(t.site)}</small>`;
        const del = document.createElement("button");
        del.className = "kill";
        del.textContent = "Remove";
        del.onclick = () => {
          teams.splice(i,1); save(); renderTeams();
        };
        row.appendChild(left); row.appendChild(del);
        host.appendChild(row);
      });
  }

  function renderJudges(){
    const host = document.getElementById("judgeList");
    host.innerHTML = "";
    judges
      .slice()
      .sort((a,b)=>a.name.localeCompare(b.name))
      .forEach((j,i)=>{
        const row = document.createElement("div");
        row.className = "pill";
        const left = document.createElement("div");
        left.innerHTML = `<b>${escapeHtml(j.name)}</b>`;
        const del = document.createElement("button");
        del.className = "kill";
        del.textContent = "Remove";
        del.onclick = () => {
          judges.splice(i,1); save(); renderJudges();
        };
        row.appendChild(left); row.appendChild(del);
        host.appendChild(row);
      });
  }

  function addTeam(){
    const name = (document.getElementById("teamName").value || "").trim();
    const site = (document.getElementById("teamSite").value || "").trim();
    if(!name || !site) return;
    if(teams.some(t=>t.name.toLowerCase()===name.toLowerCase() || t.site===site)) return;
    teams.push({name, site}); save(); renderTeams();
    document.getElementById("teamName").value = "";
    document.getElementById("teamSite").value = "";
  }

  function addJudge(){
    const name = (document.getElementById("judgeName").value || "").trim();
    if(!name) return;
    if(judges.some(j=>j.name.toLowerCase()===name.toLowerCase())) return;
    judges.push({name}); save(); renderJudges();
    document.getElementById("judgeName").value = "";
  }

  function escapeHtml(s){
    return s.replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  }

  // wire up
  load(); renderTeams(); renderJudges();
  document.getElementById("addTeam").addEventListener("click", function(e){ e.preventDefault(); addTeam(); });
  document.getElementById("addJudge").addEventListener("click", function(e){ e.preventDefault(); addJudge(); });
})();