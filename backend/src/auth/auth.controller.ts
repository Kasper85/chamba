import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { AuthService } from './auth.service.js';
import { RegisterDto } from './dto/register.dto.js';
import { LoginDto } from './dto/login.dto.js';
import { GoogleLoginDto } from './dto/google-login.dto.js';

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('register')
  @ApiOperation({ summary: 'Registrar un nuevo usuario' })
  @ApiResponse({ status: 201, description: 'Usuario registrado exitosamente con token JWT' })
  @ApiResponse({ status: 409, description: 'El correo electrónico ya existe' })
  async register(@Body() registerDto: RegisterDto) {
    return this.authService.register(registerDto);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Iniciar sesión con correo y contraseña' })
  @ApiResponse({ status: 200, description: 'Sesión iniciada correctamente con token JWT' })
  @ApiResponse({ status: 401, description: 'Credenciales inválidas o cuenta inactiva' })
  async login(@Body() loginDto: LoginDto) {
    return this.authService.login(loginDto);
  }

  @Post('google/login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Iniciar sesión con una cuenta de Google validada' })
  @ApiResponse({ status: 200, description: 'Sesión de Google iniciada correctamente' })
  @ApiResponse({ status: 401, description: 'ID token de Google inválido' })
  async loginWithGoogle(@Body() googleLoginDto: GoogleLoginDto) {
    return this.authService.loginWithGoogle(googleLoginDto.idToken);
  }

  @Post('google/register')
  @HttpCode(HttpStatus.OK)
  async prepareGoogleRegistration(@Body() googleLoginDto: GoogleLoginDto) {
    return this.authService.prepareGoogleRegistration(googleLoginDto.idToken);
  }
}
