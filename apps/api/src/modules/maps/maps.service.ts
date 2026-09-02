import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { isInSriLanka } from '../../common/utils/geo.util';

export type PlaceResult = {
  id: string;
  name: string;
  address: string;
  lat: number;
  lng: number;
};

/** Demo catalog when Google Places is unavailable. */
export const MOCK_PLACES: PlaceResult[] = [
  {
    id: 'colombo-fort',
    name: 'Colombo Fort',
    address: 'Fort, Colombo 01, Sri Lanka',
    lat: 6.9344,
    lng: 79.8428,
  },
  {
    id: 'galle-face',
    name: 'Galle Face Green',
    address: 'Galle Face, Colombo 03, Sri Lanka',
    lat: 6.9271,
    lng: 79.8448,
  },
  {
    id: 'barefoot',
    name: 'Barefoot Cafe',
    address: '704 Galle Rd, Colombo 03, Sri Lanka',
    lat: 6.8915,
    lng: 79.8555,
  },
  {
    id: 'independence-square',
    name: 'Independence Square',
    address: 'Independence Ave, Colombo 07, Sri Lanka',
    lat: 6.9036,
    lng: 79.8681,
  },
  {
    id: 'kandy-city',
    name: 'Kandy City Center',
    address: 'Kandy, Sri Lanka',
    lat: 7.2906,
    lng: 80.6337,
  },
  {
    id: 'negombo-beach',
    name: 'Negombo Beach',
    address: 'Negombo, Sri Lanka',
    lat: 7.2083,
    lng: 79.8358,
  },
  {
    id: 'bamba',
    name: 'Bambalapitiya',
    address: 'Bambalapitiya, Colombo 04, Sri Lanka',
    lat: 6.8913,
    lng: 79.856,
  },
  {
    id: 'nugegoda',
    name: 'Nugegoda',
    address: 'Nugegoda, Sri Lanka',
    lat: 6.8649,
    lng: 79.8997,
  },
  {
    id: 'lotus-tower',
    name: 'Colombo Lotus Tower',
    address: 'Lotus Tower, Colombo 01, Sri Lanka',
    lat: 6.9271,
    lng: 79.8583,
  },
  {
    id: 'slave-island',
    name: 'Slave Island',
    address: 'Slave Island, Colombo 02, Sri Lanka',
    lat: 6.9219,
    lng: 79.8533,
  },
  {
    id: 'pettah',
    name: 'Pettah Market',
    address: 'Pettah, Colombo 11, Sri Lanka',
    lat: 6.9395,
    lng: 79.8561,
  },
  {
    id: 'mount-lavinia',
    name: 'Mount Lavinia Beach',
    address: 'Mount Lavinia, Sri Lanka',
    lat: 6.833,
    lng: 79.863,
  },
  {
    id: 'dehiwala',
    name: 'Dehiwala Zoo',
    address: 'Dehiwala, Sri Lanka',
    lat: 6.8567,
    lng: 79.8722,
  },
  {
    id: 'rajagiriya',
    name: 'Rajagiriya',
    address: 'Rajagiriya, Sri Lanka',
    lat: 6.9094,
    lng: 79.8915,
  },
  {
    id: 'battaramulla',
    name: 'Battaramulla',
    address: 'Battaramulla, Sri Lanka',
    lat: 6.898,
    lng: 79.922,
  },
  {
    id: 'airport',
    name: 'Bandaranaike Airport (CMB)',
    address: 'Katunayake, Sri Lanka',
    lat: 7.1808,
    lng: 79.8841,
  },
];

const COLOMBO = { lat: 6.9271, lng: 79.8612 };

@Injectable()
export class MapsService {
  private readonly logger = new Logger(MapsService.name);

  constructor(private readonly config: ConfigService) {}

  private get apiKey(): string {
    return (
      this.config.get<string>('GOOGLE_MAPS_API_KEY') ||
      this.config.get<string>('MAPS_API_KEY') ||
      process.env.GOOGLE_MAPS_API_KEY ||
      process.env.MAPS_API_KEY ||
      ''
    ).trim();
  }

  get hasGoogleKey(): boolean {
    return this.apiKey.length > 10;
  }

  popular(): { provider: string; results: PlaceResult[] } {
    return { provider: 'MOCK_MAPS', results: MOCK_PLACES };
  }

