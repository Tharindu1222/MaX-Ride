"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Shell } from "@/components/Shell";
import { api, getToken } from "@/lib/api";

export default function AuditPage() {
  const router = useRouter();
  const [rows, setRows] = useState<any[]>([]);

  useEffect(() => {
    const token = getToken();
    if (!token) return void router.replace("/");
    api<any[]>("/admin/audit", { token }).then(setRows).catch(console.error);
  }, [router]);

  return (
    <Shell>
      <h1 className="font-display text-3xl text-[var(--max-forest)]">Audit log</h1>
      <div className="mt-6 space-y-2">
        {rows.map((a) => (
          <div key={a.id} className="bg-white/80 rounded-xl p-3 text-sm">
            <span className="font-semibold">{a.action}</span> · {a.entityType}{" "}
            {a.entityId} · {new Date(a.createdAt).toLocaleString()}
          </div>
        ))}
      </div>
    </Shell>
  );
}
