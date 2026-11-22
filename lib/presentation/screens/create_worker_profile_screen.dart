import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../data/models/category.dart';
import '../../data/services/auth_api_service.dart';
import '../state/app_state.dart';

class CreateWorkerProfileScreen extends StatefulWidget {
  final AppState appState;

  const CreateWorkerProfileScreen({
    super.key,
    required this.appState,
  });

  @override
  State<CreateWorkerProfileScreen> createState() => _CreateWorkerProfileScreenState();
}

class _CreateWorkerProfileScreenState extends State<CreateWorkerProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _dniController;
  late TextEditingController _phoneController;
  late TextEditingController _districtController;
  late TextEditingController _bioController;

  late double _baseRate;
  late double _radiusKm;
  late int _experienceYears;
  late List<String> _selectedSkills;

  @override
  void initState() {
    super.initState();
    final current = widget.appState.currentWorkerProfile;
    _nameController = TextEditingController(text: current.name);
    _dniController = TextEditingController(text: current.dni);
    _phoneController = TextEditingController(text: current.phone);
    _districtController = TextEditingController(text: current.district);
    _bioController = TextEditingController(text: current.bio);
    _baseRate = current.baseRate;
    _radiusKm = current.serviceRadiusKm.toDouble();
    _experienceYears = current.experienceYears;
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

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;

    final updated = widget.appState.currentWorkerProfile.copyWith(
      name: _nameController.text.trim(),
      dni: _dniController.text.trim(),
      phone: _phoneController.text.trim(),
      district: _districtController.text.trim(),
      bio: _bioController.text.trim(),
      baseRate: _baseRate,
      serviceRadiusKm: _radiusKm.round(),
      experienceYears: _experienceYears,
      skills: _selectedSkills,
      isVerified: true,
    );

    widget.appState.updateWorkerProfile(updated);

    if (widget.appState.authToken != null) {
      AuthApiService()
          .upsertWorkerProfile(
            widget.appState.authToken!,
            bio: _bioController.text.trim(),
            specialty: _selectedSkills.isNotEmpty ? _selectedSkills.first : 'Servicios Generales',
            district: _districtController.text.trim(),
            isAvailable: true,
          )
          .then((_) => widget.appState.refreshUserProfile())
          .catchError((_) {});
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Perfil de especialista guardado con éxito!'),
        backgroundColor: AppColors.tertiary,
      ),
    );
    Navigator.of(context).pop();
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
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
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
                Text('Nombre y Apellidos completos', style: AppTypography.labelLg),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: 'Ej. Jorge Quispe Baldera'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa tu nombre' : null,
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
                            decoration: const InputDecoration(hintText: '8 dígitos'),
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
                          Text('Teléfono Celular', style: AppTypography.labelLg),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(hintText: '974 812 345'),
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
                  decoration: const InputDecoration(hintText: 'José Leonardo Ortiz, Chiclayo'),
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
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
                    Text('Tarifa base referencial (visita/hora)', style: AppTypography.labelLg),
                    Text(
                      'S/. ${_baseRate.toStringAsFixed(0)}',
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _baseRate,
                  min: 20.0,
                  max: 150.0,
                  divisions: 26,
                  activeColor: AppColors.secondary,
                  onChanged: (val) => setState(() => _baseRate = val),
                ),
                const SizedBox(height: 14),

                // Coverage radius
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Radio de cobertura máximo', style: AppTypography.labelLg),
                    Text(
                      '${_radiusKm.toStringAsFixed(0)} km',
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.tertiary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _radiusKm,
                  min: 5.0,
                  max: 35.0,
                  divisions: 6,
                  activeColor: AppColors.tertiary,
                  onChanged: (val) => setState(() => _radiusKm = val),
                ),
                const SizedBox(height: 16),

                // Experience Years
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Años de experiencia laboral', style: AppTypography.labelLg),
                    Text(
                      '$_experienceYears años',
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _experienceYears.toDouble(),
                  min: 1.0,
                  max: 30.0,
                  divisions: 29,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _experienceYears = val.round()),
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
                  onPressed: _saveProfile,
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
