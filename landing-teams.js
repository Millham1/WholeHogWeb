(function(){
  function headers(){
    var key = (window.WHOLEHOG && WHOLEHOG.sbAnonKey) || "";
    return {
      "apikey": key,
      "Authorization": "Bearer " + key,
      "Content-Type": "application/json",
      "Prefer": "return=representation"
    };
  }
  function base(){
    return (window.WHOLEHOG && WHOLEHOG.sbProjectUrl) || "";
  }

  function qsel(id){ return document.getElementById(id); }
  function esc(s){ var d = document.createElement('div'); d.textContent = s; return d.innerHTML; }

  function renderTeams(list){
    var ul = qsel('whTeamsList');
    if(!ul) return;
    if(!Array.isArray(list) || list.length === 0){
      ul.innerHTML = '<li style="color:#666;padding:6px 8px;">No teams yet</li>';
      return;
    }
    var html = list.map(function(t){
      var label = esc(t.name) + ' (Site ' + esc(t.site_number || '') + ')';
      return (
        '<li style="display:flex;align-items:center;justify-content:space-between;padding:8px 10px;border:1px solid #ddd;border-radius:8px;margin:6px 0;">' +
          '<span>' + label + '</span>' +
          '<button data-id="' + esc(t.id) + '" class="wh-remove-team" style="background:#fff;color:#b10020;border:2px solid #b10020;border-radius:8px;padding:6px 10px;cursor:pointer;">Remove</button>' +
        '</li>'
      );
    }).join('');
    ul.innerHTML = html;

    // wire remove buttons
    var btns = ul.querySelectorAll('button.wh-remove-team');
    Array.prototype.forEach.call(btns, function(btn){
      btn.addEventListener('click', function(){
        var id = btn.getAttribute('data-id');
        if(!id) return;
        if(!confirm('Remove this team? (This will fail if the team already has scoring entries.)')) return;

        fetch(base() + '/rest/v1/teams?id=eq.' + encodeURIComponent(id), {
          method: 'DELETE',
          headers: headers()
        })
        .then(function(r){ return r.ok ? r.text() : r.text().then(function(t){ throw new Error(t || r.statusText); }); })
        .then(function(){
          loadTeams(); // refresh after deletion
        })
        .catch(function(err){
          alert('Delete failed (team may have linked scores): ' + err.message);
        });
      });
    });
  }

  function loadTeams(){
    var url = base() + '/rest/v1/teams?select=id,name,site_number&order=site_number.asc';
    fetch(url, { method:'GET', headers: headers() })
      .then(function(r){ return r.ok ? r.json() : r.text().then(function(t){ throw new Error(t || r.statusText); }); })
      .then(renderTeams)
      .catch(function(err){ console.error('Load teams failed:', err); });
  }

  function addTeam(){
    var name = (qsel('whTeamName') && qsel('whTeamName').value || '').trim();
    var site = (qsel('whSiteNumber') && qsel('whSiteNumber').value || '').trim();
    if(!name || !site){ alert('Enter both Team Name and Site #'); return; }

    var body = [{ name: name, site_number: site }];

    fetch(base() + '/rest/v1/teams', {
      method:'POST',
      headers: headers(),
      body: JSON.stringify(body)
    })
    .then(function(r){ return r.ok ? r.json() : r.text().then(function(t){ throw new Error(t || r.statusText); }); })
    .then(function(){
      if(qsel('whTeamName')) qsel('whTeamName').value = '';
      if(qsel('whSiteNumber')) qsel('whSiteNumber').value = '';
      loadTeams();
    })
    .catch(function(err){ alert('Add failed: ' + err.message); });
  }

  function ensureWiring(){
    var btn = qsel('whBtnAddTeam');
    if(btn && !btn._wh_wired){
      btn.addEventListener('click', addTeam);
      btn._wh_wired = true;
    }
  }

  function init(){
    ensureWiring();
    loadTeams();
  }

  if(document.readyState === 'loading'){
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();