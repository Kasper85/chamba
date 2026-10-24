import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../core/widgets/price_dial_stepper.dart';
import '../../data/models/category.dart';
import '../state/app_state.dart';
import '../widgets/chamba_interactive_map.dart';
import 'received_bids_screen.dart';

class PostJobScreen extends StatefulWidget {
  final AppState appState;
  final JobCategory? initialCategory;
  final bool isSosInitial;

  const PostJobScreen({
    super.key,
    required this.appState,
    this.initialCategory,
    this.isSosInitial = false,
  });

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();

  late JobCategory _selectedCategory;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController(text: 'Calle Los Pinos 342, Dpto 201');
  final _districtController = TextEditingController(text: 'Santa Victoria, Chiclayo');
  final _referenceController = TextEditingController(text: 'Frente al parque principal, reja blanca');

  double _selectedLat = -6.7760;
  double _selectedLng = -79.8436;

  late bool _isSos;
  late String _selectedUrgency;
  double _proposedBudget = 50.0;
  double _aiRecommendedPrice = 50.0;
  List<String> _detectedAiMaterials = [];
  String? _aiScenarioApplied;
  String? _aiPriceRange;
  bool _isPublishing = false;

  final List<String> _urgencyOptions = [
    'Emergencia SOS (<30 min)',
    'Urgente (Hoy)',
    'Esta semana',
    'Flexible',
  ];

  @override
  void initState() {
    super.initState();
    _isSos = widget.isSosInitial;
    _selectedCategory = widget.initialCategory ?? JobCategory.defaultCategories.first;
    _selectedUrgency = _isSos ? 'Emergencia SOS (<30 min)' : 'Urgente (Hoy)';
    if (_isSos) {
      _proposedBudget = 70.0; // Dynamic surge base
      _aiRecommendedPrice = 70.0;
      _titleController.text = '🚨 EMERGENCIA: ${_selectedCategory.name} urgente';
    } else {
      _titleController.text = 'Reparación de ${_selectedCategory.name.toLowerCase()}';
    }
  }

