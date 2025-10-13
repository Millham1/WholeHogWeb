(function(){
  'use strict';

  // Helpers
  function $(sel){ return document.querySelector(sel); }
  function $all(sel){ return Array.prototype.slice.call(document.querySelectorAll(sel)); }
  function byId(id){ return document.getElementById(id); }
  function findFirst(ids){
    for (var i=0;i<ids.length;i++){
      var el = byId(ids[i]);
      if(el) return el;
    }
    return null;
  }

  // Supabase fetch helpers using supabase-config.js globals
  function sbHeaders(){
    var key = (window.WHOLEHOG && window.WHOLEHOG.sbAnonKey) || '';
    return {
      'apikey': key,
      'Authorization': 'Bearer ' + key,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation'
    };
  }
  function sbUrl(path){
    var base = (window.WHOLEHOG && window.WHOLEHOG.sbProjectUrl) || '';
    return base + path;
  }
  function sbGet(path){
    return fetch(sbUrl(path), { method:'GET', headers: sbHeaders() }).then(function(r){ return r.json(); });
  }
  function sbPost(path, body){
    return fetch(sbUrl(path), { method:'POST', headers: sbHeaders(), body: JSON.stringify(body) }).then(function(r){ return r.json(); });
  }
  function sbDelete(path){
    return fetch(sbUrl(path), { method:'DELETE', headers: sbHeaders() }).then(function(r){
      // PostgREST returns 204 No Content on delete success
      if (r.status === 204) return { ok:true };
      return r.json().then(function(j){ return { ok:false, body:j }; });
    });
  }

  // Remove duplicate "Teams" cards (keep the first)
  function removeDuplicateTeamsCards(){
    var cards = $all('.card');
    var teamsCards = [];
    cards.forEach(function(c){
      var h = c.querySelector('h2');
      if(h && /teams/i.test(h.textContent || '')) teamsCards.push(c);
    });
    if(teamsCards.length > 1){
      teamsCards.slice(1).forEach(function(c){ c.parentNode && c.parentNode.removeChild(c); });
    }
  }

  // Render helpers
  function ensureContainerFor(sectionTitle, fallbackId){
    // Try to find an existing container by common IDs; otherwise create inside the card with the heading
    var el = findFirst([fallbackId, fallbackId+'s', fallbackId+'List', fallbackId+'-list', fallbackId+'-container']);
    if(el) return el;
    var cards = $all('.card');
    for (var i=0;i<cards.length;i++){
      var h = cards[i].querySelector('h2');
      if(h && new RegExp('^\\s*'+sectionTitle+'\\s*$', 'i').test(h.textContent||'')){
        el = document.createElement('div');
        el.id = fallbackId;
        el.className = 'list';
        cards[i].appendChild(el);
        return el;
      }
    }
    return null;
  }

  // TEAMS
  function loadTeams(){
    var cont = ensureContainerFor('Teams', 'teamsList');
    if(!cont) return;
    cont.textContent = 'Loading…';
    sbGet('/rest/v1/teams?select=id,name,site_number&order=site_number.asc').then(function(rows){
      if(!rows || !rows.length){ cont.textContent = 'No teams yet.'; return; }
      var ul = document.createElement('ul');
      ul.className = 'plain';
      rows.forEach(function(r){
        var li = document.createElement('li');
        li.textContent = r.name + ' (Site ' + r.site_number + ')';
        ul.appendChild(li);
      });
      cont.innerHTML = '';
      cont.appendChild(ul);
    }).catch(function(){ cont.textContent = 'Error loading teams.'; });
  }
  function wireAddTeam(){
    var nameEl = byId('teamName') || byId('team-name');
    var siteEl = byId('siteNumber') || byId('site-number');
    var btn    = byId('btnAddTeam') || byId('addTeam') || byId('btn-add-team');
    if(!btn || !nameEl || !siteEl) return;
    btn.addEventListener('click', function(){
      var name = (nameEl.value||'').trim();
      var site = (siteEl.value||'').trim();
      if(!name || !site){ alert('Enter team name and site #'); return; }
      sbPost('/rest/v1/teams', [{ name:name, site_number:site }]).then(function(resp){
        if(Array.isArray(resp) && resp.length){
          nameEl.value=''; siteEl.value='';
          loadTeams();
        } else {
          alert('Could not add team (check RLS).');
          console.warn(resp);
        }
      }).catch(function(){ alert('Error adding team.'); });
    });
  }

  // JUDGES (with Remove)
  function renderJudges(listEl, rows){
    if(!rows || !rows.length){ listEl.textContent = 'No judges yet.'; return; }
    var div = document.createElement('div');
    rows.forEach(function(r){
      var row = document.createElement('div');
      row.className = 'judge-row';
      var name = document.createElement('span');
      name.className = 'judge-name';
      name.textContent = r.name;
      var rm = document.createElement('button');
      rm.type = 'button';
      rm.className = 'btn-remove';
      rm.textContent = 'Remove';
      rm.addEventListener('click', function(){
        if(!confirm('Remove judge "'+r.name+'"?')) return;
        sbDelete('/rest/v1/judges?id=eq.' + encodeURIComponent(r.id)).then(function(ok){
          if(ok && ok.ok){ loadJudges(); }
          else { alert('Delete failed (RLS?)'); }
        }).catch(function(){ alert('Delete error.'); });
      });
      row.appendChild(name);
      row.appendChild(rm);
      div.appendChild(row);
    });
    listEl.innerHTML = '';
    listEl.appendChild(div);
  }
  function loadJudges(){
    var cont = ensureContainerFor('Judges', 'judgesList');
    if(!cont) return;
    cont.textContent = 'Loading…';
    sbGet('/rest/v1/judges?select=id,name&order=name.asc').then(function(rows){
      renderJudges(cont, rows||[]);
    }).catch(function(){ cont.textContent = 'Error loading judges.'; });
  }
  function wireAddJudge(){
    var nameEl = byId('judgeName') || byId('judge-name');
    var btn    = byId('btnAddJudge') || byId('addJudge') || byId('btn-add-judge');
    if(!btn || !nameEl) return;
    btn.addEventListener('click', function(){
      var name = (nameEl.value||'').trim();
      if(!name){ alert('Enter judge name'); return; }
      sbPost('/rest/v1/judges', [{ name:name }]).then(function(resp){
        if(Array.isArray(resp) && resp.length){
          nameEl.value='';
          loadJudges();
        } else {
          alert('Could not add judge (check RLS).');
          console.warn(resp);
        }
      }).catch(function(){ alert('Error adding judge.'); });
    });
  }

  // Init
  document.addEventListener('DOMContentLoaded', function(){
    removeDuplicateTeamsCards();
    wireAddTeam();
    wireAddJudge();
    loadTeams();
    loadJudges();
  });

})();