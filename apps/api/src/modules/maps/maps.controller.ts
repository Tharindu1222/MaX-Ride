import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/roles.decorator';
import { IsNumberString, IsOptional, IsString } from 'class-validator';

/** Mock Google Places / Geocoding for local development. */
const PLACES = [
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
];

class SearchQuery {
  @IsString()
  q!: string;
}

class ReverseQuery {
  @IsNumberString()
  lat!: string;

  @IsNumberString()
  lng!: string;
}

@ApiTags('maps')
@Controller('maps')
export class MapsController {
  @Public()
  @Get('places')
  search(@Query() query: SearchQuery) {
    const q = (query.q || '').toLowerCase();
    const results = PLACES.filter(
      (p) =>
        p.name.toLowerCase().includes(q) ||
        p.address.toLowerCase().includes(q),
    );
    return { provider: 'MOCK_MAPS', results };
  }

  @Public()
  @Get('geocode/reverse')
  reverse(@Query() query: ReverseQuery) {
    const lat = Number(query.lat);
    const lng = Number(query.lng);
    let best = PLACES[0];
    let bestD = Infinity;
    for (const p of PLACES) {
      const d = Math.hypot(p.lat - lat, p.lng - lng);
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    return {
      provider: 'MOCK_MAPS',
      address: best.address,
      name: best.name,
      lat,
      lng,
    };
  }

  @Public()
  @Get('places/popular')
  popular() {
    return { provider: 'MOCK_MAPS', results: PLACES };
  }
}
