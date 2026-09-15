import 'package:flutter/material.dart';
import '../constants/colors.dart';

class SoporteScreen extends StatelessWidget {
  const SoporteScreen({super.key});

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
