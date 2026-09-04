"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Shell, UnauthorizedBanner } from "@/components/Shell";
import { ApiError, api, getToken } from "@/lib/api";

type Dashboard = {
  activeRides: number;
  completedToday: number;
  pendingDrivers: number;
  openTickets: number;
  sosOpen: number;
  passengerCount: number;
  driverCount: number;
};

export default function DashboardPage() {
  const router = useRouter();
  const [data, setData] = useState<Dashboard | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [unauthorized, setUnauthorized] = useState(false);

  useEffect(() => {
    const token = getToken();
    if (!token) {
      router.replace("/");
      return;
    }
    api<Dashboard>("/admin/dashboard", { token })
      .then(setData)
      .catch((e) => {
        if (e instanceof ApiError && e.isUnauthorized) {
          setUnauthorized(true);
        }
        setError(e instanceof Error ? e.message : "Failed");
      });
  }, [router]);

  const cards = data
    ? [
        { label: "Active rides", value: data.activeRides },
        { label: "Completed today", value: data.completedToday },
        { label: "Pending drivers", value: data.pendingDrivers },
        { label: "Open tickets", value: data.openTickets },
        { label: "Open SOS", value: data.sosOpen },
        { label: "Passengers", value: data.passengerCount },
        { label: "Approved drivers", value: data.driverCount },
      ]
    : [];

  return (
    <Shell>
      <h1 className="font-display text-4xl text-[var(--max-forest)]">Dashboard</h1>
      <p className="text-black/50 mt-1">Live snapshot · MaX Ride Sri Lanka</p>
      {unauthorized && <UnauthorizedBanner message={error || "Unauthorized"} />}
      {error && !unauthorized && <p className="text-red-600 mt-4">{error}</p>}
      <div className="mt-8 grid grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-4">
        {cards.map((c) => (
          <div
            key={c.label}
            className="rounded-2xl bg-white/80 backdrop-blur p-5 border border-black/5"
          >
            <p className="text-sm text-black/50">{c.label}</p>
            <p className="text-3xl font-semibold mt-2 text-[var(--max-forest)]">
              {c.value}
            </p>
          </div>
        ))}
      </div>
    </Shell>
  );
}
