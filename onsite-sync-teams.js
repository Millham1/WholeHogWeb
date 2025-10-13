(function(){
  function base(){ return (window.WHOLEHOG && WHOLEHOG.sbProjectUrl || '').replace(/\/+$/,''); }
  function key(){  return (window.WHOLEHOG && WHOLEHOG.sbAnonKey) || ''; }
  function headers(){
    var k = key();
    return {'apikey':k,'Authorization':'Bearer '+k,'Content-Type':'application/json'};
  }
  function findTeamSelects(){
    var sels = Array.prototype.slice.call(document.querySelectorAll('select'));
    // Prefer selects whose id/name/class mentions 'team'
    var good = sels.filter(function(s){
      var id = (s.id||'').toLowerCase();
      var nm = (s.name||'').toLowerCase();
      var cl = (s.className||'').toLowerCase();
      return id.indexOf('team')>=0 || nm.indexOf('team')>=0 || cl.indexOf('team')>=0;
    });
    if (good.length) return good;
    // Fallback: first select with many text options like "Team (Site ...)"
    var guess = sels.filter(function(s){ return s.options && s.options.length >= 1; });
    return guess;
  }
  function label(t){ 
    var n = (t.name||'').trim();
    var s = (t.site_number||'').toString().trim();
    return s ? (n + ' (Site ' + s + ')') : n; 
  }
  function populate(selects, teams){
    if (!selects || !selects.length) return;
    var opts = teams.map(function(t){
      return '<option value="'+ (t.id||'') +'">'+ label(t) +'</option>';
    }).join('');
    selects.forEach(function(sel){
      var hasPlaceholder = sel.options.length && sel.options[0].value==="";
      var ph = hasPlaceholder ? sel.options[0].outerHTML : '<option value="">Select a team...</option>';
      sel.innerHTML = ph + opts;
    });
    // Expose to any other scripts
    window.WHOLEHOG = window.WHOLEHOG || {};
    window.WHOLEHOG.teams = teams;
  }
  function load(){
    var b = base(), k = key();
    if(!b || !k) return;
    fetch(b + '/rest/v1/teams?select=id,name,site_number&order=site_number.asc', {method:'GET', headers:headers()})
      .then(function(r){ return r.ok ? r.json() : []; })
      .then(function(list){
        var selects = findTeamSelects();
        populate(selects, list || []);
      })
      .catch(function(e){ console.warn('Team sync failed:', e); });
  }
  if (document.readyState === 'loading'){
    document.addEventListener('DOMContentLoaded', load);
  } else {
    load();
  }
})();