import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool   _cargando = false;
  bool   _enviado  = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _cargando = true; _error = null; });

    final result = await ApiService.recuperarContrasena(
      _emailCtrl.text.trim().toLowerCase(),
    );

    setState(() => _cargando = false);

    if (result['ok'] == true) {
      setState(() => _enviado = true);
    } else {
      setState(() => _error = result['mensaje'] ?? 'Error al enviar el correo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UTSCColors.fondo,
      appBar: AppBar(
        backgroundColor: UTSCColors.verde,
        foregroundColor: Colors.white,
        title: const Text('Recuperar Contraseña'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _enviado ? _buildExito() : _buildFormulario(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Formulario para ingresar correo ──────────────────────
  Widget _buildFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Ícono
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              color: UTSCColors.verde.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset_outlined,
              size: 48,
              color: UTSCColors.verde,
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Recuperar Contraseña',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: UTSCColors.verde,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ingresa tu correo institucional y te enviaremos un enlace para restablecer tu contraseña.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: UTSCColors.textoGris,
            ),
          ),
          const SizedBox(height: 32),

          // Error
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: UTSCColors.errorFondo,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: UTSCColors.error),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: UTSCColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: UTSCColors.error, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Campo correo
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _enviar(),
            decoration: const InputDecoration(
              labelText: 'Correo institucional',
              hintText: 'usuario@virtual.utsc.edu.mx',
              prefixIcon: Icon(Icons.email_outlined, color: UTSCColors.verde),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Ingresa tu correo';
              }
              if (!v.trim().toLowerCase().endsWith('@virtual.utsc.edu.mx')) {
                return 'Debe ser un correo @virtual.utsc.edu.mx';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Botón enviar
          ElevatedButton.icon(
            onPressed: _cargando ? null : _enviar,
            icon: _cargando
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_outlined),
            label: const Text('Enviar enlace de recuperación'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),

          // Volver al login
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '← Volver al inicio de sesión',
              style: TextStyle(color: UTSCColors.textoGris),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pantalla de éxito ─────────────────────────────────────
  Widget _buildExito() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 100, height: 100,
          decoration: const BoxDecoration(
            color: UTSCColors.aprobadaFondo,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 56,
            color: UTSCColors.aprobada,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '¡Correo enviado!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: UTSCColors.aprobada,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Hemos enviado un enlace de recuperación a:\n${_emailCtrl.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: UTSCColors.textoGris),
        ),
        const SizedBox(height: 8),
        const Text(
          'El enlace expirará en 1 hora.\nRevisa tu carpeta de Spam si no lo ves.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: UTSCColors.textoGris),
        ),
        const SizedBox(height: 40),

        // Instrucciones
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _azul2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _azul.withOpacity(0.3)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pasos siguientes:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _azul,
                      fontSize: 14)),
              SizedBox(height: 8),
              _PasoInstruccion(
                numero: '1',
                texto: 'Abre tu correo @virtual.utsc.edu.mx',
              ),
              _PasoInstruccion(
                numero: '2',
                texto: 'Haz clic en el enlace "Restablecer contraseña"',
              ),
              _PasoInstruccion(
                numero: '3',
                texto: 'Crea tu nueva contraseña en el navegador',
              ),
              _PasoInstruccion(
                numero: '4',
                texto: 'Regresa a la app e inicia sesión',
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Volver al inicio de sesión'),
        ),
      ],
    );
  }
}

const _azul  = Color(0xFF1A5276);
const _azul2 = Color(0xFFEBF5FB);

class _PasoInstruccion extends StatelessWidget {
  final String numero;
  final String texto;
  const _PasoInstruccion({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(
              color: _azul,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(numero,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: const TextStyle(
                    fontSize: 13, color: _azul)),
          ),
        ],
      ),
    );
  }
}
