import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../core/widgets/chamba_card.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const AuthScreen({super.key, required this.onLoginSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController(text: '974 123 456');
  final _dniController = TextEditingController(text: '47891234');
  bool _otpSent = false;
  final _otpController = TextEditingController(text: '4829');

  @override
  void dispose() {
    _phoneController.dispose();
    _dniController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/chamba.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'CHAMBA',
                    style: AppTypography.headlineLg.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                _otpSent ? 'Ingresa el código SMS' : 'Ingresa a tu cuenta',
                style: AppTypography.headlineLg.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent
                    ? 'Hemos enviado un código de 4 dígitos a tu número +51 ${_phoneController.text}'
                    : 'Servicios del hogar con negociación directa y pagos transparentes en Chiclayo',
                style: AppTypography.bodyMd.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              ChambaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_otpSent) ...[
                      Text(
                        'Número de Teléfono (Perú)',
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🇵🇪 +51', style: AppTypography.bodyLgMedium),
                                const SizedBox(width: 8),
                                Container(width: 1, height: 20, color: const Color(0x1F202D33)),
                              ],
                            ),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'DNI Peruano (Para verificación RENIEC)',
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _dniController,
                        keyboardType: TextInputType.number,
                        maxLength: 8,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.muted),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          counterText: '',
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Código de 4 Dígitos',
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: AppTypography.headlineLg.copyWith(
                          letterSpacing: 8,
                          color: AppColors.primary,
                        ),
                        maxLength: 4,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => setState(() => _otpSent = false),
                        child: Text(
                          'Cambiar número de teléfono',
                          style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ChambaButton(
                      label: _otpSent ? 'Verificar y Entrar' : 'Continuar con SMS',
                      onPressed: () {
                        if (!_otpSent) {
                          setState(() => _otpSent = true);
                        } else {
                          widget.onLoginSuccess();
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
