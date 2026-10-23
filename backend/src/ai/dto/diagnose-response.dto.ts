import { ApiProperty } from '@nestjs/swagger';

export class EstimatedPriceRangeDto {
  @ApiProperty({ example: 50, description: 'Precio mínimo estimado en Soles' })
  min: number;

  @ApiProperty({ example: 65, description: 'Precio máximo estimado en Soles' })
  max: number;

  @ApiProperty({ example: 'PEN', description: 'Moneda' })
  currency: string;

  @ApiProperty({ example: 'S/. 50 - S/. 65', description: 'Representación legible del rango de precio' })
  formatted: string;
}

export class DiagnoseResponseDto {
  @ApiProperty({
    example: 'Gasfitería',
    description: 'Categoría profesional recomendada para el trabajo',
  })
  category: string;

  @ApiProperty({
    example:
      'Goteo constante en la conexión de desagüe bajo el lavadero de cocina. La rosca está vencida y filtra agua.',
    description: 'Descripción técnica profesional de la avería detectada',
  })
  technicalDescription: string;

  @ApiProperty({
    type: EstimatedPriceRangeDto,
    description: 'Rango de precio sugerido por la IA en Soles',
  })
  estimatedPriceRange: EstimatedPriceRangeDto;

  @ApiProperty({
    example: ['Cinta teflón 3/4"', 'Trampa P de PVC 1 1/2"', 'Pegamento PVC Oatey', 'Empaque de jebe cónico'],
    description: 'Lista de materiales y repuestos necesarios identificados',
    type: [String],
  })
  materialsNeeded: string[];

  @ApiProperty({
    example: 'gemini-2.5-flash',
    description: 'Motor de inferencia utilizado (Gemini o motor de respaldo)',
  })
  source: string;

  @ApiProperty({
    example: 0.95,
    description: 'Nivel de confianza de la clasificación',
  })
  confidence: number;
}
