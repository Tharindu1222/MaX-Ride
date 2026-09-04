"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Shell } from "@/components/Shell";
import { api, getToken } from "@/lib/api";

export default function PricingPage() {
  const router = useRouter();
  const [rules, setRules] = useState<any[]>([]);

  useEffect(() => {
    const token = getToken();
    if (!token) return void router.replace("/");
    api<any[]>("/admin/pricing", { token }).then(setRules).catch(console.error);
  }, [router]);

  return (
    <Shell>
      <h1 className="font-display text-3xl text-[var(--max-forest)]">Pricing (LKR)</h1>
      <div className="mt-6 space-y-3">
        {rules.map((r) => (
          <div key={r.id} className="bg-white/80 rounded-xl p-4">
            <p className="font-semibold">
              {r.category?.name} · {r.name}
            </p>
            <p className="text-sm text-black/60">
              Base {r.baseFare} · /km {r.perKmFare} · /min {r.perMinuteFare} · min{" "}
              {r.minimumFare} · booking {r.bookingFee} · surge {r.surgeMultiplier}x
            </p>
          </div>
        ))}
      </div>
    </Shell>
  );
}
