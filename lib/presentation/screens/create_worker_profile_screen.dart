import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../data/models/category.dart';
import '../../data/services/auth_api_service.dart';
import '../state/app_state.dart';
import 'app_shell_gate.dart';

class CreateWorkerProfileScreen extends StatefulWidget {
  final AppState appState;
  final bool isRegistration;

  const CreateWorkerProfileScreen({
    super.key,
    required this.appState,
    this.isRegistration = false,
  });

  @override
  State<CreateWorkerProfileScreen> createState() =>
      _CreateWorkerProfileScreenState();
}

class _CreateWorkerProfileScreenState extends State<CreateWorkerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late TextEditingController _nameController;
  late TextEditingController _dniController;
  late TextEditingController _phoneController;
  late TextEditingController _districtController;
  late TextEditingController _bioController;

  late double _baseRate;
  late double _radiusKm;
  late int _experienceYears;
  late List<String> _selectedSkills;
  bool _hasRate = false;
  bool _hasRadius = false;
  bool _hasExperience = false;

  @override
  void initState() {
    super.initState();
    final current = widget.appState.currentWorkerProfile;
    final saved = widget.appState.currentUser?.workerProfile;
    _hasRate = saved?.baseRate != null;
    _hasRadius = saved?.serviceRadiusKm != null;
    _hasExperience = saved?.experienceYears != null;
    _nameController = TextEditingController(text: current.name);
    _dniController = TextEditingController(text: current.dni);
    _phoneController = TextEditingController(text: current.phone);
    _districtController = TextEditingController(text: current.district);
    _bioController = TextEditingController(text: current.bio);
    // Los sliders necesitan un valor dentro de sus límites para renderizarse.
    // Son valores iniciales de control, no datos personales inventados.
    _baseRate = current.baseRate.clamp(0.0, 150.0);
    _radiusKm = current.serviceRadiusKm.toDouble().clamp(0.0, 35.0);
    _experienceYears = current.experienceYears.clamp(0, 30);
    _selectedSkills = List.from(current.skills);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dniController.dispose();
    _phoneController.dispose();
    _districtController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final token = widget.appState.authToken;
    if (token == null) return;
    setState(() => _saving = true);
    try {
      final api = AuthApiService();
      await api.upsertWorkerProfile(
        token,
        bio: _bioController.text.trim(),
        specialty: _selectedSkills.isNotEmpty ? _selectedSkills.first : '',
        dni: _dniController.text.trim(),
        baseRate: _hasRate ? _baseRate : null,
        serviceRadiusKm: _hasRadius ? _radiusKm.round() : null,
        experienceYears: _hasExperience ? _experienceYears : null,
        skills: _selectedSkills,
        district: _districtController.text.trim(),
        isAvailable:
            widget.appState.currentUser?.workerProfile?.isAvailable ?? false,
      );
      final user = await api.updateMe(
        token,
        fullName: _nameController.text,
        phone: _phoneController.text,
        district: _districtController.text,
      );
      await widget.appState.setSession(user, token);
      if (!mounted) return;
      if (widget.isRegistration) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => AppShellGate(appState: widget.appState),
          ),
          (_) => false,
        );
      } else {
        Navigator.of(context).pop();
      }
    } on AuthApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Perfil de Especialista'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Datos del Especialista',
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Configura tus oficios, tarifa referencial y zona de atención para recibir pedidos directos.',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 20),

                // Name
                Text(
                  'Nombre y Apellidos completos',
                  style: AppTypography.labelLg,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Ej. Jorge Quispe Baldera',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa tu nombre'
                      : null,
                ),
                const SizedBox(height: 16),

                // DNI & Phone
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DNI (Perú)', style: AppTypography.labelLg),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _dniController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: '8 dígitos',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Teléfono Celular',
                            style: AppTypography.labelLg,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: '974 812 345',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // District
                Text('Distrito base de trabajo', style: AppTypography.labelLg),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _districtController,
                  decoration: const InputDecoration(
                    hintText: 'José Leonardo Ortiz, Chiclayo',
                  ),
                ),
                const SizedBox(height: 20),

                // Skills / Oficios
                Text('Oficios que dominas', style: AppTypography.labelLg),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: JobCategory.defaultCategories.map((cat) {
                    final isSelected = _selectedSkills.contains(cat.name);
                    return FilterChip(
                      selectedColor: AppColors.primary,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.neutral,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      label: Text(cat.name),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedSkills.add(cat.name);
                          } else {
                            _selectedSkills.remove(cat.name);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Base rate in Soles
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tarifa base referencial (visita/hora)',
                      style: AppTypography.labelLg,
                    ),
                    Text(
                      _hasRate
                          ? 'S/ ${_baseRate.toStringAsFixed(0)}'
                          : 'Sin indicar',
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _baseRate,
                  min: 0.0,
                  max: 150.0,
                  divisions: 30,
                  activeColor: AppColors.secondary,
                  onChanged: (val) => setState(() {
                    _baseRate = val;
                    _hasRate = true;
                  }),
                ),
                const SizedBox(height: 14),

                // Coverage radius
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Radio de cobertura máximo',
                      style: AppTypography.labelLg,
                    ),
                    Text(
                      _hasRadius
                          ? '${_radiusKm.toStringAsFixed(0)} km'
                          : 'Sin indicar',
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.tertiary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _radiusKm,
                  min: 0.0,
                  max: 35.0,
                  divisions: 7,
                  activeColor: AppColors.tertiary,
                  onChanged: (val) => setState(() {
                    _radiusKm = val;
                    _hasRadius = true;
                  }),
                ),
                const SizedBox(height: 16),

                // Experience Years
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Años de experiencia laboral',
                      style: AppTypography.labelLg,
                    ),
                    Text(
                      _hasExperience ? '$_experienceYears años' : 'Sin indicar',
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _experienceYears.toDouble(),
                  min: 0.0,
                  max: 30.0,
                  divisions: 30,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() {
                    _experienceYears = val.round();
                    _hasExperience = true;
                  }),
                ),
                const SizedBox(height: 16),

                // Bio
                Text('Descripción / Experiencia', style: AppTypography.labelLg),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Cuéntale a los clientes tus especialidades y garantías de trabajo...',
                  ),
                ),
                const SizedBox(height: 28),

                ChambaButton(
                  label: 'Guardar Perfil de Especialista',
                  leadingIcon: Icons.save,
                  isLoading: _saving,
                  onPressed: _saving ? null : _saveProfile,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
