import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/roles.decorator';
import { IsNumberString, IsOptional, IsString } from 'class-validator';
import { MapsService } from './maps.service';

class SearchQuery {
  @IsOptional()
  @IsString()
  q?: string;

  @IsOptional()
  @IsNumberString()
  lat?: string;

  @IsOptional()
  @IsNumberString()
  lng?: string;
}

class ReverseQuery {
  @IsNumberString()
  lat!: string;

  @IsNumberString()
  lng!: string;
}

class DirectionsQuery {
  @IsNumberString()
  originLat!: string;

  @IsNumberString()
  originLng!: string;

  @IsNumberString()
  destLat!: string;

  @IsNumberString()
  destLng!: string;
}

@ApiTags('maps')
@Controller('maps')
export class MapsController {
  constructor(private readonly maps: MapsService) {}

  @Public()
  @Get('places')
  search(@Query() query: SearchQuery) {
    return this.maps.searchPlaces(
      query.q || '',
      query.lat ? Number(query.lat) : undefined,
      query.lng ? Number(query.lng) : undefined,
    );
  }

  @Public()
  @Get('geocode/reverse')
  reverse(@Query() query: ReverseQuery) {
    return this.maps.reverseGeocode(Number(query.lat), Number(query.lng));
  }

  @Public()
  @Get('directions')
  directions(@Query() query: DirectionsQuery) {
    return this.maps.directions(
      Number(query.originLat),
      Number(query.originLng),
      Number(query.destLat),
      Number(query.destLng),
    );
  }

  @Public()
  @Get('places/popular')
  popular() {
    return this.maps.popular();
  }

  @Public()
  @Get('status')
  status() {
    return {
      googlePlacesEnabled: this.maps.hasGoogleKey,
      note: this.maps.hasGoogleKey
        ? 'GOOGLE_MAPS_API_KEY is set. Enable Places API, Geocoding API, Directions API in Google Cloud.'
        : 'No GOOGLE_MAPS_API_KEY — using mock places only.',
    };
  }
}
