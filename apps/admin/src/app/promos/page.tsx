"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Shell } from "@/components/Shell";
import { api, getToken } from "@/lib/api";

export default function PromosPage() {
  const router = useRouter();
  const [promos, setPromos] = useState<any[]>([]);
  const [code, setCode] = useState("WELCOME20");

  async function load(token: string) {
    setPromos(await api<any[]>("/admin/promos", { token }));
  }

  useEffect(() => {
    const token = getToken();
    if (!token) return void router.replace("/");
    load(token).catch(console.error);
  }, [router]);

  async function create(e: FormEvent) {
    e.preventDefault();
    const token = getToken();
    if (!token) return;
    const now = new Date();
    const later = new Date(Date.now() + 90 * 24 * 3600 * 1000);
    await api("/admin/promos", {
      method: "POST",
      token,
      body: JSON.stringify({
        code,
        description: "Admin created promo",
        discountType: "PERCENT",
        discountValue: 20,
        maxDiscount: 500,
        minFare: 300,
        usageLimit: 1000,
        validFrom: now.toISOString(),
        validTo: later.toISOString(),
      }),
    });
    await load(token);
  }

  return (
    <Shell>
      <h1 className="font-display text-3xl text-[var(--max-forest)]">Promotions</h1>
      <form onSubmit={create} className="mt-4 flex gap-2">
        <input
          className="rounded-lg px-3 py-2 bg-white"
          value={code}
          onChange={(e) => setCode(e.target.value)}
        />
        <button className="rounded-lg bg-[var(--max-forest)] text-white px-4">
          Create 20% promo
        </button>
      </form>
      <div className="mt-6 space-y-2">
        {promos.map((p) => (
          <div key={p.id} className="bg-white/80 rounded-xl p-4">
            <p className="font-semibold">{p.code}</p>
            <p className="text-sm text-black/60">
              {p.discountType} {p.discountValue} · used {p.usedCount}
              {p.usageLimit != null ? `/${p.usageLimit}` : ""}
            </p>
          </div>
        ))}
      </div>
    </Shell>
  );
}
