"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Shell } from "@/components/Shell";
import { api, getToken } from "@/lib/api";

export default function DriversPage() {
  const router = useRouter();
  const [drivers, setDrivers] = useState<any[]>([]);

  async function load(token: string) {
    setDrivers(await api<any[]>("/admin/drivers", { token }));
  }

  useEffect(() => {
    const token = getToken();
    if (!token) return void router.replace("/");
    load(token).catch(console.error);
  }, [router]);

  async function review(id: string, decision: "APPROVED" | "REJECTED") {
    const token = getToken();
    if (!token) return;
    await api(`/admin/drivers/${id}/review`, {
      method: "PATCH",
      token,
      body: JSON.stringify({ decision }),
    });
    await load(token);
  }

  return (
    <Shell>
      <h1 className="font-display text-3xl text-[var(--max-forest)]">Drivers</h1>
      <div className="mt-6 space-y-3">
        {drivers.map((d) => (
          <div key={d.id} className="bg-white/80 rounded-xl p-4 flex justify-between items-start gap-4">
            <div>
              <p className="font-semibold">
                {d.user?.fullName || "Unnamed"} · {d.user?.phoneNumber}
              </p>
              <p className="text-sm text-black/60">
                {d.approvalStatus} · {d.operationalStatus} · ★ {d.averageRating}
              </p>
              <p className="text-xs text-black/40 mt-1">
                NIC {d.nicNumber || "—"} · License {d.drivingLicenseNumber || "—"}
              </p>
            </div>
            {d.approvalStatus !== "APPROVED" && (
              <div className="flex gap-2">
                <button
                  className="px-3 py-1 rounded-lg bg-[var(--max-forest)] text-white text-sm"
                  onClick={() => review(d.id, "APPROVED")}
                >
                  Approve
                </button>
                <button
                  className="px-3 py-1 rounded-lg bg-[var(--max-coral)] text-white text-sm"
                  onClick={() => review(d.id, "REJECTED")}
                >
                  Reject
                </button>
              </div>
            )}
          </div>
        ))}
      </div>
    </Shell>
  );
}
