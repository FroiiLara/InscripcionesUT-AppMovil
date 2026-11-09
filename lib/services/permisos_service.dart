import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/colors.dart';

/// Permisos que la app puede usar y para qué (política de permisos Android / iOS).
///
/// Reglas que se cumplen:
///  1. Se pide el permiso solo cuando el usuario toca la función que lo necesita.
///  2. Antes del aviso del sistema se muestra una explicación propia (para qué se usa).
///  3. Si el usuario lo niega, la app sigue funcionando y ofrece alternativas.
///  4. Si lo bloquea de forma permanente, se ofrece abrir los Ajustes del sistema.
///  5. SMS y llamadas son permisos solo de Android; en iOS el sistema pide confirmación
///     al abrir el marcador o Mensajes, por lo que no se solicitan.
enum AppPermiso { camara, microfono, ubicacion, almacenamiento, contactos, sms, llamadas }

enum EstadoPermiso { concedido, denegado, bloqueado, noRequerido }

class InfoPermiso {
  final String titulo;
  final IconData icono;
  final String paraQue; // texto de justificación mostrado al usuario
  final String sinPermiso; // qué pasa si lo niega
  const InfoPermiso(this.titulo, this.icono, this.paraQue, this.sinPermiso);
}

class PermisosService {
  static const Map<AppPermiso, InfoPermiso> info = {
    AppPermiso.camara: InfoPermiso('Cámara', Icons.photo_camera_outlined,
        'Para tomar la fotografía y fotografiar tus documentos (acta, certificado y comprobante de pago) durante la inscripción.',
        'Podrás seleccionar las imágenes desde tu galería.'),
    AppPermiso.microfono: InfoPermiso('Micrófono', Icons.mic_none_outlined,
        'Para dictar por voz el mensaje de tus consultas a Control Escolar. El audio se convierte en texto y no se guarda.',
        'Podrás escribir tu consulta con el teclado.'),
    AppPermiso.ubicacion: InfoPermiso('Ubicación (GPS)', Icons.location_on_outlined,
        'Para trazar la ruta desde donde te encuentras hasta la UTSC. Tu ubicación solo se usa en ese momento y no se almacena.',
        'Podrás ver el mapa de la universidad sin ruta desde tu posición.'),
    AppPermiso.almacenamiento: InfoPermiso('Almacenamiento / Fotos', Icons.folder_open_outlined,
        'Para elegir de tu galería los documentos digitalizados que se adjuntan al trámite.',
        'Podrás tomar los documentos con la cámara.'),
    AppPermiso.contactos: InfoPermiso('Contactos', Icons.contacts_outlined,
        'Para elegir de tu agenda a tu contacto de emergencia y llenar su nombre y teléfono sin escribirlos. No se copia ni se sube tu agenda.',
        'Podrás capturar nombre y teléfono manualmente.'),
    AppPermiso.sms: InfoPermiso('SMS (solo Android)', Icons.sms_outlined,
        'Para enviar un mensaje de texto a Control Escolar desde la pantalla de Soporte.',
        'Podrás usar consultas dentro de la app o el correo electrónico.'),
    AppPermiso.llamadas: InfoPermiso('Llamadas (solo Android)', Icons.call_outlined,
        'Para llamar por teléfono a Control Escolar con un toque desde la pantalla de Soporte.',
        'Podrás marcar el número manualmente.'),
  };

  static Permission _permiso(AppPermiso p) {
    switch (p) {
      case AppPermiso.camara:
        return Permission.camera;
      case AppPermiso.microfono:
        return Permission.microphone;
      case AppPermiso.ubicacion:
        return Permission.locationWhenInUse;
      case AppPermiso.almacenamiento:
        return Permission.photos; // Android 13+: READ_MEDIA_IMAGES; antes: READ_EXTERNAL_STORAGE
      case AppPermiso.contactos:
        return Permission.contacts;
      case AppPermiso.sms:
        return Permission.sms;
      case AppPermiso.llamadas:
        return Permission.phone;
    }
  }

  /// SMS y llamadas no existen como permiso de la app en iOS.
  static bool aplica(AppPermiso p) {
    if (Platform.isIOS && (p == AppPermiso.sms || p == AppPermiso.llamadas)) return false;
    return true;
  }

  static EstadoPermiso _traducir(PermissionStatus s) {
    if (s.isGranted || s.isLimited || s.isProvisional) return EstadoPermiso.concedido;
    if (s.isPermanentlyDenied || s.isRestricted) return EstadoPermiso.bloqueado;
    return EstadoPermiso.denegado;
  }

  static Future<EstadoPermiso> estado(AppPermiso p) async {
    if (!aplica(p)) return EstadoPermiso.noRequerido;
    return _traducir(await _permiso(p).status);
  }

  /// Solicita el permiso mostrando primero la justificación. Devuelve true si se puede usar la función.
  static Future<bool> asegurar(BuildContext context, AppPermiso p) async {
    if (!aplica(p)) return true;
    final actual = await estado(p);
    if (actual == EstadoPermiso.concedido) return true;
    if (!context.mounted) return false;

    if (actual == EstadoPermiso.bloqueado) {
      await _dialogoAjustes(context, p);
      return false;
    }

    final continuar = await _dialogoJustificacion(context, p);
    if (continuar != true) return false;

    final resultado = _traducir(await _permiso(p).request());
    if (resultado == EstadoPermiso.concedido) return true;
    if (!context.mounted) return false;

    if (resultado == EstadoPermiso.bloqueado) {
      await _dialogoAjustes(context, p);
    } else {
      _aviso(context, 'Permiso denegado. ${info[p]!.sinPermiso}');
    }
    return false;
  }

  static void _aviso(BuildContext context, String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  static Future<bool?> _dialogoJustificacion(BuildContext context, AppPermiso p) {
    final i = info[p]!;
    final nombre = i.titulo.split(' (').first.toLowerCase();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(i.icono, color: UTSCColors.verde, size: 36),
        title: Text('Permiso de $nombre'),
        content: Text('${i.paraQue}\n\nSi no lo permites: ${i.sinPermiso}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ahora no')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: UTSCColors.naranja, foregroundColor: Colors.white),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  static Future<void> _dialogoAjustes(BuildContext context, AppPermiso p) async {
    final i = info[p]!;
    final nombre = i.titulo.split(' (').first;
    final abrir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$nombre desactivado'),
        content: Text('El permiso está desactivado en tu dispositivo. Para usar esta función actívalo en Ajustes → Permisos de la app.\n\nMientras tanto: ${i.sinPermiso}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: UTSCColors.naranja, foregroundColor: Colors.white),
            child: const Text('Abrir Ajustes'),
          ),
        ],
      ),
    );
    if (abrir == true) await openAppSettings();
  }

  /// Abre Ajustes del sistema (usado por la pantalla de permisos).
  static Future<void> abrirAjustes() => openAppSettings();
}
