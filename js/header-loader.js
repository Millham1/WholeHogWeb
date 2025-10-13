(function(){
  function inject(html){
    var slot = document.getElementById("site-header");
    if (!slot) return;
    slot.innerHTML = html;
  }
  var DEFAULT_HEADER_HTML = 
'
<div class="site-header-wrap" style="display:flex;align-items:center;gap:.75rem;padding:.5rem 1rem;border-bottom:1px solid #333;background:#0b0b0b;">  <img src="Legion whole hog logo.png" alt="Legion Whole Hog" style="height:48px;object-fit:contain;border-radius:6px;">  <img src="AL Medallion.png" alt="AL Medallion" style="height:48px;object-fit:contain;border-radius:6px;">  <div style="font-weight:700;font-size:1.1rem;letter-spacing:.3px;">Whole Hog Competition</div>  <nav style="margin-left:auto;display:flex;gap:.75rem;flex-wrap:wrap;">    <a href="index.html" style="text-decoration:none;border:1px solid #444;padding:.35rem .6rem;border-radius:8px;">Home</a>    <a href="leaderboard.html" style="text-decoration:none;border:1px solid #444;padding:.35rem .6rem;border-radius:8px;">Leaderboard</a>  </nav></div>
'
;
  function tryFetch(){
    try {
      if (location.protocol === "http:" || location.protocol === "https:") {
        return fetch("header.html", {cache:"no-store"})
          .then(function(r){ return r.ok ? r.text() : ""; })
          .then(function(html){ if (html) inject(html); else inject(DEFAULT_HEADER_HTML); })
          .catch(function(){ inject(DEFAULT_HEADER_HTML); });
      }
    } catch(e) {}
    inject(DEFAULT_HEADER_HTML);
  }
  document.addEventListener("DOMContentLoaded", function(){
    if (window.WHOLEHOG_HEADER_HTML) {
      inject(window.WHOLEHOG_HEADER_HTML);
    } else {
      tryFetch();
    }
  });
})();