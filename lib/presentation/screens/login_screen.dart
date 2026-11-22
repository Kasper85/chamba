import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../core/widgets/chamba_card.dart';
import '../../data/services/auth_api_service.dart';
import '../state/app_state.dart';
import 'role_selection_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final AppState appState;

  const LoginScreen({super.key, required this.appState});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'ana@chamba.pe');
  final _passwordController = TextEditingController(text: 'Password123!');
  final _authApi = AuthApiService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authApi.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      await widget.appState.setSession(response.user, response.accessToken);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Bienvenido, ${response.user.fullName}!'),
          backgroundColor: AppColors.tertiary,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => RoleSelectionScreen(appState: widget.appState),
        ),
        (route) => false,
      );
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Ocurrió un error inesperado al conectar con el servidor.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/chamba.png',
                        width: 42,
                        height: 42,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 24),
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
                  'Ingresa a tu cuenta',
                  style: AppTypography.headlineLg.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Conecta con técnicos verificados o publica tus servicios en Chiclayo y distritos.',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                ChambaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Correo Electrónico',
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'ejemplo@correo.pe',
                          prefixIcon: const Icon(Icons.email_outlined, color: AppColors.muted),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor ingresa tu correo electrónico';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                            return 'Ingresa un formato de correo válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Contraseña',
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.muted),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.muted,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingresa tu contraseña';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      ChambaButton(
                        label: _isLoading ? 'Ingresando...' : 'Iniciar Sesión',
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _handleLogin,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const SizedBox(height: 16),

                // Link to Register
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '¿Aún no tienes una cuenta?',
                      style: AppTypography.bodyMd.copyWith(color: AppColors.muted),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RegisterScreen(appState: widget.appState),
                          ),
                        );
                      },
                      child: Text(
                        'Regístrate aquí',
                        style: AppTypography.bodyMdMedium.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                // Quick test accounts for evaluation/seed (restricted to debug mode)
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Cuentas de prueba (Seed - Solo Debug):',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ActionChip(
                              avatar: const CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Text('AG', style: TextStyle(fontSize: 10, color: Colors.white)),
                              ),
                              label: const Text('Ana'),
                              onPressed: () {
                                setState(() {
                                  _emailController.text = 'ana@chamba.pe';
                                  _passwordController.text = 'Password123!';
                                  _errorMessage = null;
                                });
                              },
                            ),
                            ActionChip(
                              avatar: const CircleAvatar(
                                backgroundColor: AppColors.secondary,
                                child: Text('JT', style: TextStyle(fontSize: 10, color: Colors.white)),
                              ),
                              label: const Text('José'),
                              onPressed: () {
                                setState(() {
                                  _emailController.text = 'jose@chamba.pe';
                                  _passwordController.text = 'Password123!';
                                  _errorMessage = null;
                                });
                              },
                            ),
                            ActionChip(
                              avatar: const CircleAvatar(
                                backgroundColor: AppColors.tertiary,
                                child: Text('CR', style: TextStyle(fontSize: 10, color: Colors.white)),
                              ),
                              label: const Text('Carlos'),
                              onPressed: () {
                                setState(() {
                                  _emailController.text = 'carlos@chamba.pe';
                                  _passwordController.text = 'Password123!';
                                  _errorMessage = null;
                                });
                              },
                            ),
                            ActionChip(
                              avatar: const CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Text('MM', style: TextStyle(fontSize: 10, color: Colors.white)),
                              ),
                              label: const Text('Marcos (Lima)'),
                              onPressed: () {
                                setState(() {
                                  _emailController.text = 'marcos@chamba.pe';
                                  _passwordController.text = 'Password123!';
                                  _errorMessage = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
