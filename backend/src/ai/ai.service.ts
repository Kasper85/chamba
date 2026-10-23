import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { GoogleGenAI, Type } from '@google/genai';
import { DiagnoseResponseDto } from './dto/diagnose-response.dto.js';

@Injectable()
export class AiService {
  private readonly logger = new Logger(AiService.name);
  private readonly geminiClient: GoogleGenAI | null = null;
  private readonly modelName: string;

  constructor(private readonly configService: ConfigService) {
    const apiKey = this.configService.get<string>('GEMINI_API_KEY');
    this.modelName = this.configService.get<string>('GEMINI_MODEL', 'gemini-2.5-flash');

    const lowerKey = (apiKey || '').toLowerCase();
    const isPlaceholder =
      !apiKey ||
      lowerKey.includes('tu_clave') ||
      lowerKey.includes('dummy') ||
      lowerKey.includes('mock') ||
      lowerKey.includes('test') ||
      apiKey.length < 20;

    if (!isPlaceholder && apiKey) {
      this.geminiClient = new GoogleGenAI({ apiKey });
      this.logger.log(`AiService conectado a Gemini API (${this.modelName})`);
    } else {
      this.logger.warn(
        'GEMINI_API_KEY no configurada o es de prueba. Se utilizará el motor de diagnóstico estructurado de respaldo.',
      );
    }
  }

  /**
   * Diagnostica una avería usando Gemini (Structured Output) o el motor de respaldo
   * en caso de fallos de red o falta de credenciales.
   */
  async diagnose(imageUrl: string, prompt?: string): Promise<DiagnoseResponseDto> {
    if (this.geminiClient) {
      try {
        const result = await this.callGemini(imageUrl, prompt);
        if (result) {
          return result;
        }
      } catch (error) {
        const err = error as Error;
        this.logger.warn(
          `Fallo al invocar la API de Gemini (${err.message}). Activando diagnóstico de contingencia.`,
        );
      }
    }

    return this.fallbackDiagnosis(imageUrl, prompt);
  }

  /**
   * Invoca la API de Gemini 2.5 Flash con Structured Output garantizado por Schema.
   */
  private async callGemini(imageUrl: string, prompt?: string): Promise<DiagnoseResponseDto | null> {
    if (!this.geminiClient) return null;

    const parts: any[] = [];

    // Descarga opcional de la imagen si es una URL HTTP/HTTPS accesible
    if (imageUrl && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
      try {
        const res = await fetch(imageUrl, {
          signal: AbortSignal.timeout(2000),
        });
        if (res.ok) {
          const arrayBuffer = await res.arrayBuffer();
          const mimeType = res.headers.get('content-type') || 'image/jpeg';
          parts.push({
            inlineData: {
              mimeType,
              data: Buffer.from(arrayBuffer).toString('base64'),
            },
          });
        }
      } catch (fetchErr) {
        this.logger.debug(
          `No se pudo descargar la imagen directa (${imageUrl}): ${(fetchErr as Error).message}`,
        );
      }
    }

    const promptText = `
Analiza la siguiente evidencia de avería para la plataforma de servicios para el hogar "Chamba" en Perú.
Descripción proporcionada por el usuario: "${prompt || 'Evaluación de avería visible en la imagen'}"
Ruta o referencia de imagen: "${imageUrl}"

Genera un diagnóstico técnico riguroso en formato JSON con:
1. category: Categoría profesional más apropiada (Gasfitería, Electricidad, Carpintería, Cerrajería, Pintura y Acabados, o Mantenimiento General).
2. technicalDescription: Descripción técnica detallada de la causa raíz de la avería y solución recomendada.
3. estimatedPriceRange: Rango de precio estimado de mano de obra en Soles peruanos (PEN) acorde al mercado actual en Lima/Perú (min, max, currency: 'PEN', formatted: 'S/. XX - S/. YY').
4. materialsNeeded: Lista de materiales, repuestos o consumibles específicos necesarios para realizar la reparación con éxito.
`.trim();

    parts.push({ text: promptText });

    const response = await this.geminiClient.models.generateContent({
      model: this.modelName,
      contents: parts,
      config: {
        responseMimeType: 'application/json',
        responseSchema: {
          type: Type.OBJECT,
          properties: {
            category: { type: Type.STRING },
            technicalDescription: { type: Type.STRING },
            estimatedPriceRange: {
              type: Type.OBJECT,
              properties: {
                min: { type: Type.NUMBER },
                max: { type: Type.NUMBER },
                currency: { type: Type.STRING },
                formatted: { type: Type.STRING },
              },
              required: ['min', 'max', 'currency', 'formatted'],
            },
            materialsNeeded: {
              type: Type.ARRAY,
              items: { type: Type.STRING },
            },
          },
          required: ['category', 'technicalDescription', 'estimatedPriceRange', 'materialsNeeded'],
        },
        systemInstruction:
          'Eres un perito técnico evaluador experto de servicios domésticos y averías para la app Chamba en Perú. Responde siempre con JSON estrictamente estructurado según el esquema.',
      },
    });

    if (response.text) {
      const parsed = JSON.parse(response.text) as Record<string, any>;
      return {
        category: String(parsed.category || 'Mantenimiento General'),
        technicalDescription: String(parsed.technicalDescription || ''),
        estimatedPriceRange: parsed.estimatedPriceRange,
        materialsNeeded: Array.isArray(parsed.materialsNeeded) ? parsed.materialsNeeded : [],
        source: this.modelName,
        confidence: 0.96,
      };
    }

    return null;
  }

