"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Shell, UnauthorizedBanner } from "@/components/Shell";
import { ApiError, api, getToken, logoutAndRedirect } from "@/lib/api";

export default function RidesPage() {
  const router = useRouter();
  const [rides, setRides] = useState<any[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [unauthorized, setUnauthorized] = useState(false);

  async function load(token: string) {
    const data = await api<any[]>("/admin/rides/live", { token });
    setRides(data);
    setError(null);
    setUnauthorized(false);
  }

  function handleErr(e: unknown) {
    if (e instanceof ApiError && e.isUnauthorized) {
      setUnauthorized(true);
      setError(e.message);
      return;
    }
    setError(e instanceof Error ? e.message : "Failed to load rides");
  }

  useEffect(() => {
    const token = getToken();
    if (!token) {
      router.replace("/");
      return;
    }
    load(token).catch(handleErr);
    const t = setInterval(() => {
      const tok = getToken();
      if (!tok) {
        logoutAndRedirect();
        return;
      }
      load(tok).catch(() => undefined);
    }, 5000);
    return () => clearInterval(t);
  }, [router]);

  async function cancel(id: string) {
    const token = getToken();
    if (!token) return logoutAndRedirect();
    try {
      await api(`/admin/rides/${id}/cancel`, {
        method: "POST",
        token,
        body: JSON.stringify({ reason: "Admin cancelled" }),
      });
      await load(token);
    } catch (e) {
      handleErr(e);
    }
  }

  return (
    <Shell>
      <h1 className="font-display text-3xl text-[var(--max-forest)]">Live rides</h1>
      {unauthorized && <UnauthorizedBanner message={error || "Unauthorized"} />}
      {error && !unauthorized && <p className="text-red-600 mt-3">{error}</p>}
      <div className="mt-6 space-y-3">
        {rides.map((r) => (
          <div
            key={r.id}
            className="bg-white/80 rounded-xl p-4 flex justify-between gap-4"
          >
            <div>
              <p className="font-semibold">
                {r.rideNumber} · {r.status}
              </p>
              <p className="text-sm text-black/60">
                {r.pickupAddress} → {r.dropoffAddress}
              </p>
              <p className="text-sm mt-1">
                Passenger: {r.passenger?.user?.phoneNumber} · Driver:{" "}
                {r.driver?.user?.fullName || "—"}
              </p>
            </div>
            <button
              onClick={() => cancel(r.id)}
              className="text-sm text-[var(--max-coral)] self-start"
            >
              Cancel
            </button>
          </div>
        ))}
        {!rides.length && !unauthorized && (
          <p className="text-black/50">No active rides</p>
        )}
      </div>
    </Shell>
  );
}
