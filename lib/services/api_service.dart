import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/log.dart';
import 'secure_store.dart';

class ApiService {
  static const String baseUrl = 'https://inscripciones-8f4j.onrender.com';

  /// Tamaño máximo por documento (el servidor aplica el mismo límite).
  static const int maxArchivoBytes = 5 * 1024 * 1024;

  /// La pantalla principal asigna esto para volver al login cuando la sesión
  /// ya no se puede renovar (refresh token vencido o revocado).
  static void Function()? onSesionExpirada;
  static bool _cerrandoSesion = false;

  // ── Wake up — despierta Render antes de que el usuario haga login ──
  static Future<void> wakeUp() async {
    try {
      await http
          .get(Uri.parse('$baseUrl/ping'))
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════
  //  SESIÓN (tokens guardados CIFRADOS con flutter_secure_storage)
  // ══════════════════════════════════════════════════════════

  static Future<String?> getToken() => SecureStore.leer(SecureStore.kAccessToken);

  static Future<void> saveToken(String token) =>
      SecureStore.guardar(SecureStore.kAccessToken, token);

  /// Borra la sesión SOLO en el teléfono (tokens, datos de usuario y huella).
  static Future<void> clearToken() async {
    await SecureStore.borrar(SecureStore.kAccessToken);
    await SecureStore.borrar(SecureStore.kRefreshToken);
    await SecureStore.borrar(SecureStore.kBioHabilitado);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('usuario_nombre');
    await prefs.remove('es_admin');
    await prefs.remove('matricula');
  }

  /// Cierra la sesión.
  /// - Con la huella activada: solo "bloquea" la app (borra el access token) y conserva el
  ///   refresh token cifrado, para poder volver a entrar con la huella sin contraseña.
  /// - Sin huella: revoca los tokens en el servidor y limpia todo el teléfono.
  static Future<void> cerrarSesion() async {
    final bandera = await SecureStore.leer(SecureStore.kBioHabilitado);
    final refresh = await SecureStore.leer(SecureStore.kRefreshToken);
    if (bandera == 'true' && refresh != null && refresh.isNotEmpty) {
      await SecureStore.borrar(SecureStore.kAccessToken);
      return;
    }
    _cerrandoSesion = true;
    try {
      await _conAuth((h) => http
          .post(Uri.parse('$baseUrl/api/logout'),
              headers: h, body: jsonEncode({'refresh_token': refresh}))
          .timeout(const Duration(seconds: 10)));
    } catch (_) {
      // Sin internet: igual se cierra la sesión localmente.
    } finally {
      await clearToken();
      _cerrandoSesion = false;
    }
  }

  static Future<void> _guardarSesion(Map<String, dynamic> data) async {
    final access = data['access_token'];
    final refresh = data['refresh_token'];
    if (access is String && access.isNotEmpty) {
      await SecureStore.guardar(SecureStore.kAccessToken, access);
    }
    if (refresh is String && refresh.isNotEmpty) {
      await SecureStore.guardar(SecureStore.kRefreshToken, refresh);
    }
    final prefs = await SharedPreferences.getInstance();
    if (data['usuario'] != null) {
      await prefs.setString('usuario_nombre', data['usuario'].toString());
    }
    if (data['matricula'] != null) {
      await prefs.setString('matricula', data['matricula'].toString());
    }
    if (data.containsKey('es_admin')) {
      await prefs.setBool('es_admin', data['es_admin'].toString() == 'true');
    }
  }

  static Map<String, dynamic> _json(http.Response r) {
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      if (d is Map<String, dynamic>) return d;
    } catch (_) {}
    return {};
  }

  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Evita que dos peticiones simultáneas renueven a la vez (el refresh token es de un solo uso).
  static Future<Map<String, dynamic>>? _renovando;

  /// Canjea el refresh token por tokens nuevos.
  /// Devuelve {'ok': true} o {'ok': false, 'expirada': true/false, 'mensaje': ...}.
  /// 'expirada' = el servidor ya no acepta ese token (hay que pedir contraseña);
  /// si solo falló la conexión, 'expirada' es false y no se pierde la sesión.
  static Future<Map<String, dynamic>> restaurarSesion() {
    return _renovando ??= _renovarSesion().whenComplete(() => _renovando = null);
  }

  static Future<Map<String, dynamic>> _renovarSesion() async {
    final refresh = await SecureStore.leer(SecureStore.kRefreshToken);
    if (refresh == null || refresh.isEmpty) {
      return {'ok': false, 'expirada': true};
    }
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/api/refresh'),
        headers: {'Authorization': 'Bearer $refresh', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 90));
      if (r.statusCode == 200) {
        await _guardarSesion(_json(r));
        return {'ok': true};
      }
      if (r.statusCode == 401) {
        await clearToken();
        return {'ok': false, 'expirada': true};
      }
      return {
        'ok': false,
        'expirada': false,
        'mensaje': 'El servidor no respondió. Intenta de nuevo.'
      };
    } catch (_) {
      return {
        'ok': false,
        'expirada': false,
        'mensaje': 'Error de conexión. Verifica tu internet.'
      };
    }
  }

  /// Ejecuta una petición con el token actual; si el servidor responde 401
  /// (access token de 15 min vencido) renueva la sesión y reintenta UNA vez.
  static Future<http.Response> _conAuth(
      Future<http.Response> Function(Map<String, String> headers) enviar) async {
    var resp = await enviar(await getHeaders());
    if (resp.statusCode == 401) {
      final r = await restaurarSesion();
      if (r['ok'] == true) {
        resp = await enviar(await getHeaders());
      } else if (r['expirada'] == true && !_cerrandoSesion) {
        onSesionExpirada?.call();
      }
    }
    return resp;
  }

  // ── LOGIN ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
      String matricula, String password) async {
    try {
      logDebug('Intentando login: $baseUrl/api/login');
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

      logDebug('Respuesta login: ${response.statusCode}');
      final data = _json(response);
      if (response.statusCode == 200) {
        await _guardarSesion(data);
        return {
          'ok': true,
          'usuario': data['usuario'],
          'matricula': data['matricula'],
          'es_admin': data['es_admin'],
        };
      }
      if (response.statusCode == 429) {
        return {
          'ok': false,
          'mensaje': data['mensaje'] ?? 'Demasiados intentos. Espera un momento.'
        };
      }
      return {
        'ok': false,
        'mensaje': data['mensaje'] ?? 'Credenciales incorrectas'
      };
    } catch (e) {
      logDebug('Error login: $e');
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

      final data = _json(response);
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
      final response = await _conAuth((h) => http
          .get(Uri.parse('$baseUrl/api/historial'), headers: h)
          .timeout(const Duration(seconds: 30)));
      if (response.statusCode == 200) return _json(response);
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── VALIDAR CURP (servicio externo; solo si el alumno lo autoriza) ──
  static Future<Map<String, dynamic>> validarCurp(String curp) async {
    try {
      final response = await _conAuth((h) => http
          .get(Uri.parse('$baseUrl/api/validar_curp/$curp'), headers: h)
          .timeout(const Duration(seconds: 15)));
      return _json(response);
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
      final response = await _conAuth((h) => http
          .get(Uri.parse('$baseUrl/api/perfil'), headers: h)
          .timeout(const Duration(seconds: 30)));
      if (response.statusCode == 200) return _json(response);
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── INSCRIPCIÓN / REINSCRIPCIÓN (envío real al servidor) ──
  /// Detecta el tipo REAL del archivo por su contenido (no por el nombre), porque el
  /// servidor también revisa los primeros bytes y rechaza extensiones que no coinciden.
  static Future<String> _extensionReal(XFile f) async {
    final b = <int>[];
    await for (final trozo in f.openRead(0, 8)) {
      b.addAll(trozo);
      if (b.length >= 8) break;
    }
    if (b.length >= 4 && b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46) {
      return 'pdf';
    }
    if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return 'png';
    }
    return 'jpg';
  }

  static Future<Map<String, dynamic>> _enviarTramite(
    String ruta,
    Map<String, String> campos,
    Map<String, XFile> archivos,
  ) async {
    try {
      for (final e in archivos.entries) {
        if (await e.value.length() > maxArchivoBytes) {
          return {
            'ok': false,
            'mensaje': 'Un documento supera el máximo de ${maxArchivoBytes ~/ (1024 * 1024)} MB. '
                'Elige una imagen más ligera.'
          };
        }
      }
      final response = await _conAuth((h) async {
        final req = http.MultipartRequest('POST', Uri.parse('$baseUrl$ruta'));
        req.headers['Accept'] = 'application/json';
        if (h['Authorization'] != null) {
          req.headers['Authorization'] = h['Authorization']!;
        }
        req.fields.addAll(campos);
        for (final e in archivos.entries) {
          final ext = await _extensionReal(e.value);
          req.files.add(await http.MultipartFile.fromPath(e.key, e.value.path,
              filename: '${e.key}.$ext'));
        }
        final enviado = await req.send().timeout(const Duration(seconds: 120));
        return http.Response.fromStream(enviado);
      });
      final data = _json(response);
      return {
        'ok': (response.statusCode == 201 || response.statusCode == 200) && data['ok'] == true,
        'mensaje': data['mensaje'] ?? 'No se pudo enviar la solicitud.',
        'folio': data['folio'],
      };
    } catch (e) {
      logDebug('Error enviando trámite: $e');
      return {'ok': false, 'mensaje': 'Error de conexión. Intenta de nuevo.'};
    }
  }

  static Future<Map<String, dynamic>> enviarInscripcion({
    required String nombre,
    required String curp,
    required String fechaNacimiento, // AAAA-MM-DD
    required String telefono,
    required String carrera, // clave: ITID, II, ...
    required String contactoNombre,
    required String contactoTel,
    required XFile fotografia,
    required XFile acta,
    required XFile certificado,
    required XFile comprobante,
  }) {
    return _enviarTramite(
      '/api/inscripcion',
      {
        'nombre': nombre,
        'curp': curp,
        'fecha_nacimiento': fechaNacimiento,
        'telefono': telefono,
        'carrera': carrera,
        'contacto_emergencia_nombre': contactoNombre,
        'contacto_emergencia_tel': contactoTel,
      },
      {
        'fotografia': fotografia,
        'doc_acta': acta,
        'doc_cert': certificado,
        'comprobante': comprobante,
      },
    );
  }

  static Future<Map<String, dynamic>> enviarReinscripcion({
    required String matricula,
    required String nombre,
    required String carreraClave,
    required String cuatrimestre,
    required bool esEstadia,
    required List<String> materias,
    required String referenciaPago,
    required String fechaPago, // AAAA-MM-DD
    required XFile comprobante,
  }) {
    return _enviarTramite(
      '/api/reinscripcion',
      {
        'matricula': matricula,
        'nombre': nombre,
        'carrera_clave': carreraClave,
        'cuatrimestre': cuatrimestre,
        'es_estadia': esEstadia ? '1' : '0',
        'materias': jsonEncode(materias),
        'referencia_pago': referenciaPago,
        'fecha_pago': fechaPago,
      },
      {'comprobante': comprobante},
    );
  }

  // ── ADMIN ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getSolicitudesAdmin() async {
    try {
      final response = await _conAuth((h) => http
          .get(Uri.parse('$baseUrl/api/admin/solicitudes'), headers: h)
          .timeout(const Duration(seconds: 30)));
      if (response.statusCode == 200) return _json(response);
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
      final response = await _conAuth((h) => http
          .post(
            Uri.parse('$baseUrl/api/admin/actualizar_estatus'),
            headers: h,
            body: jsonEncode({
              'folio': folio,
              'tipo': tipo,
              'estatus': estatus,
              if (motivo != null) 'motivo': motivo,
            }),
          )
          .timeout(const Duration(seconds: 30)));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── DASHBOARD (admin) ─────────────────────────────────────
  static Future<Map<String, dynamic>?> getDashboard(
      {String estatus = 'Todas'}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/admin/dashboard')
          .replace(queryParameters: {'estatus': estatus});
      final response = await _conAuth(
          (h) => http.get(uri, headers: h).timeout(const Duration(seconds: 30)));
      if (response.statusCode == 200) return _json(response);
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── REPORTES EXCEL (admin) ────────────────────────────────
  // Pide al servidor un enlace temporal de UN SOLO USO (válido unos minutos)
  // que luego se abre en el navegador del teléfono.
  static Future<Map<String, dynamic>> crearEnlaceReporte({
    required String tipo,
    String estatus = 'Todas',
    String carrera = 'Todas',
    String? desde, // AAAA-MM-DD
    String? hasta, // AAAA-MM-DD
  }) async {
    try {
      final response = await _conAuth((h) => http
          .post(
            Uri.parse('$baseUrl/api/admin/reportes/enlace'),
            headers: h,
            body: jsonEncode({
              'tipo': tipo,
              'estatus': estatus,
              'carrera': carrera,
              'desde': desde ?? '',
              'hasta': hasta ?? '',
            }),
          )
          .timeout(const Duration(seconds: 60)));
      final data = _json(response);
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

      final data = _json(response);
      return {
        'ok': response.statusCode == 200,
        'mensaje': data['mensaje'] ?? '',
      };
    } catch (_) {
      return {'ok': false, 'mensaje': 'Error de conexión. Intenta de nuevo.'};
    }
  }
}
