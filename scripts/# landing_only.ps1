# landing_only.ps1 — update ONLY the landing page with 3 "Go to" buttons (no DB changes)
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

# --- 1) Layout detection (supports src/, app/, pages/) ---
$BaseDir   = (Test-Path (Join-Path $here "src")) ? (Join-Path $here "src") : $here
$AppDir    = Join-Path $BaseDir "app"
$PagesDir  = Join-Path $BaseDir "pages"
$CompDir   = Join-Path $BaseDir "components"
$UseApp    = (Test-Path $AppDir) -or (-not (Test-Path $PagesDir))  # prefer app if present
$HeaderExists = Test-Path (Join-Path $CompDir "Header.tsx")

# --- 2) Landing page templates (with and without Header) ---
# App Router (app/page.tsx)
$App_Landing_WithHeader = @'
import Link from "next/link";
import { Header } from "../components/Header";

export default function LandingPage() {
  return (
    <main className="min-h-screen bg-neutral-50">
      <Header title="Whole Hog" />
      <section className="mx-auto max-w-5xl px-4 py-6">
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

$App_Landing_Minimal = @'
import Link from "next/link";

export default function LandingPage() {
  return (
    <main className="min-h-screen bg-neutral-50">
      <section className="mx-auto max-w-5xl px-4 py-6">
        <h1 className="text-2xl font-bold mb-4">Whole Hog</h1>
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

# Pages Router (pages/index.tsx)
$Pages_Landing_WithHeader = @'
import Link from "next/link";
import { Header } from "../components/Header";

export default function Home() {
  return (
    <main className="min-h-screen bg-neutral-50">
      <Header title="Whole Hog" />
      <section className="mx-auto max-w-5xl px-4 py-6">
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

$Pages_Landing_Minimal = @'
import Link from "next/link";

export default function Home() {
  return (
    <main className="min-h-screen bg-neutral-50">
      <section className="mx-auto max-w-5xl px-4 py-6">
        <h1 className="text-2xl font-bold mb-4">Whole Hog</h1>
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

# --- 3) Choose landing target and content ---
if($UseApp){
  Step "Detected App Router → app/page.tsx"
  $LandingPath = Join-Path $AppDir "page.tsx"
  $Content = $HeaderExists ? $App_Landing_WithHeader : $App_Landing_Minimal
  Ensure-Dir $AppDir
} else {
  Step "Detected Pages Router → pages/index.tsx"
  $LandingPath = Join-Path $PagesDir "index.tsx"
  $Content = $HeaderExists ? $Pages_Landing_WithHeader : $Pages_Landing_Minimal
  Ensure-Dir $PagesDir
}

# --- 4) Write landing page ---
Write-File $LandingPath $Content

# --- 5) Verify it contains the three buttons ---
Step "Verifying landing page content"
$txt = Get-Content $LandingPath -Raw
$must = @('href="/on-site"','href="/blind-taste"','href="/leaderboard"')
foreach($m in $must){
  if(-not ($txt -match [regex]::Escape($m))){
    throw "Landing page missing expected link: $m"
  }
}
Ok "Landing page updated with all three buttons."

Step "Done"
Write-Host "Open your app as you normally do (Ctrl+F5 etc.). Check the landing page for the three 'Go to' buttons." -ForegroundColor Yellow

