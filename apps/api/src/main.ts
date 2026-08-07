import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import {
  ExpressAdapter,
  NestExpressApplication,
} from '@nestjs/platform-express';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(
    AppModule,
    new ExpressAdapter(),
  );
  const config = app.get(ConfigService);
  const prefix = config.get('API_PREFIX', 'api/v1');
  const port = Number(config.get('PORT', 4000));

  app.setGlobalPrefix(prefix);
  app.enableCors({
    origin: (config.get('CORS_ORIGINS') || '*').split(','),
    credentials: true,
  });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  const swagger = new DocumentBuilder()
    .setTitle('MaX Ride API')
    .setDescription('Sri Lanka ride-hailing platform API (LKR)')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, swagger);
  SwaggerModule.setup('docs', app, document);

  await app.listen(port);
  Logger.log(`MaX Ride API listening on http://localhost:${port}/${prefix}`);
  Logger.log(`Swagger docs: http://localhost:${port}/docs`);
}
bootstrap();
