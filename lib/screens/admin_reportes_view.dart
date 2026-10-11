import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../services/api_service.dart';

/// Reportes del administrador: elige tipo y filtros; el servidor genera un
/// enlace temporal y el archivo Excel (.xlsx) se descarga desde el navegador.
class AdminReportesView extends StatefulWidget {
  const AdminReportesView({super.key});
  @override
  State<AdminReportesView> createState() => _AdminReportesViewState();
}

class _AdminReportesViewState extends State<AdminReportesView>
    with AutomaticKeepAliveClientMixin {
  static const _tipos = [
    ('general', 'Reporte general', 'Libro completo: resumen, por carrera, inscripciones, reinscripciones y rechazadas.'),
    ('inscripciones', 'Detalle de inscripciones', 'Una fila por inscripción con edad, estatus y motivo de rechazo.'),
    ('reinscripciones', 'Detalle de reinscripciones', 'Cuatrimestre, materias, pago, estatus y motivo de rechazo.'),
    ('por_carrera', 'Resumen por carrera', 'Conteos por carrera y estatus, con gráfica.'),
    ('rechazadas', 'Solicitudes rechazadas', 'Rechazadas con el motivo capturado por el administrador.'),
  ];
  static const _estatus = ['Todas', 'En revisión', 'Aprobada', 'Rechazada'];
  static const _carreras = [
    ('Todas', 'Todas las carreras'),
    ('ITID', 'Ing. en Tecnologías de la Información e Innovación Digital'),
    ('II', 'Ingeniería Industrial'),
    ('IMI', 'Ing. en Mantenimiento Industrial'),
    ('IMT', 'Ingeniería Mecatrónica'),
    ('IE', 'Ingeniería en Electromovilidad'),
    ('LNM', 'Lic. en Negocios y Mercadotecnia'),
    ('LLI', 'Lic. en Educación (Enseñanza del Idioma Inglés)'),
  ];

  String _tipo = 'general';
  String _est = 'Todas';
  String _carrera = 'Todas';
  DateTime? _desde, _hasta;
  bool _generando = false;

  @override
  bool get wantKeepAlive => true;

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _fmt(DateTime? d) => d == null
      ? 'Sin límite'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _aviso(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? UTSCColors.error : UTSCColors.aprobada,
    ));
  }

  Future<void> _elegirFecha(bool esDesde) async {
    final ahora = DateTime.now();
    final p = await showDatePicker(
      context: context,
      initialDate: (esDesde ? _desde : _hasta) ?? ahora,
      firstDate: DateTime(2024),
      lastDate: DateTime(ahora.year + 1),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: UTSCColors.verde)),
        child: child!,
      ),
    );
    if (p != null) setState(() => esDesde ? _desde = p : _hasta = p);
  }

  void _elegirCarrera() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: _carreras.map((c) => ListTile(
            title: Text(c.$2, style: const TextStyle(fontSize: 14)),
            trailing: _carrera == c.$1 ? const Icon(Icons.check, color: UTSCColors.verde) : null,
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _carrera = c.$1);
            },
          )).toList(),
        ),
      ),
    );
  }

  Future<void> _descargar() async {
    if (_desde != null && _hasta != null && _desde!.isAfter(_hasta!)) {
      _aviso("La fecha 'desde' no puede ser posterior a 'hasta'.", error: true);
      return;
    }
    setState(() => _generando = true);
    final r = await ApiService.crearEnlaceReporte(
      tipo: _tipo, estatus: _est, carrera: _carrera,
      desde: _desde == null ? null : _iso(_desde!),
      hasta: _hasta == null ? null : _iso(_hasta!),
    );
    if (!mounted) return;
    setState(() => _generando = false);

    if (r['ok'] != true) {
      _aviso('${r['mensaje'] ?? 'No se pudo generar el reporte.'}', error: true);
      return;
    }
    final insc = (r['inscripciones'] as num?)?.toInt() ?? 0;
    final reinsc = (r['reinscripciones'] as num?)?.toInt() ?? 0;
    if (insc + reinsc == 0) {
      _aviso('No hay registros con esos filtros.', error: true);
      return;
    }
    try {
      final abierto = await launchUrl(Uri.parse('${r['url']}'), mode: LaunchMode.externalApplication);
      if (abierto) {
        _aviso('Descargando Excel: $insc inscripciones y $reinsc reinscripciones.');
      } else {
        _aviso('No se pudo abrir el navegador para descargar el archivo.', error: true);
      }
    } catch (_) {
      _aviso('No se pudo abrir el navegador para descargar el archivo.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final nombreCarrera = _carreras.firstWhere((c) => c.$1 == _carrera).$2;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Tipo de reporte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        ..._tipos.map((t) {
          final sel = _tipo == t.$1;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: sel ? UTSCColors.naranjaClaro : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: sel ? UTSCColors.verde : UTSCColors.borde, width: sel ? 2 : 1),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _tipo = t.$1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: sel ? UTSCColors.verde : UTSCColors.textoGris),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.$2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(t.$3, style: const TextStyle(fontSize: 12, color: UTSCColors.textoGris)),
                    ]),
                  ),
                ]),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        const Text('Filtros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        const Text('Estatus', style: TextStyle(fontSize: 12, color: UTSCColors.textoGris)),
        Wrap(
          spacing: 8,
          children: _estatus.map((e) => ChoiceChip(
            label: Text(e, style: const TextStyle(fontSize: 12)),
            selected: _est == e,
            selectedColor: UTSCColors.naranjaClaro,
            onSelected: (_) => setState(() => _est = e),
          )).toList(),
        ),
        const SizedBox(height: 12),
        const Text('Carrera', style: TextStyle(fontSize: 12, color: UTSCColors.textoGris)),
        const SizedBox(height: 4),
        _Campo(icono: Icons.school_outlined, texto: nombreCarrera, onTap: _elegirCarrera),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Solicitudes desde', style: TextStyle(fontSize: 12, color: UTSCColors.textoGris)),
              const SizedBox(height: 4),
              _Campo(
                icono: Icons.calendar_today_outlined, texto: _fmt(_desde),
                onTap: () => _elegirFecha(true),
                onLimpiar: _desde == null ? null : () => setState(() => _desde = null),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Solicitudes hasta', style: TextStyle(fontSize: 12, color: UTSCColors.textoGris)),
              const SizedBox(height: 4),
              _Campo(
                icono: Icons.calendar_today_outlined, texto: _fmt(_hasta),
                onTap: () => _elegirFecha(false),
                onLimpiar: _hasta == null ? null : () => setState(() => _hasta = null),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _generando ? null : _descargar,
          icon: _generando
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.file_download_outlined),
          label: Text(_generando ? 'Generando...' : 'Descargar Excel'),
        ),
        const SizedBox(height: 8),
        const Text(
          'El archivo se abre en tu navegador para descargarlo. El enlace es temporal (10 minutos).',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: UTSCColors.textoGris),
        ),
      ],
    );
  }
}

class _Campo extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback onTap;
  final VoidCallback? onLimpiar;
  const _Campo({required this.icono, required this.texto, required this.onTap, this.onLimpiar});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: UTSCColors.borde),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icono, color: UTSCColors.verde, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
          if (onLimpiar != null)
            GestureDetector(
              onTap: onLimpiar,
              child: const Icon(Icons.close, size: 18, color: UTSCColors.textoGris),
            ),
        ]),
      ),
    );
  }
}
