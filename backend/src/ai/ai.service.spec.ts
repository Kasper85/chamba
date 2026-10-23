import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { AiService } from './ai.service.js';

describe('AiService', () => {
  let service: AiService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AiService,
        {
          provide: ConfigService,
          useValue: {
            get: (key: string, defaultValue?: any) => {
              const mockConfig: Record<string, any> = {
                GEMINI_API_KEY: 'AIzaSy_TEST_MOCK_KEY_VALID_LENGTH_123',
                GEMINI_MODEL: 'gemini-2.5-flash',
              };
              return mockConfig[key] ?? defaultValue;
            },
          },
        },
      ],
    }).compile();

    service = module.get<AiService>(AiService);
  });

  it('debe estar definido', () => {
    expect(service).toBeDefined();
  });

  it('debe diagnosticar correctamente averías de Gasfitería con JSON estructurado', async () => {
    const result = await service.diagnose(
      'https://pub-chamba.r2.dev/diagnostics/tuberia_fuga.jpg',
      'Tubería goteando bajo lavadero de cocina',
    );

    expect(result).toBeDefined();
    expect(result.category).toBe('Gasfitería');
    expect(result.technicalDescription).toContain('Fuga hidráulica');
    expect(result.estimatedPriceRange.min).toBe(50);
    expect(result.estimatedPriceRange.max).toBe(65);
    expect(result.estimatedPriceRange.currency).toBe('PEN');
    expect(result.estimatedPriceRange.formatted).toBe('S/. 50 - S/. 65');
    expect(result.materialsNeeded).toContain('Cinta teflón 3/4"');
    expect(result.materialsNeeded).toContain('Trampa P de PVC 1 1/2"');
  });

  it('debe diagnosticar correctamente averías de Electricidad con JSON estructurado', async () => {
    const result = await service.diagnose(
      'https://pub-chamba.r2.dev/diagnostics/enchufe.jpg',
      'Tomacorriente chispeando en la pared de la sala',
    );

    expect(result.category).toBe('Electricidad');
    expect(result.technicalDescription).toContain('bornes de conexión');
    expect(result.estimatedPriceRange.formatted).toBe('S/. 40 - S/. 55');
    expect(result.materialsNeeded).toContain('Tomacorriente doble con tierra Ticino');
    expect(result.materialsNeeded).toContain('Cinta aislante 3M Temflex');
  });

  it('debe diagnosticar averías de Carpintería ante puertas trabadas', async () => {
    const result = await service.diagnose(
      'https://pub-chamba.r2.dev/diagnostics/puerta.jpg',
      'Puerta de madera trabada y raspando el piso',
    );

    expect(result.category).toBe('Carpintería');
    expect(result.estimatedPriceRange.min).toBe(55);
    expect(result.materialsNeeded).toContain('Bisagras de acero 3x3"');
  });

  it('debe manejar errores de la API externa de Gemini sin lanzar excepciones no controladas', async () => {
    // Espiamos callGemini para forzar un error de red / cuota
    vi.spyOn(service as any, 'callGemini').mockRejectedValueOnce(
      new Error('API key not valid / Network timeout'),
    );

    const result = await service.diagnose(
      'https://pub-chamba.r2.dev/diagnostics/humedad.jpg',
      'Pared con grieta y humedad salina',
    );

    expect(result).toBeDefined();
    expect(result.category).toBe('Pintura y Acabados');
    expect(result.materialsNeeded).toContain('Sellador antihumedad Tekno');
    expect(result.source).toBe('chamba-diagnostic-engine');
  });
});