  async searchPlaces(
    q: string,
    biasLat?: number,
    biasLng?: number,
  ): Promise<{ provider: string; results: PlaceResult[]; warning?: string }> {
    const query = (q || '').trim();
    if (!query) {
      return this.popular();
    }

    if (this.hasGoogleKey) {
      try {
        const google = await this.googleTextSearch(
          query,
          biasLat ?? COLOMBO.lat,
          biasLng ?? COLOMBO.lng,
        );
        if (google.length > 0) {
          return { provider: 'GOOGLE_PLACES', results: google };
        }
        // empty status from Google — try mock filter as secondary
        this.logger.warn(`Google Places returned 0 results for "${query}"`);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        this.logger.error(`Google Places search failed: ${msg}`);
        const mock = this.mockFilter(query);
        return {
          provider: 'MOCK_MAPS',
          results: mock,
          warning: `Google search failed (${msg}). Showing local suggestions.`,
        };
      }
    }

    return { provider: 'MOCK_MAPS', results: this.mockFilter(query) };
  }

  async reverseGeocode(
    lat: number,
    lng: number,
  ): Promise<{
    provider: string;
    name: string;
    address: string;
    lat: number;
    lng: number;
  }> {
    if (this.hasGoogleKey) {
      try {
        const g = await this.googleReverse(lat, lng);
        if (g) {
          return {
            provider: 'GOOGLE_GEOCODING',
            name: g.name,
            address: g.address,
            lat,
            lng,
          };
        }
      } catch (e) {
        this.logger.warn(
          `Google reverse geocode failed: ${e instanceof Error ? e.message : e}`,
        );
      }
    }

    let best = MOCK_PLACES[0];
    let bestD = Infinity;
    for (const p of MOCK_PLACES) {
      const d = Math.hypot(p.lat - lat, p.lng - lng);
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    return {
      provider: 'MOCK_MAPS',
      name: best.name,
      address: best.address,
      lat,
      lng,
    };
  }

  private mockFilter(q: string): PlaceResult[] {
    const lower = q.toLowerCase();
    return MOCK_PLACES.filter(
      (p) =>
        p.name.toLowerCase().includes(lower) ||
        p.address.toLowerCase().includes(lower),
    );
  }

  private async googleTextSearch(
    query: string,
    lat: number,
    lng: number,
  ): Promise<PlaceResult[]> {
    // Prefer Text Search — returns name, address, coordinates in one call.
    // Enable: Places API (and billing) on the Google Cloud project for this key.
    const params = new URLSearchParams({
      query: `${query} Sri Lanka`,
      location: `${lat},${lng}`,
      radius: '80000',
      region: 'lk',
      language: 'en',
      key: this.apiKey,
    });
    const url = `https://maps.googleapis.com/maps/api/place/textsearch/json?${params}`;
    const res = await fetch(url);
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }
    const body = (await res.json()) as {
      status: string;
      error_message?: string;
      results?: Array<{
        place_id?: string;
        name?: string;
        formatted_address?: string;
        geometry?: { location?: { lat: number; lng: number } };
      }>;
    };

    if (body.status === 'ZERO_RESULTS') {
      return [];
    }
    if (body.status !== 'OK' && body.status !== 'ZERO_RESULTS') {
      throw new Error(body.error_message || body.status);
    }

    return (body.results || [])
      .filter((r) => r.geometry?.location)
      .filter((r) =>
        isInSriLanka(r.geometry!.location!.lat, r.geometry!.location!.lng),
      )
      .slice(0, 15)
      .map((r) => ({
        id: r.place_id || `g-${r.geometry!.location!.lat}-${r.geometry!.location!.lng}`,
        name: r.name || r.formatted_address || 'Place',
        address: r.formatted_address || r.name || '',
        lat: r.geometry!.location!.lat,
        lng: r.geometry!.location!.lng,
      }));
  }

