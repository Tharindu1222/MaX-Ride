"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Shell } from "@/components/Shell";
import { api, getToken } from "@/lib/api";

export default function PassengersPage() {
  const router = useRouter();
  const [rows, setRows] = useState<any[]>([]);

  useEffect(() => {
    const token = getToken();
    if (!token) return void router.replace("/");
    api<any[]>("/admin/passengers", { token }).then(setRows).catch(console.error);
  }, [router]);

  return (
    <Shell>
      <h1 className="font-display text-3xl text-[var(--max-forest)]">Passengers</h1>
      <div className="mt-6 space-y-2">
        {rows.map((p) => (
          <div key={p.id} className="bg-white/80 rounded-xl p-4">
            <p className="font-semibold">{p.user?.fullName || "Passenger"}</p>
            <p className="text-sm text-black/60">{p.user?.phoneNumber} · rides {p.totalRides}</p>
          </div>
        ))}
      </div>
    </Shell>
  );
}
