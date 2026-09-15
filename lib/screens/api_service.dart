import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://inscripciones-8f4j.onrender.com';

  // ── Wake up — despierta Render en segundo plano ───────────
  static Future<void> wakeUp() async {
    try {
      await http
          .get(Uri.parse('$baseUrl/ping'))
          .timeout(const Duration(seconds: 20));
      print('🟢 Servidor despierto');
    } catch (e) {
      print('⚠️ Wake up: $e');
    }
  }

  // ── Token JWT ─────────────────────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('usuario_nombre');
    await prefs.remove('es_admin');
  }

  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── LOGIN ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
      String matricula, String password) async {
    try {
      print('🔵 Intentando login: $baseUrl/api/login');
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'matricula': matricula,
              'contrasena': password,
            }),
          )
          .timeout(const Duration(seconds: 90));

      print('🟢 Respuesta: ${response.statusCode}');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        await saveToken(data['access_token'] ?? '');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('usuario_nombre', data['usuario'] ?? '');
        await prefs.setBool(
            'es_admin', data['es_admin'].toString() == 'true');
        return {'ok': true, ...data};
      }
      return {
        'ok': false,
        'mensaje': data['mensaje'] ?? 'Credenciales incorrectas'
      };
    } catch (e) {
      print('🔴 Error login: $e');
      if (e.toString().contains('TimeoutException')) {
        return {
          'ok': false,
          'mensaje': 'El servidor tardó demasiado. Intenta de nuevo en unos segundos.'
        };
      }
      return {
        'ok': false,
        'mensaje': 'Error de conexión. Verifica tu internet.'
      };
    }
  }

  // ── REGISTRO ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> registro({
    required String matricula,
    required String nombre,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/registro'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'matricula': matricula,
              'usuario': nombre,
              'email': email,
              'contrasena': password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'ok': response.statusCode == 200 || response.statusCode == 201,
        'mensaje': data['mensaje'] ?? '',
      };
    } catch (_) {
      return {'ok': false, 'mensaje': 'Error de conexión.'};
    }
  }

  // ── HISTORIAL ─────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getHistorial() async {
    try {
      final headers = await getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/historial'), headers: headers)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── VALIDAR CURP ──────────────────────────────────────────
  static Future<Map<String, dynamic>> validarCurp(String curp) async {
    try {
      final headers = await getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/validar_curp/$curp'),
              headers: headers)
          .timeout(const Duration(seconds: 15));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {
        'valida': null,
        'mensaje': 'Servicio RENAPO no disponible. Puedes continuar.',
      };
    }
  }

  // ── PERFIL ────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getPerfil() async {
    try {
      final headers = await getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/perfil'), headers: headers)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── ADMIN ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getSolicitudesAdmin() async {
    try {
      final headers = await getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/admin/solicitudes'),
              headers: headers)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> actualizarEstatus({
    required String folio,
    required String tipo,
    required String estatus,
  }) async {
    try {
      final headers = await getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/admin/actualizar_estatus'),
            headers: headers,
            body: jsonEncode(
                {'folio': folio, 'tipo': tipo, 'estatus': estatus}),
          )
          .timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── RECUPERAR CONTRASEÑA ──────────────────────────────────
  static Future<Map<String, dynamic>> recuperarContrasena(
      String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/recuperar_contrasena'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'ok': response.statusCode == 200,
        'mensaje': data['mensaje'] ?? '',
      };
    } catch (_) {
      return {
        'ok': false,
        'mensaje': 'Error de conexión. Intenta de nuevo.'
      };
    }
  }
}
