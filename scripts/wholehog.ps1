# wholehog.ps1 — minimal update (no DB changes). Run from the project root.
# Path enforced: C:\Users\millh_y3006x1\Desktop\WholeHogWeb
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Config ---
$ProjectRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"

function Step($m){ Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok($m){ Write-Host "   • $m" -ForegroundColor Green }
function Info($m){ Write-Host "   • $m" -ForegroundColor DarkGray }
function Ensure-Dir($p){ if(-not(Test-Path $p)){ New-Item -ItemType Directory -Path $p -Force | Out-Null } }
function Backup($p){ if(Test-Path $p){ $t=Get-Date -Format "yyyyMMdd_HHmmss"; Copy-Item $p "$p.$t.bak" -Force; Info "Backup: $p -> $p.$t.bak" } }
function Write-File($p,[string]$c){ Backup $p; Ensure-Dir (Split-Path -Parent $p); Set-Content -Path $p -Encoding UTF8 -Value $c; Ok "Wrote $p" }

# --- 0) Verify path ---
Step "Verifying project root"
$here = [IO.Path]::GetFullPath((Get-Location).Path)
$expect = [IO.Path]::GetFullPath($ProjectRoot)
Write-Host "   • Current : $here"
Write-Host "   • Expected: $expect"
if($here -ne $expect){ throw "Run this script from: $expect" }
if(-not (Test-Path (Join-Path $here "package.json"))){
  throw "package.json not found. This script assumes an existing Next.js project here."
}

# --- 1) Common code blobs (shared by both routers) ---
$SupabaseClient = @'
import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL as string;
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY as string;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  throw new Error("Missing Supabase env: NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY");
}

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
'@

$Header = @'
import Link from "next/link";
export function Header({ title }: { title: string }) {
  return (
    <header className="w-full bg-white/80 backdrop-blur sticky top-0 z-50 shadow-sm">
      <div className="mx-auto max-w-5xl px-4 py-3 flex items-center justify-between">
        <div className="text-2xl font-bold tracking-tight">{title}</div>
        <nav className="flex items-center gap-2">
          <Link href="/" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Home</Link>
        </nav>
      </div>
    </header>
  );
}
'@

# ---- App Router files ----
$App_Landing = @'
"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { Header } from "../components/Header";
import { supabase } from "../supabaseClient";

export default function LandingPage() {
  return (
    <main className="min-h-screen bg-neutral-50">
      <Header title="Whole Hog" />
      <section className="mx-auto max-w-5xl px-4 py-6 grid gap-6">
        <div className="flex items-center gap-3">
          <Link href="/blind-taste" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to Blind Taste</Link>
          <Link href="/leaderboard" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to Leaderboard</Link>
        </div>
        <TeamEntryCard />
        <TeamList />
      </section>
    </main>
  );
}

function TeamEntryCard() {
  const [site, setSite] = useState("");
  const [team, setTeam] = useState("");
  const [chip, setChip] = useState("");
  const [status, setStatus] = useState<null | { type: "ok" | "warn" | "err"; msg: string }>(null);

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    const siteNum = Number(site);
    if (!Number.isFinite(siteNum)) { setStatus({ type: "warn", msg: "Site # must be a number." }); return; }
    if (!team.trim()) { setStatus({ type: "warn", msg: "Team name is required." }); return; }
    const chipNum = chip.trim().toUpperCase();
    if (!chipNum) { setStatus({ type: "warn", msg: "Chip # is required." }); return; }

    const { error } = await supabase.from("teams").upsert(
      { site_number: siteNum, team_name: team.trim(), chip_number: chipNum },
      { onConflict: "chip_number" }
    );
    if (error) setStatus({ type: "err", msg: error.message });
    else { setStatus({ type: "ok", msg: "Team saved." }); setSite(""); setTeam(""); setChip(""); }
  }

  return (
    <form onSubmit={handleSave} className="grid gap-3 rounded-2xl border bg-white p-5 shadow-sm">
      <h2 className="text-lg font-semibold">Team Entry</h2>
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div className="grid gap-1"><label className="text-sm font-medium">Site #</label>
          <input value={site} onChange={(e) => setSite(e.target.value)} className="rounded-xl border px-3 py-2" placeholder="e.g., 7" />
        </div>
        <div className="grid gap-1"><label className="text-sm font-medium">Team Name</label>
          <input value={team} onChange={(e) => setTeam(e.target.value)} className="rounded-xl border px-3 py-2" placeholder="Team" />
        </div>
        <div className="grid gap-1"><label className="text-sm font-medium">Chip # (unique)</label>
          <input value={chip} onChange={(e) => setChip(e.target.value.toUpperCase())} className="rounded-xl border px-3 py-2" placeholder="e.g., A12" />
        </div>
      </div>
      <div className="flex items-center gap-2">
        <button type="submit" className="inline-flex items-center rounded-xl border px-4 py-2 text-sm font-medium hover:shadow">Save Team</button>
        {status && (<span className={status.type==="ok"?"text-green-600 text-sm":status.type==="warn"?"text-amber-600 text-sm":"text-red-600 text-sm"}>{status.msg}</span>)}
      </div>
    </form>
  );
}

