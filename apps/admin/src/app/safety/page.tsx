"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Shell } from "@/components/Shell";
import { api, getToken } from "@/lib/api";

export default function SafetyPage() {
  const router = useRouter();
  const [rows, setRows] = useState<any[]>([]);

  useEffect(() => {
    const token = getToken();
    if (!token) return void router.replace("/");
    api<any[]>("/safety/incidents", { token }).then(setRows).catch(console.error);
  }, [router]);

  return (
    <Shell>
      <h1 className="font-display text-3xl text-[var(--max-forest)]">Safety / SOS</h1>
      <div className="mt-6 space-y-2">
        {rows.map((i) => (
          <div key={i.id} className="bg-white/80 rounded-xl p-4 border-l-4 border-[var(--max-coral)]">
            <p className="font-semibold">
              {i.level} · {i.status}
            </p>
            <p className="text-sm text-black/60">
              Ride {i.rideId || "—"} · {i.notes}
            </p>
          </div>
        ))}
        {!rows.length && <p className="text-black/50">No incidents</p>}
      </div>
    </Shell>
  );
}
