import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/permisos_service.dart';
import '../constants/colors.dart';
import '../services/api_service.dart';

/// Formulario para abrir una consulta con Control Escolar.
class NuevaConsultaScreen extends StatefulWidget {
  const NuevaConsultaScreen({super.key});
  @override
  State<NuevaConsultaScreen> createState() => _NuevaConsultaScreenState();
}

class _NuevaConsultaScreenState extends State<NuevaConsultaScreen> {
  static const _categorias = [
    'Inscripción', 'Reinscripción', 'Documentos', 'Pagos', 'Cuenta y acceso', 'Otro'
  ];
  final _form = GlobalKey<FormState>();
  final _asunto = TextEditingController();
  final _mensaje = TextEditingController();
  String? _categoria;
  bool _enviando = false;
  final SpeechToText _voz = SpeechToText();
  bool _escuchando = false;
  String _baseDictado = '';

  /// Dictado por voz: pide permiso de micrófono y convierte la voz en texto del mensaje.
  Future<void> _dictar() async {
    if (_escuchando) {
      await _voz.stop();
      setState(() => _escuchando = false);
      return;
    }
    if (!await PermisosService.asegurar(context, AppPermiso.microfono)) return;
    final disponible = await _voz.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) setState(() => _escuchando = false);
      },
      onError: (_) {
        if (mounted) setState(() => _escuchando = false);
      },
    );
    if (!disponible) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('El dictado por voz no está disponible en este dispositivo. Escribe tu mensaje.')));
      }
      return;
    }
    _baseDictado = _mensaje.text.trim();
    setState(() => _escuchando = true);
    await _voz.listen(
      localeId: 'es_MX',
      listenFor: const Duration(seconds: 60),
      onResult: (r) {
        final dictado = r.recognizedWords;
        final texto = _baseDictado.isEmpty ? dictado : '$_baseDictado $dictado';
        _mensaje.text = texto.length > 2000 ? texto.substring(0, 2000) : texto;
        _mensaje.selection = TextSelection.collapsed(offset: _mensaje.text.length);
      },
    );
  }

  @override
  void dispose() {
    _voz.cancel();
    _asunto.dispose();
    _mensaje.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _enviando = true);
    final r = await ApiService.crearConsulta(
        _categoria!, _asunto.text.trim(), _mensaje.text.trim());
    if (!mounted) return;
    setState(() => _enviando = false);
    if (r['ok'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Consulta enviada. Te avisaremos cuando Control Escolar responda.')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: UTSCColors.error, content: Text(r['mensaje'].toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UTSCColors.fondo,
      appBar: AppBar(
          backgroundColor: UTSCColors.verde,
          foregroundColor: Colors.white,
          title: const Text('Nueva consulta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DropdownButtonFormField<String>(
              value: _categoria,
              decoration: const InputDecoration(
                  labelText: 'Categoría', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              items: [for (final c in _categorias) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _categoria = v),
              validator: (v) => v == null ? 'Elige una categoría' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _asunto,
              maxLength: 120,
              decoration: const InputDecoration(
                  labelText: 'Asunto', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              validator: (v) =>
                  (v == null || v.trim().length < 5) ? 'Mínimo 5 caracteres' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _mensaje,
              maxLength: 2000,
              minLines: 6,
              maxLines: 10,
              decoration: InputDecoration(
                  labelText: 'Describe tu duda',
                  alignLabelWithHint: true,
                  suffixIcon: IconButton(
                    tooltip: _escuchando ? 'Detener dictado' : 'Dictar por voz',
                    icon: Icon(_escuchando ? Icons.mic : Icons.mic_none,
                        color: _escuchando ? UTSCColors.error : UTSCColors.verde),
                    onPressed: _dictar,
                  ),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white),
              validator: (v) =>
                  (v == null || v.trim().length < 10) ? 'Mínimo 10 caracteres' : null,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _enviando ? null : _enviar,
                icon: _enviando
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: const Text('Enviar consulta'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: UTSCColors.naranja, foregroundColor: Colors.white),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
