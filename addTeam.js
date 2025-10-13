import { supabase } from './supabaseClient.js';

export async function addTeam(args) {
  const team_name = (args && args.team_name ? String(args.team_name).trim() : "");
  const chip_raw  = (args && args.chip_number != null ? String(args.chip_number).trim() : "");
  const n = Number(chip_raw);

  if (!team_name) throw new Error("Team name is required.");
  if (!Number.isInteger(n) || n <= 0) throw new Error("Chip number must be a positive integer.");

  const res = await supabase
    .from("teams")
    .insert([{ team_name: team_name, chip_number: n }])
    .select()
    .single();

  if (res && res.error) {
    if (res.error.code === "23505") throw new Error("That chip number is already registered.");
    throw new Error(res.error.message || "Insert failed.");
  }
  return res.data;
}

document.addEventListener("DOMContentLoaded", function () {
  var form = document.getElementById("add-team-form");
  if (!form) return;

  form.addEventListener("submit", async function (ev) {
    ev.preventDefault();
    var team_name   = form.elements["team_name"] ? form.elements["team_name"].value : "";
    var chip_number = form.elements["chip_number"] ? form.elements["chip_number"].value : "";

    try {
      var inserted = await addTeam({ team_name: team_name, chip_number: chip_number });
      alert("Added " + inserted.team_name + " (Chip #" + inserted.chip_number + ")");
      form.reset();
    } catch (err) {
      alert(err && err.message ? err.message : "Failed to add team");
      console.error(err);
    }
  }, { passive: false });
});