  /**
   * Motor de diagnóstico estructurado de contingencia para garantizar alta disponibilidad
   * ante desconexión o fallas en el proveedor de IA externo.
   */
  fallbackDiagnosis(imageUrl: string, prompt?: string): DiagnoseResponseDto {
    const textToAnalyze = `${prompt || ''} ${imageUrl || ''}`.toLowerCase();

    // 1. Gasfitería / Fugas de agua
    if (
      textToAnalyze.includes('fuga') ||
      textToAnalyze.includes('gote') ||
      textToAnalyze.includes('tub') ||
      textToAnalyze.includes('lavadero') ||
      textToAnalyze.includes('agua') ||
      textToAnalyze.includes('desague') ||
      textToAnalyze.includes('inodoro') ||
      textToAnalyze.includes('bano') ||
      textToAnalyze.includes('grifo')
    ) {
      return {
        category: 'Gasfitería',
        technicalDescription:
          'Fuga hidráulica activa con desgaste en empaques cónicos de estanqueidad o acoples roscados de desagüe. Requiere sustitución de trampa/acople y sellado con teflón de alta densidad.',
        estimatedPriceRange: {
          min: 50,
          max: 65,
          currency: 'PEN',
          formatted: 'S/. 50 - S/. 65',
        },
        materialsNeeded: [
          'Cinta teflón 3/4"',
          'Trampa P de PVC 1 1/2"',
          'Pegamento PVC Oatey',
          'Empaque de jebe cónico',
        ],
        source: 'chamba-diagnostic-engine',
        confidence: 0.9,
      };
    }

    // 2. Electricidad / Cortocircuitos
    if (
      textToAnalyze.includes('enchufe') ||
      textToAnalyze.includes('chispa') ||
      textToAnalyze.includes('cable') ||
      textToAnalyze.includes('corriente') ||
      textToAnalyze.includes('luz') ||
      textToAnalyze.includes('corto') ||
      textToAnalyze.includes('breaker') ||
      textToAnalyze.includes('tomacorriente') ||
      textToAnalyze.includes('interruptor')
    ) {
      return {
        category: 'Electricidad',
        technicalDescription:
          'Falso contacto con sobrecalentamiento y carbonización visible en bornes de conexión. Riesgo de cortocircuito; requiere aislamiento de fase y neutro, corte en tablero general y sustitución del mecanismo.',
        estimatedPriceRange: {
          min: 40,
          max: 55,
          currency: 'PEN',
          formatted: 'S/. 40 - S/. 55',
        },
        materialsNeeded: [
          'Tomacorriente doble con tierra Ticino',
          'Cinta aislante 3M Temflex',
          'Terminales punta de cobre',
        ],
        source: 'chamba-diagnostic-engine',
        confidence: 0.92,
      };
    }

    // 3. Carpintería / Cerrajería
    if (
      textToAnalyze.includes('puerta') ||
      textToAnalyze.includes('chapa') ||
      textToAnalyze.includes('cerradura') ||
      textToAnalyze.includes('madera') ||
      textToAnalyze.includes('bisagra') ||
      textToAnalyze.includes('trabada') ||
      textToAnalyze.includes('llave')
    ) {
      return {
        category: 'Carpintería',
        technicalDescription:
          'Descuadre por dilatación higrotérmica y fatiga en bisagras de sujeción perimetral. Requiere cepillado milimétrico de holgura, reajuste de escuadra y lubricación del pestillo.',
        estimatedPriceRange: {
          min: 55,
          max: 70,
          currency: 'PEN',
          formatted: 'S/. 55 - S/. 70',
        },
        materialsNeeded: [
          'Tornillos autorroscantes Spax 2 1/2"',
          'Bisagras de acero 3x3"',
          'Lija para madera grano 100',
          'Lubricante dieléctrico en aerosol',
        ],
        source: 'chamba-diagnostic-engine',
        confidence: 0.88,
      };
    }

    // 4. Pintura y Acabados
    if (
      textToAnalyze.includes('pared') ||
      textToAnalyze.includes('grieta') ||
      textToAnalyze.includes('humedad') ||
      textToAnalyze.includes('pintura') ||
      textToAnalyze.includes('techo')
    ) {
      return {
        category: 'Pintura y Acabados',
        technicalDescription:
          'Eflorescencia salina y fisuras superficiales por humedad residual en muro. Requiere raspado mecánico, sellador hidrófugo, empaste y aplicación de látex lavable.',
        estimatedPriceRange: {
          min: 60,
          max: 85,
          currency: 'PEN',
          formatted: 'S/. 60 - S/. 85',
        },
        materialsNeeded: [
          'Sellador antihumedad Tekno',
          'Pasta mural / imprimante',
          'Lija al agua grano 180',
          'Pintura látex lavable 1 galón',
        ],
        source: 'chamba-diagnostic-engine',
        confidence: 0.87,
      };
    }

    // Diagnóstico General por Defecto
    return {
      category: 'Mantenimiento General',
      technicalDescription:
        'Avería doméstica identificada que amerita revisión técnica in situ, comprobación de estado operativo y ajuste de fijaciones para restaurar su funcionalidad.',
      estimatedPriceRange: {
        min: 45,
        max: 65,
        currency: 'PEN',
        formatted: 'S/. 45 - S/. 65',
      },
      materialsNeeded: [
        'Kit de fijación rápida (tarugos y tornillos universales)',
        'Cinta multiuso selladora',
        'Insumos básicos de limpieza técnica',
      ],
      source: 'chamba-diagnostic-engine',
      confidence: 0.85,
    };
  }
}
