"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Shell } from "@/components/Shell";
import { api, getToken } from "@/lib/api";

export default function SupportPage() {
  const router = useRouter();
  const [tickets, setTickets] = useState<any[]>([]);

  useEffect(() => {
    const token = getToken();
    if (!token) return void router.replace("/");
    api<any[]>("/support/tickets", { token }).then(setTickets).catch(console.error);
  }, [router]);

  return (
    <Shell>
      <h1 className="font-display text-3xl text-[var(--max-forest)]">Support tickets</h1>
      <div className="mt-6 space-y-2">
        {tickets.map((t) => (
          <div key={t.id} className="bg-white/80 rounded-xl p-4">
            <p className="font-semibold">
              {t.subject} · {t.status}
            </p>
            <p className="text-sm text-black/60">
              {t.category}: {t.description}
            </p>
          </div>
        ))}
        {!tickets.length && <p className="text-black/50">No tickets yet</p>}
      </div>
    </Shell>
  );
}
