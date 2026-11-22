import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../core/widgets/chamba_card.dart';
import '../../data/services/auth_api_service.dart';
import '../state/app_state.dart';
import 'role_selection_screen.dart';

class RegisterScreen extends StatefulWidget {
  final AppState appState;

  const RegisterScreen({super.key, required this.appState});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _customDistrictController = TextEditingController();
  String _selectedDistrict = 'Lima - Miraflores';

  final _authApi = AuthApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  String get _effectiveDistrict => _selectedDistrict == 'Otra ciudad o distrito del Perú'
      ? (_customDistrictController.text.trim().isNotEmpty
          ? _customDistrictController.text.trim()
          : 'Perú')
      : _selectedDistrict;

  final List<String> _districts = [
    'Lima - Miraflores',
    'Lima - San Isidro',
    'Lima - Santiago de Surco',
    'Lima - San Borja',
    'Lima - Los Olivos',
    'Lima - San Miguel',
    'Lima - Magdalena del Mar',
    'Lima - Jesús María',
    'Lima - La Molina',
    'Lima - San Juan de Lurigancho',
    'Lima - Comas',
    'Lima - Chorrillos',
    'Callao - Bellavista',
    'Chiclayo - Santa Victoria',
    'Chiclayo - Centro',
    'Chiclayo - La Victoria',
    'Chiclayo - José Leonardo Ortiz',
    'Chiclayo - Pimentel',
    'Lambayeque - Centro',
    'Ferreñafe',
    'Trujillo - Centro',
    'Trujillo - Víctor Larco',
    'Trujillo - Huanchaco',
    'Arequipa - Centro',
    'Arequipa - Yanahuara',
    'Arequipa - Cayma',
    'Piura - Centro',
    'Piura - Castilla',
    'Cusco - Centro',
    'Cusco - Wanchaq',
    'Huancayo - Centro',
    'Chimbote',
    'Huaraz',
    'Ica - Centro',
    'Tacna - Centro',
    'Iquitos - Centro',
    'Tarapoto',
    'Cajamarca - Centro',
    'Puno - Centro',
    'Pucallpa',
    'Otra ciudad o distrito del Perú',
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _customDistrictController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authApi.register(
        fullName: _fullNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
        district: _effectiveDistrict,
      );

      await widget.appState.setSession(response.user, response.accessToken);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Cuenta creada exitosamente! Bienvenido, ${response.user.fullName}'),
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
      setState(() => _errorMessage = 'No se pudo conectar con el servidor.');
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
                Text(
                  'Crea tu cuenta CHAMBA',
                  style: AppTypography.headlineLg.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Regístrate para contratar servicios o trabajar como especialista técnico con una sola cuenta.',
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
                      // Nombre Completo
                      Text(
                        'Nombre Completo',
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _fullNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'Ej. Carlos Ramírez',
                          prefixIcon: const Icon(Icons.person_outline, color: AppColors.muted),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El nombre completo es obligatorio';
                          }
                          if (value.trim().split(' ').length < 2) {
                            return 'Ingresa tu nombre y apellido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Correo Electrónico
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
                          hintText: 'correo@ejemplo.com',
                          prefixIcon: const Icon(Icons.email_outlined, color: AppColors.muted),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El correo electrónico es obligatorio';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                            return 'Formato de correo no válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Teléfono
                      Text(
                        'Número de Teléfono (Opcional)',
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '+51 974 000 000',
                          prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.muted),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Distrito / Cobertura Nacional
                      Text(
                        'Ciudad / Distrito (Cobertura Nacional)',
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x3D202D33)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDistrict,
                            isExpanded: true,
                            items: _districts.map((d) {
                              return DropdownMenuItem<String>(
                                value: d,
                                child: Text(d, style: AppTypography.bodyMd),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedDistrict = val);
                            },
                          ),
                        ),
                      ),
                      if (_selectedDistrict == 'Otra ciudad o distrito del Perú') ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _customDistrictController,
                          decoration: InputDecoration(
                            hintText: 'Ingresa tu ciudad y distrito (ej. Ayacucho - Huamanga)',
                            prefixIcon: const Icon(Icons.edit_location_alt_outlined, color: AppColors.muted),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          ),
                          validator: (value) {
                            if (_selectedDistrict == 'Otra ciudad o distrito del Perú' &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Por favor ingresa tu ciudad o distrito';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Contraseña
                      Text(
                        'Contraseña (mínimo 6 caracteres)',
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
                            return 'La contraseña es obligatoria';
                          }
                          if (value.length < 6) {
                            return 'Debe tener al menos 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirmación de Contraseña
                      Text(
                        'Confirmar Contraseña',
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_reset_outlined, color: AppColors.muted),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.muted,
                            ),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Confirma tu contraseña';
                          }
                          if (value != _passwordController.text) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      ChambaButton(
                        label: _isLoading ? 'Creando cuenta...' : 'Crear Cuenta',
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _handleRegister,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '¿Ya tienes una cuenta?',
                      style: AppTypography.bodyMd.copyWith(color: AppColors.muted),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Inicia Sesión',
                        style: AppTypography.bodyMdMedium.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
