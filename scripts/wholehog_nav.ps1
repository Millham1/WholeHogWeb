# wholehog_nav.ps1 — create nav buttons/pages (no DB changes)
# Run from: C:\Users\millh_y3006x1\Desktop\WholeHogWeb
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
  throw "package.json not found. This assumes an existing Next.js project."
}

# --- 1) Figure out layout (supports src/, app/, pages/) ---
$BaseDir   = (Test-Path (Join-Path $here "src")) ? (Join-Path $here "src") : $here
$AppDir    = Join-Path $BaseDir "app"
$PagesDir  = Join-Path $BaseDir "pages"
$CompDir   = Join-Path $BaseDir "components"
$UseApp    = (Test-Path $AppDir) -or (-not (Test-Path $PagesDir))  # prefer app if present

# Header import paths per router
$Import_Header_App_Landing   = '../components/Header'
$Import_Header_App_Subpage   = '../../components/Header'
$Import_Header_Pages         = '../components/Header'

# --- 2) Header (provides the Home button) ---
Step "Writing shared Header (with Home button)"
$Header = @'
import Link from "next/link";
export function Header({ title }: { title: string }) {
  return (
    <header className="w-full bg-white/80 backdrop-blur sticky top-0 z-50 shadow-sm">
      <div className="mx-auto max-w-5xl px-4 py-3 flex items-center justify-between">
        <div className="text-2xl font-bold tracking-tight">{title}</div>
        <nav className="flex items-center gap-2">
          <Link href="/" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">
            Home
          </Link>
        </nav>
      </div>
    </header>
  );
}
'@
Ensure-Dir $CompDir
Write-File (Join-Path $CompDir "Header.tsx") $Header

# --- 3) Page templates ---
# Landing page (adds "Go to" buttons)
$App_Landing = @'
"use client";
import Link from "next/link";
import { Header } from "__IMPORT__";

export default function LandingPage() {
  return (
    <main className="min-h-screen bg-neutral-50">
      <Header title="Whole Hog" />
      <section className="mx-auto max-w-5xl px-4 py-6 grid gap-6">
        <div className="flex flex-wrap items-center gap-3" data-wholehog="landing-nav">
          <Link href="/on-site" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to On-Site</Link>
          <Link href="/blind-taste" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to Blind Taste</Link>
          <Link href="/leaderboard" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to Leaderboard</Link>
        </div>
      </section>
    </main>
  );
}
'@

$Pages_Landing = @'
import Link from "next/link";
import { Header } from "__IMPORT__";

export default function Home() {
  return (
    <main className="min-h-screen bg-neutral-50">
      <Header title="Whole Hog" />
      <section className="mx-auto max-w-5xl px-4 py-6 grid gap-6">
        <div className="flex flex-wrap items-center gap-3" data-wholehog="landing-nav">
          <Link href="/on-site" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to On-Site</Link>
          <Link href="/blind-taste" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to Blind Taste</Link>
          <Link href="/leaderboard" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to Leaderboard</Link>
        </div>
      </section>
    </main>
  );
}
'@

# On-Site page (Header gives Home button)
$App_OnSite = @'
"use client";
import { Header } from "__IMPORT__";
export default function OnSitePage() {
  return (
    <main className="min-h-screen bg-neutral-50">
      <Header title="On-Site" />
      <section className="mx-auto max-w-5xl px-4 py-6">
        <p className="text-sm text-neutral-600">On-Site page.</p>
      </section>
    </main>
  );
}
'@

$Pages_OnSite = @'
import { Header } from "__IMPORT__";
export default function OnSitePage() {
  return (
    <main className="min-h-screen bg-neutral-50">
      <Header title="On-Site" />
      <section className="mx-auto max-w-5xl px-4 py-6">
        <p className="text-sm text-neutral-600">On-Site page.</p>
      </section>
    </main>
  );
}
'@

# Blind Taste page (Header gives Home button)
$App_Blind = @'
"use client";
import { Header } from "__IMPORT__";
export default function BlindTastePage() {
  return (
    <main className="min-h-screen bg-neutral-50">
      <Header title="Blind Taste" />
      <section className="mx-auto max-w-5xl px-4 py-6">
        <p className="text-sm text-neutral-600">Blind Taste page.</p>
      </section>
    </main>
  );
}
'@

$Pages_Blind = @'
import { Header } from "__IMPORT__";
export default function BlindTastePage() {
  return (
    <main className="min-h-screen bg-neutral-50">
      <Header title="Blind Taste" />
      <section className="mx-auto max-w-5xl px-4 py-6">
        <p className="text-sm text-neutral-600">Blind Taste page.</p>
      </section>
    </main>
  );
}
'@

