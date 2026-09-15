import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  // ── Verificar si el dispositivo soporta biométricos ───────
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  // ── Obtener tipos de biométrico disponibles ────────────────
  static Future<List<BiometricType>> getBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  // ── Autenticar con biométrico ─────────────────────────────
  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Usa tu huella digital o Face ID para iniciar sesión',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // permite PIN como respaldo
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // ── Guardar credenciales para login biométrico ────────────
  static Future<void> guardarCredenciales(
      String matricula, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bio_matricula', matricula);
    await prefs.setString('bio_password', password);
    await prefs.setBool('bio_habilitado', true);
  }

  // ── Obtener credenciales guardadas ────────────────────────
  static Future<Map<String, String>?> obtenerCredenciales() async {
    final prefs = await SharedPreferences.getInstance();
    final habilitado = prefs.getBool('bio_habilitado') ?? false;
    if (!habilitado) return null;
    final matricula = prefs.getString('bio_matricula');
    final password  = prefs.getString('bio_password');
    if (matricula == null || password == null) return null;
    return {'matricula': matricula, 'password': password};
  }

  // ── Verificar si el biométrico está habilitado ────────────
  static Future<bool> estaHabilitado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('bio_habilitado') ?? false;
  }

  // ── Deshabilitar biométrico ───────────────────────────────
  static Future<void> deshabilitar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bio_habilitado', false);
    await prefs.remove('bio_matricula');
    await prefs.remove('bio_password');
  }
}
