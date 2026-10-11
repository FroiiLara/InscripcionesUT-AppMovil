import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://inscripciones-8f4j.onrender.com';

  // ── Wake up — despierta Render antes de que el usuario haga login ──
  static Future<void> wakeUp() async {
    try {
      await http
          .get(Uri.parse('$baseUrl/ping'))
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

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
        await prefs.setBool('es_admin', data['es_admin'].toString() == 'true');
        return {'ok': true, ...data};
      }
      return {
        'ok': false,
        'mensaje': data['mensaje'] ?? 'Credenciales incorrectas'
      };
    } catch (e) {
      print('🔴 Error: $e');
      if (e.toString().contains('TimeoutException')) {
        return {
          'ok': false,
          'mensaje':
              'El servidor tardó demasiado. Intenta de nuevo en unos segundos.'
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
          .get(Uri.parse('$baseUrl/api/validar_curp/$curp'), headers: headers)
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
          .get(Uri.parse('$baseUrl/api/admin/solicitudes'), headers: headers)
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
    String? motivo, // obligatorio cuando estatus == 'Rechazada'
  }) async {
    try {
      final headers = await getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/admin/actualizar_estatus'),
            headers: headers,
            body:
                jsonEncode({
              'folio': folio,
              'tipo': tipo,
              'estatus': estatus,
              if (motivo != null) 'motivo': motivo,
            }),
          )
          .timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── DASHBOARD (admin) ─────────────────────────────────────
  static Future<Map<String, dynamic>?> getDashboard(
      {String estatus = 'Todas'}) async {
    try {
      final headers = await getHeaders();
      final uri = Uri.parse('$baseUrl/api/admin/dashboard')
          .replace(queryParameters: {'estatus': estatus});
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── REPORTES EXCEL (admin) ────────────────────────────────
  // Pide al servidor un enlace temporal de descarga (válido unos minutos)
  // que luego se abre en el navegador del teléfono.
  static Future<Map<String, dynamic>> crearEnlaceReporte({
    required String tipo,
    String estatus = 'Todas',
    String carrera = 'Todas',
    String? desde, // AAAA-MM-DD
    String? hasta, // AAAA-MM-DD
  }) async {
    try {
      final headers = await getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/admin/reportes/enlace'),
            headers: headers,
            body: jsonEncode({
              'tipo': tipo,
              'estatus': estatus,
              'carrera': carrera,
              'desde': desde ?? '',
              'hasta': hasta ?? '',
            }),
          )
          .timeout(const Duration(seconds: 60));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {...data, 'ok': response.statusCode == 200 && data['ok'] == true};
    } catch (_) {
      return {'ok': false, 'mensaje': 'Error de conexión. Intenta de nuevo.'};
    }
  }

  // ── RECUPERAR CONTRASEÑA ──────────────────────────────────
  static Future<Map<String, dynamic>> recuperarContrasena(String email) async {
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
      return {'ok': false, 'mensaje': 'Error de conexión. Intenta de nuevo.'};
    }
  }
}
