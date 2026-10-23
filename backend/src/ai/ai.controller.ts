import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { AiService } from './ai.service.js';
import { DiagnoseRequestDto } from './dto/diagnose-request.dto.js';
import { DiagnoseResponseDto } from './dto/diagnose-response.dto.js';

@ApiTags('AI Diagnostics (Gemini)')
@Controller('ai')
export class AiController {
  constructor(private readonly aiService: AiService) {}

  @Post('diagnose')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Diagnosticar avería doméstica mediante IA multimodal (Gemini / R2)',
    description:
      'Recibe la URL de la imagen subida a Cloudflare R2 y un texto descriptivo. Devuelve un diagnóstico estructurado con categoría técnica, descripción, rango de precio estimado en Soles (PEN) y lista de repuestos necesarios.',
  })
  @ApiResponse({
    status: 200,
    description: 'Diagnóstico técnico estructurado generado exitosamente',
    type: DiagnoseResponseDto,
  })
  @ApiResponse({
    status: 400,
    description: 'Datos de entrada inválidos (se requiere imageUrl)',
  })
  async diagnose(@Body() dto: DiagnoseRequestDto): Promise<DiagnoseResponseDto> {
    return this.aiService.diagnose(dto.imageUrl, dto.prompt);
  }
}
