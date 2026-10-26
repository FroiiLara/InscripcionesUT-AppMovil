import 'package:local_auth/local_auth.dart';
import '../utils/log.dart';
import 'secure_store.dart';

/// Inicio de sesión con huella / rostro.
///
/// IMPORTANTE (seguridad): la contraseña del alumno NUNCA se guarda en el teléfono.
/// Al activar la huella solo se marca una bandera; la sesión rápida usa el
/// "refresh token" que el servidor entregó al iniciar sesión (guardado cifrado y que
/// el servidor puede revocar). Si ese token vence o se revoca, se pide la contraseña.
class BiometricService {
  static final _auth = LocalAuthentication();

  // ── Verificar si el dispositivo soporta biométricos ───────
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      logDebug('Biometría: canCheck=$canCheck, supported=$isSupported');
      return canCheck && isSupported;
    } catch (e) {
      logDebug('Biometría isAvailable falló: $e');
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
          biometricOnly: true, // sin PIN de respaldo: solo huella / rostro
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      logDebug('Biometría: $e');
      return false;
    }
  }

  // ── Activar la sesión rápida (no guarda la contraseña) ────
  static Future<bool> habilitar() async {
    final refresh = await SecureStore.leer(SecureStore.kRefreshToken);
    logDebug('Activar huella: refresh token presente = ${refresh != null && refresh.isNotEmpty}');
    if (refresh == null || refresh.isEmpty) return false; // el servidor no entregó sesión renovable
    return SecureStore.guardar(SecureStore.kBioHabilitado, 'true');
  }

  // ── ¿Está activada y hay una sesión que renovar? ──────────
  static Future<bool> estaHabilitado() async {
    final bandera = await SecureStore.leer(SecureStore.kBioHabilitado);
    final refresh = await SecureStore.leer(SecureStore.kRefreshToken);
    return bandera == 'true' && refresh != null && refresh.isNotEmpty;
  }

  // ── Desactivar ────────────────────────────────────────────
  static Future<void> deshabilitar() async {
    await SecureStore.borrar(SecureStore.kBioHabilitado);
  }
}
