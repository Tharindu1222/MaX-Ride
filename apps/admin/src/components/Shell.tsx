"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { clearToken, logoutAndRedirect } from "@/lib/api";

const links = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/rides", label: "Live rides" },
  { href: "/drivers", label: "Drivers" },
  { href: "/passengers", label: "Passengers" },
  { href: "/pricing", label: "Pricing" },
  { href: "/promos", label: "Promos" },
  { href: "/support", label: "Support" },
  { href: "/safety", label: "Safety" },
  { href: "/audit", label: "Audit" },
  { href: "/reports", label: "Reports" },
];

export function Shell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();

  function signOut() {
    clearToken();
    router.replace("/");
  }

  return (
    <div className="min-h-screen grid grid-cols-[240px_1fr]">
      <aside className="bg-[var(--max-forest)] text-white p-6 flex flex-col gap-6 sticky top-0 h-screen">
        <div>
          <p className="font-display text-2xl font-semibold tracking-tight text-[var(--max-lime)]">
            MaX Ride
          </p>
          <p className="text-sm text-white/60 mt-1">Operations · LKR</p>
        </div>

        <button
          type="button"
          onClick={signOut}
          className="w-full rounded-xl bg-[var(--max-lime)] text-[var(--max-ink)] font-semibold text-sm py-2.5 hover:brightness-105 transition"
        >
          Log out
        </button>

        <nav className="flex flex-col gap-1 overflow-y-auto flex-1">
          {links.map((l) => {
            const active = pathname.startsWith(l.href);
            return (
              <Link
                key={l.href}
                href={l.href}
                className={`rounded-lg px-3 py-2 text-sm transition ${
                  active
                    ? "bg-white/15 text-[var(--max-lime)]"
                    : "text-white/80 hover:bg-white/10"
                }`}
              >
                {l.label}
              </Link>
            );
          })}
        </nav>

        <button
          type="button"
          onClick={signOut}
          className="w-full rounded-xl border border-white/25 text-white/90 text-sm py-2.5 hover:bg-white/10 transition"
        >
          Sign out
        </button>
      </aside>
      <main className="p-8 bg-[linear-gradient(160deg,#f2efe6_0%,#e4ebe6_50%,#f7f4ec_100%)] min-h-screen">
        {children}
      </main>
    </div>
  );
}

/** Banner used when a page hits 401 / session expired */
export function UnauthorizedBanner({ message }: { message?: string }) {
  return (
    <div className="mt-4 rounded-xl border border-red-200 bg-red-50 p-4 flex flex-wrap items-center justify-between gap-3">
      <div>
        <p className="font-semibold text-red-700">
          {message || "Unauthorized — your session expired or is invalid."}
        </p>
        <p className="text-sm text-red-600/80 mt-1">
          Log out and sign in again with +94770000000 / admin123
        </p>
      </div>
      <button
        type="button"
        onClick={logoutAndRedirect}
        className="rounded-lg bg-[var(--max-forest)] text-white px-4 py-2 text-sm font-semibold"
      >
        Log out
      </button>
    </div>
  );
}