  private async googleReverse(
    lat: number,
    lng: number,
  ): Promise<{ name: string; address: string } | null> {
    const params = new URLSearchParams({
      latlng: `${lat},${lng}`,
      language: 'en',
      region: 'lk',
      result_type: 'street_address|route|premise|point_of_interest|locality',
      key: this.apiKey,
    });
    const url = `https://maps.googleapis.com/maps/api/geocode/json?${params}`;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const body = (await res.json()) as {
      status: string;
      error_message?: string;
      results?: Array<{
        formatted_address?: string;
        address_components?: Array<{ long_name: string; types: string[] }>;
      }>;
    };
    if (body.status !== 'OK' || !body.results?.length) {
      if (body.status !== 'ZERO_RESULTS') {
        throw new Error(body.error_message || body.status);
      }
      return null;
    }
    const top = body.results[0];
    const address = top.formatted_address || `${lat.toFixed(5)}, ${lng.toFixed(5)}`;
    const nameComp =
      top.address_components?.find((c) =>
        c.types.some((t) =>
          ['point_of_interest', 'premise', 'route', 'neighborhood', 'sublocality'].includes(
            t,
          ),
        ),
      )?.long_name || address.split(',')[0];
    return { name: nameComp, address };
  }

  async directions(
    originLat: number,
    originLng: number,
    destLat: number,
    destLng: number,
  ): Promise<{
    provider: string;
    distanceMeters: number;
    durationSeconds: number;
    distanceText: string;
    durationText: string;
    points: Array<{ lat: number; lng: number }>;
  }> {
    const fallback = () => {
      const dist = this.haversineMeters(originLat, originLng, destLat, destLng);
      return {
        provider: 'STRAIGHT_LINE',
        distanceMeters: Math.round(dist),
        durationSeconds: Math.max(60, Math.round((dist / 1000 / 25) * 3600)),
        distanceText: dist >= 1000 ? `${(dist / 1000).toFixed(1)} km` : `${Math.round(dist)} m`,
        durationText: `${Math.max(1, Math.round(dist / 1000 / 25 * 60))} min`,
        points: [
          { lat: originLat, lng: originLng },
          { lat: destLat, lng: destLng },
        ],
      };
    };

    if (!this.hasGoogleKey) {
      return fallback();
    }

    try {
      const params = new URLSearchParams({
        origin: `${originLat},${originLng}`,
        destination: `${destLat},${destLng}`,
        mode: 'driving',
        region: 'lk',
        language: 'en',
        key: this.apiKey,
      });
      const url = `https://maps.googleapis.com/maps/api/directions/json?${params}`;
      const res = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const body = (await res.json()) as {
        status: string;
        error_message?: string;
        routes?: Array<{
          overview_polyline?: { points?: string };
          legs?: Array<{
            distance?: { value?: number; text?: string };
            duration?: { value?: number; text?: string };
          }>;
        }>;
      };

      if (body.status !== 'OK' || !body.routes?.length) {
        this.logger.warn(
          `Directions empty: ${body.error_message || body.status}`,
        );
        return fallback();
      }

      const route = body.routes[0];
      const leg = route.legs?.[0];
      const encoded = route.overview_polyline?.points || '';
      const points = encoded
        ? this.decodePolyline(encoded)
        : [
            { lat: originLat, lng: originLng },
            { lat: destLat, lng: destLng },
          ];

      return {
        provider: 'GOOGLE_DIRECTIONS',
        distanceMeters: leg?.distance?.value ?? 0,
        durationSeconds: leg?.duration?.value ?? 0,
        distanceText: leg?.distance?.text || '',
        durationText: leg?.duration?.text || '',
        points,
      };
    } catch (e) {
      this.logger.warn(
        `Directions failed: ${e instanceof Error ? e.message : e}`,
      );
      return fallback();
    }
  }

  private haversineMeters(
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

  /** Google encoded polyline algorithm → list of lat/lng. */
  private decodePolyline(encoded: string): Array<{ lat: number; lng: number }> {
    let index = 0;
    const len = encoded.length;
    let lat = 0;
    let lng = 0;
    const path: Array<{ lat: number; lng: number }> = [];

    while (index < len) {
      let result = 0;
      let shift = 0;
      let b: number;
      do {
        b = encoded.charCodeAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      const dlat = (result & 1) !== 0 ? ~(result >> 1) : result >> 1;
      lat += dlat;

      result = 0;
      shift = 0;
      do {
        b = encoded.charCodeAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      const dlng = (result & 1) !== 0 ? ~(result >> 1) : result >> 1;
      lng += dlng;

      path.push({ lat: lat / 1e5, lng: lng / 1e5 });
    }
    return path;
  }
}