  void _toggleSos(bool val) {
    setState(() {
      _isSos = val;
      if (_isSos) {
        _selectedUrgency = 'Emergencia SOS (<30 min)';
        _proposedBudget = (_proposedBudget * 1.35).roundToDouble();
        _aiRecommendedPrice = (_aiRecommendedPrice * 1.35).roundToDouble();
        if (!_titleController.text.startsWith('🚨')) {
          _titleController.text = '🚨 ${_titleController.text}';
        }
      } else {
        _selectedUrgency = 'Urgente (Hoy)';
        _proposedBudget = (_proposedBudget / 1.35).roundToDouble();
        _aiRecommendedPrice = (_aiRecommendedPrice / 1.35).roundToDouble();
        _titleController.text = _titleController.text.replaceAll('🚨 ', '').replaceAll('🚨', '');
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _districtController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickImageAndDiagnose(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      await _executeRealAiDiagnosticFlow(bytes, picked.name);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir la cámara o galería.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _executeRealAiDiagnosticFlow(Uint8List bytes, String filename) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => const _AiScanningModalDialog(
        scenarioName: 'Subiendo y analizando foto...',
        icon: Icons.camera_enhance_rounded,
        accentColor: Color(0xFF6366F1),
      ),
    );

    try {
      final result = await widget.appState.runAiDiagnosticFlow(
        imageBytes: bytes,
        filename: filename,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final matchingCategory = JobCategory.defaultCategories.firstWhere(
        (c) => c.name.toLowerCase().contains(result.category.toLowerCase()) ||
               result.category.toLowerCase().contains(c.name.toLowerCase()),
        orElse: () => _selectedCategory,
      );

      setState(() {
        _selectedCategory = matchingCategory;
        final prefix = _isSos ? '🚨 ' : '';
        _titleController.text = '$prefix Reparación de ${result.category}';
        _descriptionController.text = result.technicalDescription;
        _detectedAiMaterials = List<String>.from(result.materialsNeeded);
        _aiRecommendedPrice = _isSos ? (result.averagePrice * 1.35).roundToDouble() : result.averagePrice;
        _proposedBudget = _aiRecommendedPrice;
        _aiScenarioApplied = result.badgeLabel;
        _aiPriceRange = result.formattedPrice;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isAiGenerated
                ? '✨ ${result.badgeLabel} completado con éxito'
                : 'ℹ️ ${result.badgeLabel} aplicado',
          ),
          backgroundColor: result.isAiGenerated ? const Color(0xFF4F46E5) : const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo subir la foto'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAiDiagnosisSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0x33202D33),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Diagnóstico Visual con IA',
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'Simula la captura de una foto/video para autocompletar',
                            style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _pickImageAndDiagnose(ImageSource.camera);
                        },
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('Tomar Foto', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6366F1),
                          side: const BorderSide(color: Color(0xFF6366F1)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _pickImageAndDiagnose(ImageSource.gallery);
                        },
                        icon: const Icon(Icons.photo_library_rounded, size: 18),
                        label: const Text('Galería', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'O selecciona una avería de prueba:',
                  style: AppTypography.labelLg.copyWith(color: AppColors.neutral),
                ),
                const SizedBox(height: 12),
                _buildAiScenarioOption(
                  ctx: ctx,
                  icon: Icons.water_drop_rounded,
                  accentColor: const Color(0xFF0284C7),
                  title: 'Tubería goteando bajo lavadero',
                  categoryName: 'Gasfitería',
                  priceEstimate: 'S/. 50 - S/. 65',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _runAiScanningSimulation(
                      scenarioName: 'Tubería goteando bajo lavadero',
                      icon: Icons.water_drop_rounded,
                      accentColor: const Color(0xFF0284C7),
                      categoryId: 'gasfiteria',
                      categoryName: 'Gasfitería',
                      title: 'Reparación de fuga en trampa de lavadero y codo PVC',
                      description: 'Goteo constante en la conexión de desagüe bajo el lavadero de cocina. La rosca está vencida y filtra agua cada vez que se abre la llave.',
                      materials: ['Cinta teflón 3/4"', 'Trampa P de PVC 1 1/2"', 'Pegamento PVC Oatey', 'Empaque de jebe cónico'],
                      suggestedPrice: 55.0,
                      priceRange: 'S/. 50 - S/. 65',
                    );
                  },
                ),
                _buildAiScenarioOption(
                  ctx: ctx,
                  icon: Icons.bolt_rounded,
                  accentColor: const Color(0xFFF59E0B),
                  title: 'Enchufe chispeando en pared',
                  categoryName: 'Electricidad',
                  priceEstimate: 'S/. 40 - S/. 55',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _runAiScanningSimulation(
                      scenarioName: 'Enchufe chispeando en pared',
                      icon: Icons.bolt_rounded,
                      accentColor: const Color(0xFFF59E0B),
                      categoryId: 'electricidad',
                      categoryName: 'Electricidad',
                      title: 'Cambio de tomacorriente sobrecalentado con chispas',
                      description: 'Tomacorriente doble en sala emite chispas y olor a quemado al conectar artefactos. Falso contacto visible y bornes recalentados.',
                      materials: ['Tomacorriente doble con tierra Ticino', 'Cinta aislante 3M Temflex', 'Terminales punta de cobre'],
                      suggestedPrice: 45.0,
                      priceRange: 'S/. 40 - S/. 55',
                    );
                  },
                ),
                _buildAiScenarioOption(
                  ctx: ctx,
                  icon: Icons.meeting_room_rounded,
                  accentColor: const Color(0xFF8B5CF6),
                  title: 'Puerta de madera trabada',
                  categoryName: 'Carpintería',
                  priceEstimate: 'S/. 55 - S/. 70',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _runAiScanningSimulation(
                      scenarioName: 'Puerta de madera trabada',
                      icon: Icons.meeting_room_rounded,
                      accentColor: const Color(0xFF8B5CF6),
                      categoryId: 'carpinteria',
                      categoryName: 'Carpintería',
                      title: 'Ajuste y cepillado de puerta de madera hinchada',
                      description: 'La puerta principal roza fuertemente contra el piso y el marco por humedad ambiental en Chiclayo, trabando la chapa al cerrar.',
                      materials: ['Tornillos para bisagra 1 1/2"', 'Lija para madera grano 80 y 120', 'Lubricante para chapa WD-40'],
                      suggestedPrice: 60.0,
                      priceRange: 'S/. 55 - S/. 70',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAiScenarioOption({
    required BuildContext ctx,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String categoryName,
    required String priceEstimate,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.bodyLgMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              categoryName,
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sugerido: $priceEstimate',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _runAiScanningSimulation({
    required String scenarioName,
    required IconData icon,
    required Color accentColor,
    required String categoryId,
    required String categoryName,
    required String title,
    required String description,
    required List<String> materials,
    required double suggestedPrice,
    required String priceRange,
  }) async {
    // Show 1.5s scanning simulation dialog with live laser viewfinder
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _AiScanningModalDialog(
        scenarioName: scenarioName,
        icon: icon,
        accentColor: accentColor,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Close dialog

    final matchingCategory = JobCategory.defaultCategories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => _selectedCategory,
    );

    setState(() {
      _selectedCategory = matchingCategory;
      _titleController.text = _isSos ? '🚨 $title' : title;
      _descriptionController.text = description;
      _detectedAiMaterials = List<String>.from(materials);
      _aiRecommendedPrice = _isSos ? (suggestedPrice * 1.35).roundToDouble() : suggestedPrice;
      _proposedBudget = _aiRecommendedPrice;
      _aiScenarioApplied = scenarioName;
      _aiPriceRange = priceRange;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '¡Diagnóstico IA completado! $title (Sugerido: $priceRange).',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4338CA),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isPublishing = true);
    await Future.delayed(const Duration(milliseconds: 600));

    final newJob = widget.appState.createJobRequest(
      title: _titleController.text.trim(),
      categoryId: _selectedCategory.id,
      categoryName: _selectedCategory.name,
      description: _descriptionController.text.trim().isEmpty
          ? '${_isSos ? "🚨 EMERGENCIA SOS: " : ""}Trabajo de ${_selectedCategory.name} en ${_districtController.text.trim()}'
          : _descriptionController.text.trim(),
      budget: _proposedBudget,
      district: _districtController.text.trim(),
      address: _addressController.text.trim(),
      urgency: _selectedUrgency,
      latitude: _selectedLat,
      longitude: _selectedLng,
      reference: _referenceController.text.trim(),
      isSos: _isSos,
      urgencyMultiplier: _isSos ? 1.35 : 1.0,
    );

    if (!mounted) return;
    setState(() => _isPublishing = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReceivedBidsScreen(
          appState: widget.appState,
          job: newJob,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isSos ? const Color(0xFFFFF7F5) : AppColors.canvas,
      appBar: AppBar(
        title: Text(_isSos ? '🚨 Publicar Emergencia SOS' : 'Publicar Solicitud'),
        backgroundColor: _isSos ? AppColors.sosRedLight : AppColors.canvas,
        foregroundColor: _isSos ? AppColors.sosRedDark : AppColors.primary,
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
                // FEATURE 1: AI VISUAL DIAGNOSIS HERO CARD
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _showAiDiagnosisSelector,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        _aiScenarioApplied ?? '✨ Diagnóstico Visual',
                                        style: AppTypography.bodyLgMedium.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'NUEVO',
                                          style: AppTypography.labelSm.copyWith(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _aiScenarioApplied != null
                                        ? 'Falla detectada: $_aiScenarioApplied (Toca para cambiar)'
                                        : 'Sube o simula una foto para detectar falla, repuestos y precio justo.',
                                    style: AppTypography.labelSm.copyWith(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Interactive SOS Emergency Switch Card
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isSos ? AppColors.sosRedLight : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isSos ? AppColors.sosRed : const Color(0x1F173B4D),
                      width: _isSos ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isSos ? AppColors.sosGlow : const Color(0x08173B4D),
                        blurRadius: _isSos ? 12 : 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isSos ? AppColors.sosRed : AppColors.surfaceContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isSos ? Icons.emergency_rounded : Icons.flash_on_rounded,
                          color: _isSos ? Colors.white : AppColors.secondary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activar Modo SOS (< 30 min)',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyLgMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: _isSos ? AppColors.sosRedDark : AppColors.neutral,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isSos
                                  ? '⚡ Tarifa de Emergencia (+35%) • Atención garantizada en < 30 min.'
                                  : 'Para fugas graves, cerraduras rotas o cortes de luz.',
                              style: AppTypography.labelSm.copyWith(
                                color: _isSos ? AppColors.sosRedDark : AppColors.muted,
                                fontWeight: _isSos ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isSos,
                        activeThumbColor: AppColors.sosRed,
                        activeTrackColor: AppColors.sosRedLight,
                        onChanged: _toggleSos,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                Text(
                  _isSos ? '🚨 Detalles de la Emergencia SOS' : 'Detalla lo que necesitas',
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _isSos ? AppColors.sosRedDark : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isSos
                      ? 'Los técnicos de guardia más cercanos en Chiclayo recibirán una alerta prioritaria en su pantalla.'
                      : 'Los técnicos usarán esta información para enviarte cotizaciones exactas.',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 20),

                // Category selector
                Text(
                  'Categoría del servicio',
                  style: AppTypography.labelLg.copyWith(color: AppColors.neutral),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: JobCategory.defaultCategories.map((cat) {
                      final isSelected = cat.id == _selectedCategory.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.card,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.neutral,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          avatar: Icon(
                            cat.icon,
                            size: 16,
                            color: isSelected ? Colors.white : AppColors.primary,
                          ),
                          label: Text(cat.name),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedCategory = cat;
                                _titleController.text =
                                    'Reparación de ${cat.name.toLowerCase()}';
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Job Title
                Text(
                  'Título de la solicitud',
                  style: AppTypography.labelLg.copyWith(color: AppColors.neutral),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'Ej. Fuga en lavadero de cocina',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Ingresa un título descriptivo' : null,
                ),
                const SizedBox(height: 18),

                // Description
                Text(
                  'Descripción del trabajo',
                  style: AppTypography.labelLg.copyWith(color: AppColors.neutral),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Describe el problema, materiales requeridos o si tienes repuestos...',
                  ),
                ),
                const SizedBox(height: 20),

                // AI ESTIMATED MATERIALS CARD (if detected)
                if (_detectedAiMaterials.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.handyman_rounded, color: Color(0xFF7C3AED), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Materiales estimados detectados por IA',
                                style: AppTypography.bodyLgMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF5B21B6),
                                ),
                              ),
                            ),
                            if (_aiPriceRange != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _aiPriceRange!,
                                  style: AppTypography.labelSm.copyWith(
                                    color: const Color(0xFF5B21B6),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Puedes comprarlos con anticipación o solicitarlos al técnico asignado:',
                          style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _detectedAiMaterials.map((mat) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFDDD6FE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check, size: 13, color: Color(0xFF7C3AED)),
                                  const SizedBox(width: 4),
                                  Text(
                                    mat,
                                    style: AppTypography.labelSm.copyWith(
                                      color: const Color(0xFF4C1D95),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Interactive Map Section
                Text(
                  'Ubicación en el Mapa',
                  style: AppTypography.labelLg.copyWith(color: AppColors.neutral),
                ),
                const SizedBox(height: 6),
                Text(
                  'Mueve el marcador o pulsa el botón GPS para ubicar tu domicilio con precisión:',
                  style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                ChambaInteractiveMap(
                  mode: MapDisplayMode.selectLocation,
                  height: 220,
                  initialCenter: LatLng(_selectedLat, _selectedLng),
                  onLocationChanged: (pos, name) {
                    setState(() {
                      _selectedLat = pos.latitude;
                      _selectedLng = pos.longitude;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // District & Address & Reference
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Distrito',
                            style: AppTypography.labelLg.copyWith(color: AppColors.neutral),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _districtController,
                            decoration: const InputDecoration(
                              hintText: 'Santa Victoria / Chiclayo',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dirección',
                            style: AppTypography.labelLg.copyWith(color: AppColors.neutral),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              hintText: 'Calle y número',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Text(
                  'Referencia del domicilio',
                  style: AppTypography.labelLg.copyWith(color: AppColors.neutral),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    hintText: 'Ej. Frente a parque, portón marrón, timbre blanco',
                    prefixIcon: Icon(Icons.near_me_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 20),

                // Urgency Chips
                Text(
                  '¿Para cuándo lo necesitas?',
                  style: AppTypography.labelLg.copyWith(color: AppColors.neutral),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _urgencyOptions.map((urg) {
                      final isSelected = _selectedUrgency == urg;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          selectedColor: AppColors.surfaceContainer,
                          backgroundColor: AppColors.card,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.primary : AppColors.neutral,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          label: Text(urg),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setState(() => _selectedUrgency = urg);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // inDrive Style Budget Stepper Dial with Semáforo de Probabilidad de Aceptación
                PriceDialStepper(
                  currentPrice: _proposedBudget,
                  recommendedPrice: _aiRecommendedPrice,
                  minPrice: 15.0,
                  maxPrice: 2000.0,
                  label: _isSos ? 'Presupuesto con Tarifa de Emergencia' : 'Tu Presupuesto Inicial Ofrecido',
                  isSosSurge: _isSos,
                  surgeLabel: '⚡ Tarifa Dinámica de Emergencia (+35%) • Llegada en < 30 min',
                  onPriceChanged: (val) {
                    setState(() => _proposedBudget = val);
                  },
                ),
                const SizedBox(height: 28),

                // Publish CTA
                ChambaButton(
                  label: _isPublishing
                      ? 'Despachando alerta SOS...'
                      : (_isSos
                          ? '🚨 Publicar Emergencia SOS (<30 min)'
                          : 'Publicar Solicitud en Chiclayo'),
                  leadingIcon: _isSos ? Icons.emergency : Icons.send_rounded,
                  isLoading: _isPublishing,
                  backgroundColor: _isSos ? AppColors.sosRed : null,
                  onPressed: _isPublishing ? null : _submit,
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

class _AiScanningModalDialog extends StatefulWidget {
  final String scenarioName;
  final IconData icon;
  final Color accentColor;

  const _AiScanningModalDialog({
    required this.scenarioName,
    required this.icon,
    required this.accentColor,
  });

  @override
  State<_AiScanningModalDialog> createState() => _AiScanningModalDialogState();
}

class _AiScanningModalDialogState extends State<_AiScanningModalDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  Timer? _stepTimer;
  int _step = 0;

  final List<String> _steps = const [
    '📸 Procesando captura de foto/video...',
    '🔍 Identificando piezas desgastadas y fallas...',
    '💡 Cotizando repuestos en ferreterías de Chiclayo...',
  ];

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _stepTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (mounted && _step < _steps.length - 1) {
        setState(() => _step++);
      }
    });
  }

  @override
  void dispose() {
    _laserController.dispose();
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scanner Viewfinder Card
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: widget.accentColor.withValues(alpha: 0.6), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Grid background
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(widget.icon, size: 48, color: widget.accentColor.withValues(alpha: 0.85)),
                          const SizedBox(height: 8),
                          Text(
                            widget.scenarioName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    // Viewfinder corner marks
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ViewfinderReticlePainter(color: widget.accentColor),
                      ),
                    ),
                    // Sweeping Laser Beam
                    AnimatedBuilder(
                      animation: _laserController,
                      builder: (context, _) {
                        return Positioned(
                          top: _laserController.value * 140,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  widget.accentColor,
                                  Colors.white,
                                  widget.accentColor,
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.accentColor.withValues(alpha: 0.8),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Escaneo Inteligente Chamba IA',
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                _steps[_step],
                key: ValueKey<int>(_step),
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: widget.accentColor),
                  const SizedBox(width: 6),
                  Text(
                    'Modelo Lambayeque v2.4 (Precisión 98%)',
                    style: TextStyle(
                      color: widget.accentColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewfinderReticlePainter extends CustomPainter {
  final Color color;

  const _ViewfinderReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    const cornerLength = 16.0;
    const padding = 12.0;

    // Top-left
    canvas.drawLine(const Offset(padding, padding + cornerLength), const Offset(padding, padding), paint);
    canvas.drawLine(const Offset(padding, padding), const Offset(padding + cornerLength, padding), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - padding - cornerLength, padding), Offset(size.width - padding, padding), paint);
    canvas.drawLine(Offset(size.width - padding, padding), Offset(size.width - padding, padding + cornerLength), paint);

    // Bottom-left
    canvas.drawLine(Offset(padding, size.height - padding - cornerLength), Offset(padding, size.height - padding), paint);
    canvas.drawLine(Offset(padding, size.height - padding), Offset(padding + cornerLength, size.height - padding), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - padding - cornerLength, size.height - padding), Offset(size.width - padding, size.height - padding), paint);
    canvas.drawLine(Offset(size.width - padding, size.height - padding - cornerLength), Offset(size.width - padding, size.height - padding), paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderReticlePainter oldDelegate) => oldDelegate.color != color;
}
