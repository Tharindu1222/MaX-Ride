"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Shell } from "@/components/Shell";
import { api, getToken } from "@/lib/api";

export default function ReportsPage() {
  const router = useRouter();
  const [data, setData] = useState<any>(null);

  useEffect(() => {
    const token = getToken();
    if (!token) return void router.replace("/");
    api("/admin/reports", { token }).then(setData).catch(console.error);
  }, [router]);

  return (
    <Shell>
      <h1 className="font-display text-3xl text-[var(--max-forest)]">Reports</h1>
      <pre className="mt-6 bg-white/80 rounded-xl p-4 text-sm overflow-auto">
        {JSON.stringify(data, null, 2)}
      </pre>
    </Shell>
  );
}
