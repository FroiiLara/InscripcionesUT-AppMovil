import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../services/biometric_service.dart';

class LoginScreen extends StatefulWidget {
  /// Mensaje que se muestra al abrir (p. ej. "Tu sesión expiró").
  final String? mensajeInicial;
  const LoginScreen({super.key, this.mensajeInicial});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey          = GlobalKey<FormState>();
  final _matriculaCtrl    = TextEditingController();
  final _passwordCtrl     = TextEditingController();
  bool   _cargando        = false;
  bool   _mostrarPassword = false;
  String? _errorMensaje;
  bool _bioDisponible  = false;
  bool _bioHabilitado  = false;

  @override
  void initState() {
    super.initState();
    _errorMensaje = widget.mensajeInicial;
    _verificarBiometrico();
  }

  Future<void> _verificarBiometrico() async {
    final disponible = await BiometricService.isAvailable();
    final habilitado = await BiometricService.estaHabilitado();
    if (!mounted) return;
    setState(() {
      _bioDisponible = disponible;
      _bioHabilitado = habilitado;
    });
  }

  // La huella NO guarda la contraseña: solo desbloquea la sesión que el servidor ya
  // entregó (refresh token cifrado), que se canjea por tokens nuevos.
  Future<void> _loginBiometrico() async {
    final autenticado = await BiometricService.authenticate();
    if (!autenticado) return;

    setState(() { _cargando = true; _errorMensaje = null; });
    final result = await ApiService.restaurarSesion();
    if (!mounted) return;
    setState(() => _cargando = false);

    if (result['ok'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else if (result['expirada'] == true) {
      // El servidor ya no acepta la sesión rápida: se desactiva y se pide la contraseña.
      await BiometricService.deshabilitar();
      if (!mounted) return;
      setState(() {
        _bioHabilitado = false;
        _errorMensaje = 'Tu sesión rápida expiró. Inicia sesión con tu matrícula y contraseña.';
      });
    } else {
      setState(() => _errorMensaje = result['mensaje'] ?? 'No se pudo iniciar sesión.');
    }
  }

  @override
  void dispose() {
    _matriculaCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _cargando = true; _errorMensaje = null; });

    final result = await ApiService.login(
      _matriculaCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _cargando = false);

    if (result['ok'] == true) {
      _passwordCtrl.clear(); // la contraseña no debe quedarse en memoria de la pantalla
      if (_bioDisponible && !_bioHabilitado && mounted) {
        await _ofrecerBiometrico();
      } else if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      setState(() => _errorMensaje = result['mensaje'] ?? 'Error al iniciar sesión.');
    }
  }

  Future<void> _ofrecerBiometrico() async {
    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.fingerprint, color: UTSCColors.verde, size: 28),
          SizedBox(width: 8),
          Text('Acceso rápido'),
        ]),
        content: const Text(
            '¿Quieres activar el inicio de sesión con huella digital o Face ID?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ahora no',
                style: TextStyle(color: UTSCColors.textoGris)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
    if (guardar == true) {
      await BiometricService.habilitar(); // solo una bandera: no se guarda la contraseña
      if (mounted) setState(() => _bioHabilitado = true);
    }
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UTSCColors.fondo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 32),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Iniciar Sesión',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: UTSCColors.verde)),
                            const Text('Sistema de Inscripciones UTSC',
                                style: TextStyle(
                                    fontSize: 13, color: UTSCColors.textoGris)),
                            const SizedBox(height: 28),
                            if (_errorMensaje != null) ...[
                              _ErrorBox(mensaje: _errorMensaje!),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _matriculaCtrl,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Matrícula',
                                hintText: 'Ej. 220001',
                                prefixIcon: Icon(Icons.badge_outlined,
                                    color: UTSCColors.verde),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Ingresa tu matrícula';
                                }
                                if (v.trim().length < 4) {
                                  return 'Matrícula inválida';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: !_mostrarPassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _iniciarSesion(),
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock_outline,
                                    color: UTSCColors.verde),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _mostrarPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => setState(() =>
                                      _mostrarPassword = !_mostrarPassword),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Ingresa tu contraseña';
                                }
                                if (v.length < 6) {
                                  return 'Mínimo 6 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const ForgotPasswordScreen()),
                                ),
                                child: const Text('¿Olvidaste tu contraseña?',
                                    style: TextStyle(
                                        color: UTSCColors.naranja,
                                        fontSize: 13)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _cargando ? null : _iniciarSesion,
                              child: _cargando
                                  ? const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          height: 22, width: 22,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5)),
                                        SizedBox(height: 4),
                                        Text('Conectando...',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.white70)),
                                      ],
                                    )
                                  : const Text('Iniciar Sesión'),
                            ),
                            const SizedBox(height: 16),
                            // Botón biométrico
                            if (_bioDisponible && _bioHabilitado)
                              OutlinedButton.icon(
                                onPressed: _cargando ? null : _loginBiometrico,
                                icon: const Icon(Icons.fingerprint,
                                    color: UTSCColors.verde, size: 24),
                                label: const Text('Entrar con biométrico',
                                    style: TextStyle(color: UTSCColors.verde)),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 52),
                                  side: const BorderSide(color: UTSCColors.verde),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            if (_bioDisponible && _bioHabilitado)
                              const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('¿No tienes cuenta? ',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: UTSCColors.textoGris)),
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const RegisterScreen()),
                                  ),
                                  child: const Text('Regístrate',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: UTSCColors.verde,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Aviso de Privacidad',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          decoration: TextDecoration.underline)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // Logo real de la UTSC
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: UTSCColors.verde.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Image.asset(
              'assets/images/logo_utsc.png',
              fit: BoxFit.contain,
              // Si el logo no carga muestra el ícono de respaldo
              errorBuilder: (ctx, err, stack) => const Icon(
                Icons.school_rounded,
                size: 80,
                color: UTSCColors.verde,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Universidad Tecnológica de Santa Catarina',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
  );
  }
} // end _LoginScreenState

class _ErrorBox extends StatelessWidget {
  final String mensaje;
  const _ErrorBox({required this.mensaje});

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
          Expanded(
            child: Text(mensaje,
                style: const TextStyle(color: UTSCColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
