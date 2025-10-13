;(() => {
  // Minimal Supabase REST helper (no external libs). Keeps your UI unchanged.
  const SB_URL = 'https://wiolulxxfyetvdpnfusq.supabase.co';
  const SB_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc';

  async function sbFetch(path, opts) {
    opts = opts || {};
    const hdrs = opts.headers || {};
    // PostgREST headers
    hdrs['apikey'] = SB_KEY;
    hdrs['Authorization'] = 'Bearer ' + SB_KEY;
    if (!hdrs['Content-Type'] && (opts.method || '').toUpperCase() !== 'GET') {
      hdrs['Content-Type'] = 'application/json';
    }
    // return row(s) when inserting/updating
    if (!hdrs['Prefer']) hdrs['Prefer'] = 'return=representation';

    opts.headers = hdrs;
    const res = await fetch(SB_URL + '/rest/v1' + path, opts);
    if (!res.ok) {
      const txt = await res.text().catch(() => '');
      throw new Error('Supabase REST ' + res.status + ' ' + res.statusText + (txt ? (' - ' + txt) : ''));
    }
    // Some DELETE/UPSERT may return empty
    const ct = res.headers.get('content-type') || '';
    if (ct.indexOf('application/json') >= 0) return res.json();
    return null;
  }

  // PUBLIC API
  const sb = {
    // Tables expected (snake_case typical for Postgres/Supabase):
    // teams(id uuid/text, name text, site_number text)
    // judges(id uuid/text, name text)
    // entries(id uuid/text, ts bigint, team_id, team_name, site_number, judge_id, judge_name,
    //         suitable text, appearance int, color int, skin int, moisture int, meat_sauce int,
    //         completeness_points int, completeness_json json/text, total int)
    listTeams:  () => sbFetch('/teams?select=*&order=name.asc'),
    addTeam:    (name, site_number) => sbFetch('/teams',  { method: 'POST', body: JSON.stringify([{ name, site_number }]) }),
    listJudges: () => sbFetch('/judges?select=*&order=name.asc'),
    addJudge:   (name) => sbFetch('/judges', { method: 'POST', body: JSON.stringify([{ name }]) }),
    listEntries:() => sbFetch('/entries?select=*'),
    saveEntry:  (entry) => {
      // upsert by id if provided; otherwise insert new
      const hasId = entry && entry.id ? true : false;
      const qs = hasId ? '?on_conflict=id' : '';
      return sbFetch('/entries' + qs, { method: 'POST', body: JSON.stringify([entry]) });
    }
  };
  window.sb = sb;

  // === Optional "best-effort" autowire (does nothing if IDs not found) ===
  async function autoWire() {
    try {
      // Try to populate team select
      var teamSel = document.querySelector('[data-team-select], #teamSelect, #teamSel, select[name="team"], #team');
      if (teamSel) {
        const teams = await sb.listTeams();
        teamSel.innerHTML = '<option value="">Select...</option>' + teams.map(t =>
          '<option value="' + (t.id || t.name) + '" data-site="' + (t.site_number || '') + '">' +
            (t.name || 'Team') + (t.site_number ? (' (Site ' + t.site_number + ')') : '') +
          '</option>').join('');
      }

      // Populate judge select
      var judgeSel = document.querySelector('[data-judge-select], #judgeSelect, #judgeSel, select[name="judge"], #judge');
      if (judgeSel) {
        const judges = await sb.listJudges();
        judgeSel.innerHTML = '<option value="">Select...</option>' + judges.map(j =>
          '<option value="' + (j.id || j.name) + '">' + (j.name || 'Judge') + '</option>').join('');
      }

      // Optional: lightweight leaderboard render if a container exists.
      var lb = document.querySelector('#leaderboard, [data-leaderboard]');
      if (lb) {
        const entries = await sb.listEntries();
        // Client-side group/sum — adapts to snake_case or camelCase
        const byTeam = {};
        entries.forEach(e => {
          var team = e.team_name || e.teamName || 'Unknown';
          var total = (
            (e.total != null ? e.total : 0) ||
            ((e.appearance||0) + (e.color||0) + (e.skin||0) + (e.moisture||0) + (e.meat_sauce||e.meatSauce||0) + (e.completeness_points||e.completenessPoints||0))
          );
          byTeam[team] = (byTeam[team] || 0) + total;
        });
        var rows = Object.keys(byTeam).map(k => ({ team:k, total: byTeam[k] }))
                                      .sort((a,b)=>b.total - a.total);
        lb.innerHTML = rows.map((r,i)=>(
          '<div class="lb-row"><span class="rank">'+(i+1)+'.</span><span class="team">'+r.team+
          '</span><b class="pts">'+r.total+'</b></div>'
        )).join('');
      }
    } catch (err) {
      console.error('whAutoWire error:', err);
    }
  }

  window.whAutoWire = autoWire;
  document.addEventListener('DOMContentLoaded', function(){ try{ autoWire(); }catch(e){} });
})();