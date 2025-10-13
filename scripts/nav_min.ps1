# nav_min.ps1 — write simple nav files (no DB changes). Run from project root folder.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"

function Ensure-Dir($p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null } }
function Backup($p)     { if (Test-Path $p) { $t = Get-Date -Format "yyyyMMdd_HHmmss"; Copy-Item $p "$p.$t.bak" -Force } }
function WriteFile($path, [string]$content) {
  Ensure-Dir (Split-Path -Parent $path)
  Backup $path
  Set-Content -Path $path -Encoding UTF8 -Value $content
  Write-Host "wrote: $path" -ForegroundColor Green
}

# sanity check
$here = [System.IO.Path]::GetFullPath((Get-Location).Path)
if ($here -ne $Root) { throw "Run this script from: $Root (current: $here)" }
if (-not (Test-Path (Join-Path $here "package.json"))) { throw "No package.json found here. This assumes a Next.js project." }

# ---------- SHARED HEADER (Home button) ----------
$HeaderTsx = @"
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
"@

# ---------- APP ROUTER PAGES ----------
$AppLanding = @"
import Link from "next/link";
import { Header } from "../components/Header";

export default function LandingPage() {
  return (
    <main className="min-h-screen bg-neutral-50">
      <Header title="Whole Hog" />
      <section className="mx-auto max-w-5xl px-4 py-6">
        <div className="flex flex-wrap items-center gap-3">
          <Link href="/on-site" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to On-Site</Link>
          <Link href="/blind-taste" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to Blind Taste</Link>
          <Link href="/leaderboard" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to Leaderboard</Link>
        </div>
      </section>
    </main>
  );
}
"@

$AppOnSite = @"
import { Header } from "../../components/Header";

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
"@

$AppBlind = @"
import { Header } from "../../components/Header";

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
"@

$AppLeader = @"
import { Header } from "../../components/Header";

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
"@

# ---------- PAGES ROUTER PAGES ----------
$PagesLanding = @"
import Link from "next/link";
import { Header } from "../components/Header";

export default function Home() {
  return (
    <main className="min-h-screen bg-neutral-50">
      <Header title="Whole Hog" />
      <section className="mx-auto max-w-5xl px-4 py-6">
        <div className="flex flex-wrap items-center gap-3">
          <Link href="/on-site" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to On-Site</Link>
          <Link href="/blind-taste" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to Blind Taste</Link>
          <Link href="/leaderboard" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to Leaderboard</Link>
        </div>
      </section>
    </main>
  );
}
"@

$PagesOnSite = @"
import { Header } from "../components/Header";

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
"@

$PagesBlind = @"
import { Header } from "../components/Header";

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
"@

$PagesLeader = @"
import { Header } from "../components/Header";

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
"@

# ---------- WRITE FILES ----------
WriteFile (Join-Path $Root "components/Header.tsx") $HeaderTsx

# App Router
WriteFile (Join-Path $Root "app/page.tsx") $AppLanding
WriteFile (Join-Path $Root "app/on-site/page.tsx") $AppOnSite
WriteFile (Join-Path $Root "app/blind-taste/page.tsx") $AppBlind
WriteFile (Join-Path $Root "app/leaderboard/page.tsx") $AppLeader

# Pages Router
WriteFile (Join-Path $Root "pages/index.tsx") $PagesLanding
WriteFile (Join-Path $Root "pages/on-site.tsx") $PagesOnSite
WriteFile (Join-Path $Root "pages/blind-taste.tsx") $PagesBlind
WriteFile (Join-Path $Root "pages/leaderboard.tsx") $PagesLeader

Write-Host "`nAll nav pages written. Start your app as you normally do (Ctrl+F5, etc.) and check the landing page." -ForegroundColor Yellow
