const API_BASE =
  process.env.NEXT_PUBLIC_API_URL || "http://localhost:4000/api/v1";

const TOKEN_KEY = "max_ride_admin_token";
const REFRESH_KEY = "max_ride_admin_refresh";

export class ApiError extends Error {
  status: number;
  code?: string;

  constructor(message: string, status: number, code?: string) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.code = code;
  }

  get isUnauthorized() {
    return this.status === 401;
  }
}

export async function api<T>(
  path: string,
  options: RequestInit & { token?: string | null } = {},
): Promise<T> {
  const { token, ...init } = options;
  const headers: HeadersInit = {
    "Content-Type": "application/json",
    ...(init.headers || {}),
  };
  if (token) {
    (headers as Record<string, string>)["Authorization"] = `Bearer ${token}`;
  }

  const res = await fetch(`${API_BASE}${path}`, { ...init, headers });
  let json: any = null;
  try {
    json = await res.json();
  } catch {
    throw new ApiError(res.statusText || "Request failed", res.status);
  }

  if (!res.ok || json.success === false) {
    const message =
      json?.error?.message ||
      (typeof json?.message === "string" ? json.message : null) ||
      res.statusText ||
      "Request failed";
    throw new ApiError(message, res.status, json?.error?.code);
  }
  return json.data as T;
}

export function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string, refreshToken?: string) {
  localStorage.setItem(TOKEN_KEY, token);
  if (refreshToken) localStorage.setItem(REFRESH_KEY, refreshToken);
}

export function clearToken() {
  if (typeof window === "undefined") return;
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(REFRESH_KEY);
}

export function logoutAndRedirect() {
  clearToken();
  if (typeof window !== "undefined") {
    window.location.href = "/";
  }
}
