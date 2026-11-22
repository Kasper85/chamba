import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/services/camera_image_service.dart';
import '../../data/services/api_client.dart';
import '../../data/services/auth_api_service.dart';
import '../state/app_state.dart';

class AddPortfolioScreen extends StatefulWidget {
  final AppState appState;
  const AddPortfolioScreen({super.key, required this.appState});
  @override
  State<AddPortfolioScreen> createState() => _AddPortfolioScreenState();
}

class _AddPortfolioScreenState extends State<AddPortfolioScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _beforeDescription = TextEditingController();
  final _afterDescription = TextEditingController();
  Uint8List? _before;
  Uint8List? _after;
  bool _busy = false;
  @override
  void dispose() {
    _title.dispose();
    _beforeDescription.dispose();
    _afterDescription.dispose();
    super.dispose();
  }

  Future<void> _pick(bool before, ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await CameraImageService().pick(source);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 500000 ||
          bytes.length < 2 ||
          bytes[0] != 255 ||
          bytes[1] != 216) {
        throw const FormatException(
          'Selecciona una foto JPEG de hasta 500 KB.',
        );
      }
      if (mounted) {
        setState(() {
          if (before) {
            _before = bytes;
          } else {
            _after = bytes;
          }
        });
      }
    } on CameraPermissionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Permite el acceso a la cámara para tomar fotos.',
            ),
            action: e.blocked
                ? SnackBarAction(
                    label: 'Ajustes',
                    onPressed: CameraImageService.openSettings,
                  )
                : null,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo cargar la foto. Usa una imagen JPEG de hasta 500 KB.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_before == null || _after == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega las fotos del antes y después.')),
      );
      return;
    }
    final token = widget.appState.authToken;
    if (token == null) return;
    setState(() => _busy = true);
    try {
      await ApiClient().post(
        '/api/v1/worker-profile/me/portfolio',
        token: token,
        body: {
          'title': _title.text.trim(),
          'category':
              widget.appState.currentUser?.workerProfile?.specialty ?? '',
          'beforeDescription': _beforeDescription.text.trim(),
          'afterDescription': _afterDescription.text.trim(),
          'beforeImageUrl': 'data:image/jpeg;base64,${base64Encode(_before!)}',
          'afterImageUrl': 'data:image/jpeg;base64,${base64Encode(_after!)}',
        },
      );
      final user = await AuthApiService().getMe(token);
      await widget.appState.setSession(user, token);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Agregar obra')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: _title,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Título del trabajo'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Ingresa el título' : null,
          ),
          _photoSection(true, _before),
          TextFormField(
            controller: _beforeDescription,
            maxLength: 600,
            decoration: const InputDecoration(labelText: 'Estado inicial'),
          ),
          _photoSection(false, _after),
          TextFormField(
            controller: _afterDescription,
            maxLength: 600,
            decoration: const InputDecoration(labelText: 'Trabajo realizado'),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Procesando…' : 'Guardar obra'),
          ),
        ],
      ),
    ),
  );
  Widget _photoSection(bool before, Uint8List? bytes) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        before ? 'Antes' : 'Después',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (bytes != null) Image.memory(bytes, height: 180, fit: BoxFit.cover),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _pick(before, ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Tomar foto'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _pick(before, ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Galería'),
          ),
        ],
      ),
    ],
  );
}
