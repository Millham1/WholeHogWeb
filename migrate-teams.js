(function(){
  try {
    if (!window.WHOLEHOG) window.WHOLEHOG = {};
    var base = (WHOLEHOG.sbProjectUrl || '').replace(/\/+$/,'');
    var key  = WHOLEHOG.sbAnonKey || '';
    if (!base || !key) return;

    if (localStorage.getItem('WH_MIGRATED_TEAMS_TO_SB') === 'yes') return;

    function headers(){
      return {
        'apikey': key,
        'Authorization': 'Bearer ' + key,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal'
      };
    }

    function looksLikeTeams(arr){
      if (!Array.isArray(arr) || arr.length === 0) return false;
      // accept objects with name + (site or site_number)
      var ok = arr.some(function(o){
        return o && typeof o === 'object' &&
               typeof o.name === 'string' &&
               (typeof o.site === 'string' || typeof o.site_number === 'string');
      });
      return ok;
    }

    function normalizeTeam(o){
      return {
        name: (o.name || '').trim(),
        site_number: (o.site_number || o.site || '').toString().trim()
      };
    }

    function uniqByNameSite(list){
      var seen = {};
      var out = [];
      list.forEach(function(t){
        var k = (t.name + '|' + t.site_number).toLowerCase();
        if (!seen[k] && t.name && t.site_number){ seen[k] = true; out.push(t); }
      });
      return out;
    }

    // scan localStorage for arrays that look like teams
    var candidates = [];
    for (var i=0;i<localStorage.length;i++){
      var k = localStorage.key(i);
      try {
        var v = localStorage.getItem(k);
        var j = JSON.parse(v);
        if (looksLikeTeams(j)){
          j.forEach(function(o){ candidates.push(normalizeTeam(o)); });
        }
      } catch(_){}
    }
    candidates = uniqByNameSite(candidates);
    if (candidates.length === 0){ localStorage.setItem('WH_MIGRATED_TEAMS_TO_SB','yes'); return; }

    // fetch existing teams from Supabase to avoid duplicates
    fetch(base + '/rest/v1/teams?select=name,site_number&limit=1000', {method:'GET', headers:headers()})
      .then(function(r){ return r.ok ? r.json() : []; })
      .then(function(existing){
        var exist = {};
        existing.forEach(function(t){
          var k = (t.name + '|' + t.site_number).toLowerCase();
          exist[k] = true;
        });
        var toInsert = candidates.filter(function(t){
          var key = (t.name + '|' + t.site_number).toLowerCase();
          return !exist[key];
        });
        if (toInsert.length === 0){
          localStorage.setItem('WH_MIGRATED_TEAMS_TO_SB','yes');
          return;
        }
        // insert in small batches
        var chunk = 50, idx = 0;
        function next(){
          if (idx >= toInsert.length){
            localStorage.setItem('WH_MIGRATED_TEAMS_TO_SB','yes');
            return;
          }
          var batch = toInsert.slice(idx, idx+chunk);
          idx += chunk;
          fetch(base + '/rest/v1/teams', {
            method:'POST',
            headers:headers(),
            body: JSON.stringify(batch)
          }).then(function(){ next(); }).catch(function(){ next(); });
        }
        next();
      });
  } catch(e){
    // silent
  }
})();