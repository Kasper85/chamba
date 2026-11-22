import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_card.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  final AppState appState;

  const SettingsScreen({super.key, required this.appState});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _bidSound = true;
  bool _locationTracking = true;
  String _selectedDistrict = 'Santa Victoria, Chiclayo';

  final List<String> _districts = [
    'Santa Victoria, Chiclayo',
    'Chiclayo Centro',
    'La Victoria, Chiclayo',
    'José Leonardo Ortiz, Chiclayo',
    'Pimentel, Lambayeque',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDistrict = widget.appState.clientDistrict;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Configuración',
          style: AppTypography.headlineSm.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // District & Zone
          Text(
            'ZONA Y COBERTURA',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          ChambaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_city, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Distrito de residencia',
                        style: AppTypography.bodyLgMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x1F202D33)),
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
                        if (val != null) {
                          setState(() => _selectedDistrict = val);
                          widget.appState.clientDistrict = val;
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Notifications
          Text(
            'NOTIFICACIONES Y SONIDOS',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          ChambaCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: AppColors.secondary,
                  title: Text(
                    'Alertas de nuevas ofertas',
                    style: AppTypography.bodyLgMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral,
                    ),
                  ),
                  subtitle: Text(
                    'Recibe notificación inmediata al ingresar cotizaciones',
                    style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                  ),
                  value: _pushNotifications,
                  onChanged: (val) => setState(() => _pushNotifications = val),
                ),
                const Divider(height: 1, color: Color(0x14202D33)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: AppColors.secondary,
                  title: Text(
                    'Sonido de contraoferta',
                    style: AppTypography.bodyLgMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral,
                    ),
                  ),
                  subtitle: Text(
                    'Tono acústico estilo inDrive cuando un precio cambia',
                    style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                  ),
                  value: _bidSound,
                  onChanged: (val) => setState(() => _bidSound = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Privacy & GPS
          Text(
            'PRIVACIDAD Y MAPA',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          ChambaCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: AppColors.tertiary,
                  title: Text(
                    'Radio de privacidad (500m)',
                    style: AppTypography.bodyLgMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral,
                    ),
                  ),
                  subtitle: Text(
                    'Oculta tu casa exacta a especialistas hasta que aceptes la oferta',
                    style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                  ),
                  value: _locationTracking,
                  onChanged: (val) => setState(() => _locationTracking = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About app
          Center(
            child: Column(
              children: [
                Text(
                  'CHAMBA Perú • Chiclayo',
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Versión 1.0.0+1 (Stitch Design System Parity)',
                  style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
