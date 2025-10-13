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