function TeamList() {
  const [rows, setRows] = useState<{ id: string; site_number: number; team_name: string; chip_number: string }[]>([]);
  useEffect(() => {
    let mounted = true;
    async function load() {
      const { data } = await supabase.from("teams").select("id, site_number, team_name, chip_number").order("site_number", { ascending: true });
      if (mounted) setRows(data || []);
    }
    load();
    const channel = supabase.channel("teams-list").on("postgres_changes", { event: "*", schema: "public", table: "teams" }, () => load()).subscribe();
    return () => { mounted = false; supabase.removeChannel(channel); };
  }, []);
  if (!rows.length) return null;
  return (
    <div className="rounded-2xl border bg-white">
      <div className="px-5 py-3 text-sm font-semibold">Registered Teams</div>
      <div className="divide-y">
        {rows.map((r) => (
          <div key={r.id} className="grid grid-cols-1 sm:grid-cols-4 items-center gap-2 px-5 py-3">
            <div className="text-sm"><span className="text-neutral-500">Site:</span> {r.site_number}</div>
            <div className="text-sm sm:col-span-2 font-medium">{r.team_name}</div>
            <div className="text-sm"><span className="text-neutral-500">Chip:</span> {r.chip_number}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
'@

$App_BlindTaste = @'
"use client";
import { useEffect, useMemo, useState } from "react";
import { Header } from "../../components/Header";
import { supabase } from "../../supabaseClient";

export default function BlindTastePage() {
  const [chip, setChip] = useState("");
  const [score, setScore] = useState("");
  const [status, setStatus] = useState<null | { type: "ok" | "warn" | "err"; msg: string }>(null);
  const [team, setTeam] = useState<null | { chip_number: string; team_name: string; site_number: number }>(null);
  const scoreNumber = useMemo(() => (score.trim() === "" ? NaN : Number(score)), [score]);

  useEffect(() => {
    let active = true;
    async function lookupTeam(c: string) {
      if (!c) { setTeam(null); return; }
      const { data, error } = await supabase.from("teams").select("chip_number, team_name, site_number").eq("chip_number", c).maybeSingle();
      if (!active) return;
      if (error) { setTeam(null); setStatus({ type: "err", msg: `Lookup failed: ${error.message}` }); }
      else if (data) { setTeam(data); setStatus(null); }
      else { setTeam(null); setStatus({ type: "warn", msg: "No team found for that chip # yet. Save a team card first." }); }
    }
    lookupTeam(chip.trim());
    return () => { active = false; };
  }, [chip]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const c = chip.trim();
    if (!c) { setStatus({ type: "warn", msg: "Enter a chip #." }); return; }
    if (!Number.isFinite(scoreNumber)) { setStatus({ type: "warn", msg: "Score must be a number." }); return; }
    const { data: teamRow, error: teamErr } = await supabase.from("teams").select("chip_number").eq("chip_number", c).maybeSingle();
    if (teamErr) { setStatus({ type: "err", msg: `Team check failed: ${teamErr.message}` }); return; }
    if (!teamRow) { setStatus({ type: "err", msg: "Chip # not found in Teams. Add it on the landing page first." }); return; }
    const { error: insertErr } = await supabase.from("scores").insert({ chip_number: c, score: scoreNumber });
    if (insertErr) { setStatus({ type: "err", msg: `Save failed: ${insertErr.message}` }); return; }
    setStatus({ type: "ok", msg: "Score saved." }); setScore("");
  }

  return (
    <main className="min-h-screen bg-neutral-50">
      <Header title="Blind Taste" />
      <section className="mx-auto max-w-5xl px-4 py-6">
        <form onSubmit={handleSubmit} className="grid gap-4 rounded-2xl border bg-white p-5 shadow-sm">
          <div className="grid gap-1">
            <label htmlFor="chip" className="text-sm font-medium">Chip #</label>
            <input id="chip" value={chip} onChange={(e) => setChip(e.target.value.toUpperCase())} placeholder="e.g., A12" className="w-full rounded-xl border px-3 py-2 outline-none focus:ring" autoFocus autoComplete="off" inputMode="text" />
            {team && (<p className="text-xs text-neutral-600">Team: <span className="font-medium">{team.team_name}</span> (Site {team.site_number})</p>)}
          </div>
          <div className="grid gap-1">
            <label htmlFor="score" className="text-sm font-medium">Score</label>
            <input id="score" value={score} onChange={(e) => setScore(e.target.value)} placeholder="e.g., 89.5" className="w-full rounded-xl border px-3 py-2 outline-none focus:ring" inputMode="decimal" />
          </div>
          <div className="flex items-center gap-2">
            <button type="submit" className="inline-flex items-center rounded-xl border px-4 py-2 text-sm font-medium hover:shadow">Save Score</button>
            {status && (<span className={status.type==="ok"?"text-green-600 text-sm":status.type==="warn"?"text-amber-600 text-sm":"text-red-600 text-sm"}>{status.msg}</span>)}
          </div>
        </form>
        {team && <RecentScores chip={team.chip_number} />}
      </section>
    </main>
  );
}

function RecentScores({ chip }: { chip: string }) {
  const [rows, setRows] = useState<{ id: string; score: number; created_at: string }[]>([]);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    let mounted = true;
    async function load() {
      const { data, error } = await supabase.from("scores").select("id, score, created_at").eq("chip_number", chip).order("created_at", { ascending: false }).limit(10);
      if (!mounted) return;
      if (error) setError(error.message); else setRows(data || []);
    }
    load();
    const channel = supabase.channel(`scores-${chip}`).on("postgres_changes", { event: "INSERT", schema: "public", table: "scores", filter: `chip_number=eq.${chip}` }, (payload) => {
      setRows((prev) => [{ id: payload.new.id as string, score: payload.new.score as number, created_at: payload.new.created_at as string }, ...prev].slice(0, 10));
    }).subscribe();
    return () => { mounted = false; supabase.removeChannel(channel); };
  }, [chip]);
  if (error) return <p className="mt-6 text-sm text-red-600">{error}</p>;
  if (!rows.length) return <p className="mt-6 text-sm text-neutral-600">No scores yet for this chip.</p>;
  return (
    <div className="mt-6">
      <h2 className="text-lg font-semibold">Recent Scores</h2>
      <ul className="mt-2 divide-y rounded-2xl border bg-white">
        {rows.map((r) => (<li key={r.id} className="flex items-center justify-between px-4 py-2"><span className="text-sm">{new Date(r.created_at).toLocaleString()}</span><span className="text-base font-medium">{r.score}</span></li>))}
      </ul>
    </div>
  );
}
'@

$App_Leaderboard = @'
"use client";
import { Header } from "../../components/Header";
export default function LeaderboardPage() {
  return (
    <main className="min-h-screen bg-neutral-50">
      <Header title="Leaderboard" />
      <section className="mx-auto max-w-5xl px-4 py-6">
        <p className="text-sm text-neutral-600">Leaderboard coming soon.</p>
      </section>
    </main>
  );
}
'@

# ---- Pages Router files ----
$Pages_Landing = $App_Landing.Replace('from "../components/Header"','from "../components/Header"').Replace('from "../supabaseClient"','from "../supabaseClient"').Replace('"use client";','') # pages/ runs client by default
$Pages_BlindTaste = $App_BlindTaste.Replace('from "../../components/Header"','from "../components/Header"').Replace('from "../../supabaseClient"','from "../supabaseClient"').Replace('"use client";','')
$Pages_Leaderboard = $App_Leaderboard.Replace('from "../../components/Header"','from "../components/Header"').Replace('"use client";','')

# --- 2) Create/Update shared files ---
Step "Writing shared files"
if(-not (Test-Path (Join-Path $here "supabaseClient.ts"))){
  Write-File (Join-Path $here "supabaseClient.ts") $SupabaseClient
}else{ Info "Skip (exists): supabaseClient.ts" }

Ensure-Dir (Join-Path $here "components")
Write-File (Join-Path $here "components/Header.tsx") $Header

# --- 3) Detect router and write pages ---
$HasApp = Test-Path (Join-Path $here "app")
$HasPages = Test-Path (Join-Path $here "pages")

if($HasApp -or -not $HasPages){
  Step "Using App Router (app/*)"
  Ensure-Dir (Join-Path $here "app")
  # Landing: only overwrite if missing Leaderboard link
  $landingPath = Join-Path $here "app\page.tsx"
  $needsWrite = $true
  if(Test-Path $landingPath){
    $content = Get-Content $landingPath -Raw
    if($content -match 'href="/leaderboard"'){ $needsWrite = $false; Info "Landing already has Leaderboard link. Leaving file as-is." }
  }
  if($needsWrite){ Write-File $landingPath $App_Landing }

  Ensure-Dir (Join-Path $here "app\blind-taste")
  Write-File (Join-Path $here "app\blind-taste\page.tsx") $App_BlindTaste

  Ensure-Dir (Join-Path $here "app\leaderboard")
  Write-File (Join-Path $here "app\leaderboard\page.tsx") $App_Leaderboard
}else{
  Step "Using Pages Router (pages/*)"
  Ensure-Dir (Join-Path $here "pages")
  # Landing: only overwrite if missing Leaderboard link
  $landingPath = Join-Path $here "pages\index.tsx"
  $needsWrite = $true
  if(Test-Path $landingPath){
    $content = Get-Content $landingPath -Raw
    if($content -match 'href="/leaderboard"'){ $needsWrite = $false; Info "Landing already has Leaderboard link. Leaving file as-is." }
  }
  if($needsWrite){ Write-File $landingPath $Pages_Landing }

  Write-File (Join-Path $here "pages\blind-taste.tsx") $Pages_BlindTaste
  Write-File (Join-Path $here "pages\leaderboard.tsx") $Pages_Leaderboard
}

Step "Done"
Write-Host "Keep using your existing run workflow (e.g., Ctrl+F5). No DB or tooling changes were made." -ForegroundColor Yellow





