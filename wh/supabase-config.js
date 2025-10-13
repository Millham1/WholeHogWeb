(function(){
  window.WHOLEHOG = window.WHOLEHOG || {};
  WHOLEHOG.URL = 'https://wiolulxxfyetvdpnfusq.supabase.co';
  WHOLEHOG.KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc';
  function ensureClient(){
    if (!window.supabase) return null;
    if (!WHOLEHOG.sb){
      try { WHOLEHOG.sb = window.supabase.createClient(WHOLEHOG.URL, WHOLEHOG.KEY); }
      catch(e){ console.error('Supabase createClient failed', e); }
    }
    return WHOLEHOG.sb || null;
  }
  (function wait(){ if (ensureClient()) return; setTimeout(wait, 120); })();
})();