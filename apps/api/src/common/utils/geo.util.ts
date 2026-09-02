/** Sri Lanka bounding box (matches passenger/driver map camera lock). */
export function isInSriLanka(lat: number, lng: number): boolean {
  return lat >= 5.8 && lat <= 9.9 && lng >= 79.4 && lng <= 82.1;
}

/** Haversine distance in meters between two WGS84 points. */
export function distanceMeters(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

export function estimateDurationSeconds(distanceM: number): number {
  // ~25 km/h average urban speed
  const mps = 25_000 / 3600;
  return Math.max(60, Math.round(distanceM / mps));
}

export function generateRideNumber(): string {
  const ts = Date.now().toString(36).toUpperCase();
  const rand = Math.floor(Math.random() * 10000)
    .toString()
    .padStart(4, '0');
  return `MX${ts}${rand}`;
}

export function generateStartPin(): string {
  return Math.floor(1000 + Math.random() * 9000).toString();
}

export function roundMoney(n: number): number {
  return Math.round(n * 100) / 100;
}
