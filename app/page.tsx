import Link from "next/link";
import { Header } from "../components/Header";

export default function LandingPage() {
  return (
    <main className="min-h-screen bg-neutral-50">
      <Header title="Whole Hog" />
      <section className="mx-auto max-w-5xl px-4 py-6">
{/* WHOLEHOG_LEADERBOARD_BTN_START */}
<div className="mt-4" data-wholehog-leaderboard-btn>
  <Link href="/leaderboard" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">
    Go to Leaderboard
  </Link>
</div>
{/* WHOLEHOG_LEADERBOARD_BTN_END */}

        <div className="flex flex-wrap items-center gap-3">
          <Link href="/on-site" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to On-Site</Link>
          <Link href="/blind-taste" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to Blind Taste</Link>
          <Link href="/leaderboard" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to Leaderboard</Link>
        </div>
      </section>
    </main>
  );
}

