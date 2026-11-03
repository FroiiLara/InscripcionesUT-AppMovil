import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Insignia de estatus de una consulta.
class EstatusChip extends StatelessWidget {
  final String estatus;
  const EstatusChip(this.estatus, {super.key});

  @override
  Widget build(BuildContext context) {
    Color fg, bg;
    switch (estatus) {
      case 'Respondida':
        fg = UTSCColors.aprobada;
        bg = UTSCColors.aprobadaFondo;
        break;
      case 'Cerrada':
        fg = UTSCColors.textoGris;
        bg = const Color(0xFFEEEEEE);
        break;
      default:
        fg = UTSCColors.revision;
        bg = UTSCColors.revisionFondo;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: fg)),
      child: Text(estatus, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

/// Mensaje de error o vacío con botón de reintento.
class EstadoVacio extends StatelessWidget {
  final String texto;
  final VoidCallback? onReintentar;
  const EstadoVacio(this.texto, {super.key, this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: UTSCColors.textoGris)),
          if (onReintentar != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ]),
      ),
    );
  }
}
