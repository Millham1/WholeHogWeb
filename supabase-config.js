;(function(){
  try{
    // The CDN exposes a global named \supabase\ (UMD). Use it to create a client.
    if (typeof supabase === 'undefined' || typeof supabase.createClient !== 'function') {
      console.error('[supabase-config] Supabase UMD not loaded yet.');
      return;
    }
    var client = supabase.createClient('https://wiolulxxfyetvdpnfusq.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc');
    // Expose the client globally for other scripts
    window.supabase = client;
    window.supabaseClient = client;
    console.log('[supabase-config] client ready:', typeof window.supabase.from === 'function');
  }catch(e){
    console.error('[supabase-config] init failed', e);
  }
})();
