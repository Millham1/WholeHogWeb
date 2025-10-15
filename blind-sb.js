(function(){
  'use strict';

  function $(sel){ return document.querySelector(sel); }
  function $all(sel){ return Array.prototype.slice.call(document.querySelectorAll(sel)); }

  // GET helper that reuses WHOLEHOG.sb if present
  function sbGet(path){
    if(window.WHOLEHOG && WHOLEHOG.sb && WHOLEHOG.sb.get){
      return WHOLEHOG.sb.get(path).then(r=>r.json());
    }
    var base = (window.WHOLEHOG && WHOLEHOG.sbProjectUrl) ? WHOLEHOG.sbProjectUrl : '';
    return fetch(base + path, {
      method:'GET',
      headers:{
        'apikey': (WHOLEHOG && WHOLEHOG.sbAnonKey) || '',
        'Authorization':'Bearer ' + ((WHOLEHOG && WHOLEHOG.sbAnonKey) || '')
      }
    }).then(r=>r.json());
  }

  // POST helper that reuses WHOLEHOG.sb if present
  function sbPost(path, body){
    if(window.WHOLEHOG && WHOLEHOG.sb && WHOLEHOG.sb.post){
      return WHOLEHOG.sb.post(path, body).then(r=>r.json());
    }
    var base = (window.WHOLEHOG && WHOLEHOG.sbProjectUrl) ? WHOLEHOG.sbProjectUrl : '';
    return fetch(base + path, {
      method:'POST',
      headers:{
        'apikey': (WHOLEHOG && WHOLEHOG.sbAnonKey) || '',
        'Authorization':'Bearer ' + ((WHOLEHOG && WHOLEHOG.sbAnonKey) || ''),
        'Content-Type':'application/json',
        'Prefer':'return=representation'
      },
      body: JSON.stringify(body)
    }).then(r=>r.json());
  }

  // Build score pickers
  var scores = { appearance:null, tenderness:null, taste:null };

  function buildOptions(container, min, max, step){
    var frag = document.createDocumentFragment();
    for(var v=min; v<=max; v+=step){
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'opt';
      b.textContent = String(v);
      (function(val){
        b.addEventListener('click', function(){
          var key = container.getAttribute('data-for');
          scores[key] = val;
          var lab = document.querySelector('button.picker-btn[data-for="'+key+'"] .sel');
          if(lab){ lab.textContent = String(val); }
          container.classList.remove('show');
          updateTotal();
        });
      })(v);
      frag.appendChild(b);
    }
    container.innerHTML = '';
    container.appendChild(frag);
  }

  function attachPicker(key, min, max, step){
    var btn = document.querySelector('button.picker-btn[data-for="'+key+'"]');
    var box = document.querySelector('div.options[data-for="'+key+'"]');
    if(!btn || !box) return;
    buildOptions(box, min, max, step);
    btn.addEventListener('click', function(){
      $all('div.options.show').forEach(function(el){ if(el!==box) el.classList.remove('show'); });
      box.classList.toggle('show');
    });
  }

  function updateTotal(){
    var a = scores.appearance||0, t = scores.tenderness||0, ta = scores.taste||0;
    var td = document.getElementById('totalDisplay');
    if(td) td.textContent = String(a+t+ta);
  }

  function loadJudges(){
    var sel = document.getElementById('judgeSelect');
    if(!sel) return;
    sel.innerHTML = '<option value="">Loading…</option>';
    sbGet('judges?select=id,name&order=name')
      .then(function(rows){
        sel.innerHTML = '<option value="">Select judge…</option>';
        (rows||[]).forEach(function(r){
          var o = document.createElement('option');
          o.value = r.id; o.textContent = r.name;
          sel.appendChild(o);
        });
      })
      .catch(function(){
        sel.innerHTML = '<option value="">Error loading judges</option>';
      });
  }

  function saveEntry(){
    var judgeId = document.getElementById('judgeSelect').value;
    var chip = (document.getElementById('chipInput').value||'').trim();
    if(!judgeId){ alert('Pick a judge'); return; }
    if(!chip){ alert('Enter a chip number'); return; }
    if(scores.appearance==null || scores.tenderness==null || scores.taste==null){
      alert('Pick all three scores'); return;
    }
    var body = [{
      judge_id: judgeId,
      chip_number: chip,
      appearance: scores.appearance,
      tenderness: scores.tenderness,
      taste: scores.taste
    }];
    sbPost('blind_entries', body)
      .then(function(resp){
        if(Array.isArray(resp) && resp.length){
          // reset and refresh
          scores.appearance = scores.tenderness = scores.taste = null;
          $all('.picker-btn .sel').forEach(function(s){ s.textContent='Choose'; });
          updateTotal();
          document.getElementById('chipInput').value='';
          refreshLeaderboard();
        } else {
          console.warn('Save response', resp);
          alert('Could not save (check Supabase table & RLS).');
        }
      })
      .catch(function(err){
        console.error(err);
        alert('Error saving score.');
      });
  }

  function refreshLeaderboard(){
    // Requires a view v_blind_leaderboard
    sbGet('v_blind_leaderboard?select=chip_number,total_points,tie_taste,tie_tenderness,tie_appearance&order=total_points.desc,tie_taste.desc,tie_tenderness.desc,tie_appearance.desc&limit=20')
      .then(function(rows){
        var host = document.getElementById('leaderboard');
        if(!host) return;
        if(!rows || !rows.length){ host.textContent='No scores yet.'; return; }
        var html = '<table class="lb"><thead><tr><th>Rank</th><th>Chip</th><th>Total</th></tr></thead><tbody>';
        rows.forEach(function(r, idx){
          html += '<tr><td>'+(idx+1)+'</td><td>'+r.chip_number+'</td><td>'+r.total_points+'</td></tr>';
        });
        html += '</tbody></table>';
        host.innerHTML = html;
      })
      .catch(function(){
        var host = document.getElementById('leaderboard');
        if(host) host.textContent = 'Leaderboard view missing (run SQL).';
      });
  }

  // Init
  document.addEventListener('click', function(e){
    if(!e.target.closest('.mini-card')){
      $all('.options.show').forEach(function(x){ x.classList.remove('show'); });
    }
  });

  attachPicker('appearance', 2, 40, 2);
  attachPicker('tenderness', 2, 40, 2);
  attachPicker('taste', 4, 80, 4);
  updateTotal();
  loadJudges();
  refreshLeaderboard();

  var saveBtn = document.getElementById('saveBtn');
  if(saveBtn){ saveBtn.addEventListener('click', saveEntry); }
})();
