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
