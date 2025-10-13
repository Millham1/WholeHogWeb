(function(){
  window.WHOLEHOG = window.WHOLEHOG || {};
  window.WHOLEHOG.sbProjectUrl = "https://wiolulxxfyetvdpnfusq.supabase.co";
  window.WHOLEHOG.sbAnonKey    = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc";

  function sbHeaders(){
    return {
      "apikey": window.WHOLEHOG.sbAnonKey,
      "Authorization": "Bearer " + window.WHOLEHOG.sbAnonKey,
      "Content-Type": "application/json",
      "Prefer": "return=representation"
    };
  }
  window.WHOLEHOG.sb = {
    get:  function(path){ return fetch(window.WHOLEHOG.sbProjectUrl + path, { method:"GET",  headers: sbHeaders() }); },
    post: function(path, body){ return fetch(window.WHOLEHOG.sbProjectUrl + path, { method:"POST", headers: sbHeaders(), body: JSON.stringify(body) }); }
  };
})();