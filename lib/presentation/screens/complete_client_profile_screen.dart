import 'package:flutter/material.dart';

import '../../core/widgets/chamba_button.dart';
import '../../data/services/auth_api_service.dart';
import '../state/app_state.dart';
import 'app_shell_gate.dart';

class CompleteClientProfileScreen extends StatefulWidget {
  final AppState appState;
  final bool isRegistration;
  final AuthApiService? authApi;
  const CompleteClientProfileScreen({
    super.key,
    required this.appState,
    this.isRegistration = false,
    this.authApi,
  });

  @override
  State<CompleteClientProfileScreen> createState() =>
      _CompleteClientProfileScreenState();
}

class _CompleteClientProfileScreenState
    extends State<CompleteClientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _district;
  late final TextEditingController _address;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.appState.currentUser;
    _name = TextEditingController(text: user?.fullName ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _district = TextEditingController(text: user?.district ?? '');
    _address = TextEditingController(text: user?.address ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _district.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate() ||
        widget.appState.authToken == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final user = await (widget.authApi ?? AuthApiService()).updateMe(
        widget.appState.authToken!,
        fullName: _name.text,
        phone: _phone.text,
        district: _district.text,
        address: _address.text,
      );
      await widget.appState.setSession(user, widget.appState.authToken!);
      if (!mounted) return;
      if (!widget.isRegistration) {
        Navigator.of(context).pop();
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AppShellGate(appState: widget.appState),
        ),
        (_) => false,
      );
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.isRegistration ? 'Completa tu perfil' : 'Editar perfil',
      ),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Cuéntanos tus datos para personalizar CHAMBA.'),
          const SizedBox(height: 20),
          _field(
            _name,
            'Nombre completo',
            Icons.person_outline,
            required: true,
          ),
          _field(_phone, 'Teléfono', Icons.phone_outlined),
          _field(
            _district,
            'Ciudad o distrito',
            Icons.location_city_outlined,
            required: true,
          ),
          _field(_address, 'Dirección de referencia', Icons.home_outlined),
          const SizedBox(height: 24),
          ChambaButton(
            label: _saving ? 'Guardando...' : 'Guardar perfil',
            isLoading: _saving,
            onPressed: _saving ? null : _save,
            leadingIcon: Icons.check,
          ),
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? 'Completa este campo' : null
          : null,
    ),
  );
}
