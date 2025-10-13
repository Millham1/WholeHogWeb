import { supabase } from './supabaseClient.js';

async function loadChips() {
  const { data, error } = await supabase
    .from('teams')
    .select('chip_number')
    .order('chip_number', { ascending: true });

  if (error) {
    console.error('Load chips error:', error);
    return [];
  }
  return data ?? [];
}

export async function populateChipSelect() {
  const sel = document.getElementById('chip-select');
  if (!sel) return;

  const chips = await loadChips();

  sel.innerHTML = '';
  const ph = document.createElement('option');
  ph.value = '';
  ph.textContent = 'Select chip #';
  ph.disabled = true;
  ph.selected = true;
  sel.appendChild(ph);

  for (const row of chips) {
    if (row?.chip_number == null) continue;
    const n = row.chip_number;
    const opt = document.createElement('option');
    opt.value = String(n);
    opt.textContent = String(n); // label shows ONLY the number
    sel.appendChild(opt);
  }
}

document.addEventListener('DOMContentLoaded', () => {
  populateChipSelect();
});
