import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento CIFRADO para lo sensible (tokens de sesión).
/// En Android usa EncryptedSharedPreferences (clave guardada en el Keystore del
/// teléfono) y en iOS el Keychain. SharedPreferences normal guarda texto plano
/// y cualquiera con acceso al archivo (root, respaldo, otra app con fallos) lo lee.
class SecureStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static const kAccessToken  = 'access_token';
  static const kRefreshToken = 'refresh_token';
  static const kBioHabilitado = 'bio_habilitado';

  static Future<String?> leer(String clave) async {
    try {
      return await _storage.read(key: clave);
    } catch (_) {
      // Si el almacén quedó corrupto (p. ej. tras restaurar el teléfono) se limpia.
      try { await _storage.deleteAll(); } catch (_) {}
      return null;
    }
  }

  static Future<void> guardar(String clave, String valor) async {
    try {
      await _storage.write(key: clave, value: valor);
    } catch (_) {}
  }

  static Future<void> borrar(String clave) async {
    try {
      await _storage.delete(key: clave);
    } catch (_) {}
  }

  /// Versiones anteriores de la app guardaban el token JWT y hasta la CONTRASEÑA del
  /// login biométrico en SharedPreferences (texto plano). Al actualizar, se borran.
  /// El alumno tendrá que volver a activar la huella una vez.
  static Future<void> migrarDatosAntiguos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final clave in const ['jwt_token', 'bio_password', 'bio_matricula']) {
        if (prefs.containsKey(clave)) await prefs.remove(clave);
      }
      if (prefs.containsKey('bio_habilitado')) await prefs.remove('bio_habilitado');
    } catch (_) {}
  }
}
