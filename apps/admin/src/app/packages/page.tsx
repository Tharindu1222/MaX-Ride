"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Shell } from "@/components/Shell";
import { api, getToken } from "@/lib/api";

type Package = {
  id: string;
  name: string;
  description?: string;
  packageType: "HOURLY" | "DAILY" | "FIXED_TRIP";
  vehicleCategoryId?: string;
  durationHours?: number;
  includedKm?: number;
  price: string | number;
  isActive: boolean;
  category?: { name: string };
};

const emptyForm = {
  name: "",
  description: "",
  packageType: "HOURLY" as const,
  durationHours: 2,
  includedKm: 40,
  price: 4500,
  isActive: true,
};

export default function PackagesPage() {
  const router = useRouter();
  const [packages, setPackages] = useState<Package[]>([]);
  const [form, setForm] = useState({ ...emptyForm, id: "" as string });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function load(token: string) {
    const rows = await api<Package[]>("/admin/packages", { token });
    setPackages(rows);
  }

  useEffect(() => {
    const token = getToken();
    if (!token) return void router.replace("/");
    load(token).catch((e) => setError(String(e)));
  }, [router]);

  function edit(p: Package) {
    setForm({
      id: p.id,
      name: p.name,
      description: p.description ?? "",
      packageType: p.packageType,
      durationHours: p.durationHours ?? 0,
      includedKm: p.includedKm ?? 0,
      price: Number(p.price),
      isActive: p.isActive,
    });
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    const token = getToken();
    if (!token) return;
    setSaving(true);
    setError(null);
    try {
      await api("/admin/packages", {
        method: "POST",
        token,
        body: {
          id: form.id || undefined,
          name: form.name,
          description: form.description || undefined,
          packageType: form.packageType,
          durationHours: form.durationHours || undefined,
          includedKm: form.includedKm || undefined,
          price: Number(form.price),
          isActive: form.isActive,
        },
      });
      setForm({ ...emptyForm, id: "" });
      await load(token);
    } catch (err) {
      setError(String(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Shell>
      <h1 className="font-display text-3xl text-[var(--max-forest)]">
        Rental packages
      </h1>
      <p className="mt-2 text-sm text-black/60">
        Hourly, daily, and fixed-trip packages shown in the passenger app.
      </p>

      <form
        onSubmit={onSubmit}
        className="mt-6 bg-white/80 rounded-xl p-4 grid gap-3 md:grid-cols-2"
      >
        <input
          className="rounded-lg border px-3 py-2"
          placeholder="Name"
          value={form.name}
          onChange={(e) => setForm({ ...form, name: e.target.value })}
          required
        />
        <select
          className="rounded-lg border px-3 py-2"
          value={form.packageType}
          onChange={(e) =>
            setForm({
              ...form,
              packageType: e.target.value as typeof form.packageType,
            })
          }
        >
          <option value="HOURLY">Hourly</option>
          <option value="DAILY">Daily</option>
          <option value="FIXED_TRIP">Fixed trip</option>
        </select>
        <input
          className="rounded-lg border px-3 py-2"
          placeholder="Description"
          value={form.description}
          onChange={(e) => setForm({ ...form, description: e.target.value })}
        />
        <input
          type="number"
          className="rounded-lg border px-3 py-2"
          placeholder="Price LKR"
          value={form.price}
          onChange={(e) => setForm({ ...form, price: Number(e.target.value) })}
          required
        />
        <input
          type="number"
          className="rounded-lg border px-3 py-2"
          placeholder="Duration hours"
          value={form.durationHours}
          onChange={(e) =>
            setForm({ ...form, durationHours: Number(e.target.value) })
          }
        />
        <input
          type="number"
          className="rounded-lg border px-3 py-2"
          placeholder="Included km"
          value={form.includedKm}
          onChange={(e) =>
            setForm({ ...form, includedKm: Number(e.target.value) })
          }
        />
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.isActive}
            onChange={(e) => setForm({ ...form, isActive: e.target.checked })}
          />
          Active
        </label>
        <button
          type="submit"
          disabled={saving}
          className="rounded-xl bg-[var(--max-forest)] text-white font-semibold py-2.5"
        >
          {saving ? "Saving…" : form.id ? "Update package" : "Add package"}
        </button>
        {error && <p className="text-sm text-red-600 md:col-span-2">{error}</p>}
      </form>

      <div className="mt-6 space-y-3">
        {packages.map((p) => (
          <button
            key={p.id}
            type="button"
            onClick={() => edit(p)}
            className="w-full text-left bg-white/80 rounded-xl p-4 hover:bg-white"
          >
            <p className="font-semibold">
              {p.name} · {p.packageType}
              {!p.isActive && (
                <span className="ml-2 text-xs text-black/40">inactive</span>
              )}
            </p>
            <p className="text-sm text-black/60">
              LKR {p.price}
              {p.durationHours != null ? ` · ${p.durationHours}h` : ""}
              {p.includedKm != null ? ` · ${p.includedKm} km` : ""}
              {p.category?.name ? ` · ${p.category.name}` : ""}
            </p>
          </button>
        ))}
      </div>
    </Shell>
  );
}
