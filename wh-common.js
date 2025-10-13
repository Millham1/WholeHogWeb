/* wh-common.js: shared Supabase client + helpers */
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const SUPABASE_URL = "https://wiolulxxfyetvdpnfusq.supabase.co";
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc";
export const sb = createClient(SUPABASE_URL, SUPABASE_KEY);

// Teams
export async function fetchTeams() {
  const { data, error } = await sb.from("teams").select("id,name,site_number").order("site_number", { ascending: true });
  if (error) { console.error("fetchTeams:", error); return []; }
  return data || [];
}
export async function insertTeam(name, site_number) {
  const { data, error } = await sb.from("teams").insert([{ name, site_number }]).select();
  if (error) throw error;
  return data?.[0] || null;
}

// Judges
export async function fetchJudges() {
  const { data, error } = await sb.from("judges").select("id,name").order("name", { ascending: true });
  if (error) { console.error("fetchJudges:", error); return []; }
  return data || [];
}
export async function insertJudge(name) {
  const { data, error } = await sb.from("judges").insert([{ name }]).select();
  if (error) throw error;
  return data?.[0] || null;
}

// small helpers for remembering last selection
export const state = {
  get lastTeam(){ return localStorage.getItem("wh.lastTeam") || ""; },
  set lastTeam(v){ localStorage.setItem("wh.lastTeam", v || ""); },
  get lastJudge(){ return localStorage.getItem("wh.lastJudge") || ""; },
  set lastJudge(v){ localStorage.setItem("wh.lastJudge", v || ""); }
};
