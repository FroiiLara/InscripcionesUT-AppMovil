import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../services/permisos_service.dart';

class SoporteScreen extends StatelessWidget {
  const SoporteScreen({super.key});

  static const _telefono = '8181248400';
  static const _direccion = 'Universidad Tecnológica de Santa Catarina, Carretera Monterrey-Saltillo Km 61.5, Santa Catarina, Nuevo León';

  void _aviso(BuildContext c, String t) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(t)));

  /// Llamada: se pide el permiso de llamadas (Android) y se abre el marcador.
  Future<void> _llamar(BuildContext context) async {
    await PermisosService.asegurar(context, AppPermiso.llamadas);
    // Aunque el permiso se niegue, el marcador del sistema sigue disponible (alternativa).
    final ok = await launchUrl(Uri(scheme: 'tel', path: _telefono));
    if (!ok && context.mounted) _aviso(context, 'No se pudo abrir el marcador. Llama al (81) 81-24-84-00.');
  }

  Future<void> _sms(BuildContext context) async {
    await PermisosService.asegurar(context, AppPermiso.sms);
    final cuerpo = Uri.encodeComponent('Hola, tengo una duda sobre mi trámite en el Sistema de Inscripciones UTSC.');
    final ok = await launchUrl(Uri.parse('sms:$_telefono?body=$cuerpo'));
    if (!ok && context.mounted) _aviso(context, 'No se pudo abrir la app de mensajes.');
  }

  /// Ruta: con GPS traza desde la posición actual; sin permiso abre solo el destino.
  Future<void> _comoLlegar(BuildContext context) async {
    final destino = Uri.encodeComponent(_direccion);
    String url = 'https://www.google.com/maps/dir/?api=1&destination=$destino';
    final permitido = await PermisosService.asegurar(context, AppPermiso.ubicacion);
    if (permitido) {
      try {
        if (!await Geolocator.isLocationServiceEnabled()) {
          if (context.mounted) _aviso(context, 'Activa el GPS del dispositivo para trazar la ruta desde tu ubicación.');
        } else {
          final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 15));
          url += '&origin=${pos.latitude},${pos.longitude}';
        }
      } catch (_) {
        if (context.mounted) _aviso(context, 'No se pudo obtener tu ubicación. Se muestra solo la universidad.');
      }
    }
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) _aviso(context, 'No se pudo abrir el mapa.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UTSCColors.fondo,
      appBar: AppBar(
        title: const Text('Soporte y Contacto'),
        backgroundColor: UTSCColors.verde,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Información de Contacto',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: UTSCColors.verde)),
            const SizedBox(height: 14),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: UTSCColors.verde, width: 1)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _Contacto(icono: Icons.location_on_outlined,
                        texto: 'Carretera Monterrey-Saltillo Km. 61.5,\nC.P. 66359, Santa Catarina, N.L.'),
                    const Divider(height: 20),
                    _Contacto(icono: Icons.phone_outlined,   texto: '(81) 81-24-84-00'),
                    const Divider(height: 20),
                    _Contacto(icono: Icons.email_outlined,   texto: 'utsc@utsc.edu.mx'),
                    const Divider(height: 20),
                    _Contacto(icono: Icons.language_outlined, texto: 'www.utsc.edu.mx'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: () => _llamar(context),
                icon: const Icon(Icons.call),
                label: const Text('Llamar'),
                style: ElevatedButton.styleFrom(backgroundColor: UTSCColors.verde, foregroundColor: Colors.white),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => _sms(context),
                icon: const Icon(Icons.sms),
                label: const Text('Enviar SMS'),
                style: ElevatedButton.styleFrom(backgroundColor: UTSCColors.verde, foregroundColor: Colors.white),
              )),
            ]),
            const SizedBox(height: 24),
            const Text('Horario de Atención',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: UTSCColors.verde)),
            const SizedBox(height: 14),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _Horario('Lunes a Viernes', '8:00 AM – 6:00 PM'),
                    const Divider(height: 16),
                    _Horario('Sábados', '9:00 AM – 1:00 PM'),
                    const Divider(height: 16),
                    _Horario('Domingos', 'Cerrado'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Ubicación',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: UTSCColors.verde)),
            const SizedBox(height: 14),
            Container(
              width: double.infinity, height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: UTSCColors.borde),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 48, color: UTSCColors.textoGris),
                  SizedBox(height: 8),
                  Text('Mapa — UTSC Santa Catarina, N.L.',
                      style: TextStyle(color: UTSCColors.textoGris)),
                  SizedBox(height: 4),
                  Text('Carretera Monterrey-Saltillo Km. 61.5',
                      style: TextStyle(color: UTSCColors.textoGris, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _comoLlegar(context),
                icon: const Icon(Icons.directions),
                label: const Text('Cómo llegar desde mi ubicación'),
                style: ElevatedButton.styleFrom(backgroundColor: UTSCColors.naranja, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Contacto extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Contacto({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: UTSCColors.naranja, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(texto, style: const TextStyle(fontSize: 14, color: UTSCColors.texto))),
      ],
    );
  }
}

class _Horario extends StatelessWidget {
  final String dia, horario;
  const _Horario(this.dia, this.horario);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(dia, style: const TextStyle(fontWeight: FontWeight.w600, color: UTSCColors.verde, fontSize: 14)),
        Text(horario, style: const TextStyle(color: UTSCColors.texto, fontSize: 14)),
      ],
    );
  }
}
