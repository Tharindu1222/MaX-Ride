"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { api, setToken } from "@/lib/api";

export default function LoginPage() {
  const router = useRouter();
  const [phone, setPhone] = useState("+94770000000");
  const [password, setPassword] = useState("admin123");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const data = await api<{ accessToken: string; refreshToken?: string }>(
        "/auth/admin/login",
        {
          method: "POST",
          body: JSON.stringify({ phoneNumber: phone, password }),
        },
      );
      setToken(data.accessToken, data.refreshToken);
      router.push("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen grid place-items-center bg-[radial-gradient(circle_at_20%_20%,#c8f56033,transparent_40%),radial-gradient(circle_at_80%_0%,#0f3d2e22,transparent_35%),#f2efe6]">
      <form
        onSubmit={onSubmit}
        className="w-full max-w-md p-10 rounded-3xl bg-[var(--max-forest)] text-white shadow-2xl"
      >
        <p className="font-display text-4xl text-[var(--max-lime)]">MaX Ride</p>
        <p className="mt-2 text-white/70">Admin console · Sri Lanka</p>
        <div className="mt-8 space-y-4">
          <input
            className="w-full rounded-xl px-4 py-3 text-[var(--max-ink)] bg-white"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder="Phone"
          />
          <input
            type="password"
            className="w-full rounded-xl px-4 py-3 text-[var(--max-ink)] bg-white"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Password"
          />
          {error && <p className="text-[var(--max-coral)] text-sm">{error}</p>}
          <button
            type="submit"
            disabled={loading}
            className="w-full rounded-xl bg-[var(--max-lime)] text-[var(--max-ink)] font-semibold py-3"
          >
            {loading ? "Signing in…" : "Sign in"}
          </button>
        </div>
        <p className="mt-6 text-xs text-white/50">
          Default seed: +94770000000 / admin123
        </p>
      </form>
    </div>
  );
}