# Leaderboard page (Header gives Home button)
$App_Leader = @'
"use client";
import { Header } from "__IMPORT__";
export default function LeaderboardPage() {
  return (
    <main className="min-h-screen bg-neutral-50">
      <Header title="Leaderboard" />
      <section className="mx-auto max-w-5xl px-4 py-6">
        <p className="text-sm text-neutral-600">Leaderboard page.</p>
      </section>
    </main>
  );
}
'@

$Pages_Leader = @'
import { Header } from "__IMPORT__";
export default function LeaderboardPage() {
  return (
    <main className="min-h-screen bg-neutral-50">
      <Header title="Leaderboard" />
      <section className="mx-auto max-w-5xl px-4 py-6">
        <p className="text-sm text-neutral-600">Leaderboard page.</p>
      </section>
    </main>
  );
}
'@

# --- 4) Write files for the detected router (handles src/ prefix automatically) ---
if($UseApp){
  Step "Using App Router (app/*)"
  Ensure-Dir $AppDir
  # Landing
  $landing = $App_Landing.Replace('__IMPORT__', $Import_Header_App_Landing)
  Write-File (Join-Path $AppDir "page.tsx") $landing
  # On-Site
  Ensure-Dir (Join-Path $AppDir "on-site")
  $onsite = $App_OnSite.Replace('__IMPORT__', $Import_Header_App_Subpage)
  Write-File (Join-Path $AppDir "on-site\page.tsx") $onsite
  # Blind Taste
  Ensure-Dir (Join-Path $AppDir "blind-taste")
  $blind = $App_Blind.Replace('__IMPORT__', $Import_Header_App_Subpage)
  Write-File (Join-Path $AppDir "blind-taste\page.tsx") $blind
  # Leaderboard
  Ensure-Dir (Join-Path $AppDir "leaderboard")
  $leader = $App_Leader.Replace('__IMPORT__', $Import_Header_App_Subpage)
  Write-File (Join-Path $AppDir "leaderboard\page.tsx") $leader
}
else{
  Step "Using Pages Router (pages/*)"
  Ensure-Dir $PagesDir
  # Landing
  $landing = $Pages_Landing.Replace('__IMPORT__', $Import_Header_Pages)
  Write-File (Join-Path $PagesDir "index.tsx") $landing
  # On-Site
  $onsite = $Pages_OnSite.Replace('__IMPORT__', $Import_Header_Pages)
  Write-File (Join-Path $PagesDir "on-site.tsx") $onsite
  # Blind Taste
  $blind = $Pages_Blind.Replace('__IMPORT__', $Import_Header_Pages)
  Write-File (Join-Path $PagesDir "blind-taste.tsx") $blind
  # Leaderboard
  $leader = $Pages_Leader.Replace('__IMPORT__', $Import_Header_Pages)
  Write-File (Join-Path $PagesDir "leaderboard.tsx") $leader
}

# --- 5) Verify results (fail loudly if buttons not present) ---
Step "Verifying files"
$HeaderPath = Join-Path $CompDir "Header.tsx"
if(-not (Test-Path $HeaderPath)){ throw "Header not found at $HeaderPath" }
$headerText = Get-Content $HeaderPath -Raw
if(-not ($headerText -match 'href="/"')){ throw "Header does not contain Home button href='/'" }

if($UseApp){
  $LandingPath = Join-Path $AppDir "page.tsx"
  $OnSitePath  = Join-Path $AppDir "on-site\page.tsx"
  $BlindPath   = Join-Path $AppDir "blind-taste\page.tsx"
  $LeaderPath  = Join-Path $AppDir "leaderboard\page.tsx"
}else{
  $LandingPath = Join-Path $PagesDir "index.tsx"
  $OnSitePath  = Join-Path $PagesDir "on-site.tsx"
  $BlindPath   = Join-Path $PagesDir "blind-taste.tsx"
  $LeaderPath  = Join-Path $PagesDir "leaderboard.tsx"
}

foreach($p in @($LandingPath,$OnSitePath,$BlindPath,$LeaderPath)){
  if(-not (Test-Path $p)){ throw "Missing expected page: $p" }
}

$landingText = Get-Content $LandingPath -Raw
$needs = @('Go to On-Site','Go to Blind Taste','Go to Leaderboard')
foreach($n in $needs){ if(-not ($landingText -match [regex]::Escape($n))){ throw "Landing page missing button text: $n" } }

Ok "All buttons and pages are in place."
Step "Done"
Write-Host "Start the app as you normally do (e.g., Ctrl+F5). Landing has 3 'Go to' buttons; subpages show a Home button." -ForegroundColor Yellow


