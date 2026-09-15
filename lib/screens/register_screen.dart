import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _matriculaCtrl  = TextEditingController();
  final _nombreCtrl     = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();

  bool   _cargando        = false;
  bool   _mostrarPassword = false;
  String? _errorMensaje;

  bool get _rLen   => _passwordCtrl.text.length >= 8;
  bool get _rUpper => _passwordCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _rLower => _passwordCtrl.text.contains(RegExp(r'[a-z]'));
  bool get _rNum   => _passwordCtrl.text.contains(RegExp(r'[0-9]'));
  bool get _rSim   => _passwordCtrl.text.contains(RegExp(r'[^a-zA-Z0-9\s]'));
  bool get _passOk => _rLen && _rUpper && _rLower && _rNum && _rSim;

  @override
  void dispose() {
    _matriculaCtrl.dispose();
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_passOk) {
      setState(() => _errorMensaje = 'La contraseña no cumple todos los requisitos.');
      return;
    }
    setState(() { _cargando = true; _errorMensaje = null; });

    final result = await ApiService.registro(
      matricula: _matriculaCtrl.text.trim(),
      nombre:    _nombreCtrl.text.trim(),
      email:     _emailCtrl.text.trim().toLowerCase(),
      password:  _passwordCtrl.text,
    );

    setState(() => _cargando = false);

    if (result['ok'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('¡Cuenta creada! Inicia sesión.'),
          backgroundColor: UTSCColors.verde,
        ));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      setState(() => _errorMensaje = result['mensaje'] ?? 'Error al registrarse.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UTSCColors.fondo,
      appBar: AppBar(
        backgroundColor: UTSCColors.verde,
        foregroundColor: Colors.white,
        title: const Text('Registro de Usuario'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Icon(Icons.school_rounded, size: 60, color: UTSCColors.verde),
                    const SizedBox(height: 8),
                    const Text('Crear cuenta',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: UTSCColors.verde)),
                    const Text('Sistema de Inscripciones UTSC',
                        style: TextStyle(fontSize: 13, color: UTSCColors.textoGris)),
                    const SizedBox(height: 24),

                    if (_errorMensaje != null) ...[
                      _ErrorCaja(mensaje: _errorMensaje!),
                      const SizedBox(height: 12),
                    ],

                    // Matrícula
                    TextFormField(
                      controller: _matriculaCtrl,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Matrícula',
                        hintText: 'Solo números',
                        prefixIcon: Icon(Icons.badge_outlined, color: UTSCColors.verde),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Ingresa tu matrícula';
                        if (v.trim().length < 4) return 'Matrícula inválida';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Nombre
                    TextFormField(
                      controller: _nombreCtrl,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        hintText: 'Ej. Juan Carlos Pérez Martínez',
                        prefixIcon: Icon(Icons.person_outline, color: UTSCColors.verde),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length < 5) {
                          return 'Ingresa tu nombre completo (mínimo 5 caracteres)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Correo
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Correo institucional',
                        hintText: 'usuario@virtual.utsc.edu.mx',
                        prefixIcon: Icon(Icons.email_outlined, color: UTSCColors.verde),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                        if (!v.trim().toLowerCase().endsWith('@virtual.utsc.edu.mx')) {
                          return 'Debe ser @virtual.utsc.edu.mx';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Contraseña
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: !_mostrarPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _registrar(),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline, color: UTSCColors.verde),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _mostrarPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _mostrarPassword = !_mostrarPassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Reglas de contraseña
                    _ReglasContrasena(
                      rLen: _rLen, rUpper: _rUpper,
                      rLower: _rLower, rNum: _rNum, rSim: _rSim,
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _cargando ? null : _registrar,
                      child: _cargando
                          ? const SizedBox(height: 22, width: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Registrarse'),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('¿Ya tienes cuenta? ',
                            style: TextStyle(fontSize: 13, color: UTSCColors.textoGris)),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text('Inicia sesión aquí',
                              style: TextStyle(fontSize: 13, color: UTSCColors.verde, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCaja extends StatelessWidget {
  final String mensaje;
  const _ErrorCaja({required this.mensaje});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UTSCColors.errorFondo,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: UTSCColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: UTSCColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(mensaje, style: const TextStyle(color: UTSCColors.error, fontSize: 13))),
        ],
      ),
    );
  }
}

class _ReglasContrasena extends StatelessWidget {
  final bool rLen, rUpper, rLower, rNum, rSim;
  const _ReglasContrasena({required this.rLen, required this.rUpper,
      required this.rLower, required this.rNum, required this.rSim});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: UTSCColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('La contraseña debe tener:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: UTSCColors.textoGris)),
          const SizedBox(height: 8),
          _Regla(ok: rLen,   texto: 'Mínimo 8 caracteres'),
          _Regla(ok: rUpper, texto: 'Una mayúscula (A-Z)'),
          _Regla(ok: rLower, texto: 'Una minúscula (a-z)'),
          _Regla(ok: rNum,   texto: 'Un número (0-9)'),
          _Regla(ok: rSim,   texto: 'Un símbolo (!@#\$...)'),
        ],
      ),
    );
  }
}

class _Regla extends StatelessWidget {
  final bool ok;
  final String texto;
  const _Regla({required this.ok, required this.texto});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.circle_outlined,
              size: 16, color: ok ? UTSCColors.aprobada : UTSCColors.textoGris),
          const SizedBox(width: 8),
          Text(texto, style: TextStyle(fontSize: 13,
              color: ok ? UTSCColors.aprobada : UTSCColors.textoGris)),
        ],
      ),
    );
  }
}
