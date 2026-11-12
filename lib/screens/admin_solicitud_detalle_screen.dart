import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';

/// Detalle completo de una inscripción o reinscripción para el administrador,
/// con los botones de aprobar / rechazar. El cambio de estatus lo hace el panel
/// (callback [onCambiar]) para reutilizar el diálogo del motivo y la llamada a la API.
class AdminSolicitudDetalleScreen extends StatefulWidget {
  final dynamic solicitud;
  final String tipo; // 'inscripcion' | 'reinscripcion'
  final Future<bool> Function(String estatus) onCambiar;
  const AdminSolicitudDetalleScreen({
    super.key,
    required this.solicitud,
    required this.tipo,
    required this.onCambiar,
  });

  @override
  State<AdminSolicitudDetalleScreen> createState() => _AdminSolicitudDetalleScreenState();
}

class _AdminSolicitudDetalleScreenState extends State<AdminSolicitudDetalleScreen> {
  bool _procesando = false;

  dynamic get _s => widget.solicitud;
  bool get _esInsc => widget.tipo == 'inscripcion';
  String get _estatus => (_s['estatus'] ?? 'En revisión').toString();

  Color get _color {
    if (_estatus == 'Aprobada') return UTSCColors.aprobada;
    if (_estatus == 'Rechazada') return UTSCColors.rechazada;
    return UTSCColors.revision;
  }

  Color get _fondo {
    if (_estatus == 'Aprobada') return UTSCColors.aprobadaFondo;
    if (_estatus == 'Rechazada') return UTSCColors.rechazadaFondo;
    return UTSCColors.revisionFondo;
  }

  String _v(String clave) {
    final x = _s[clave];
    if (x == null) return '—';
    final t = x.toString().trim();
    return t.isEmpty ? '—' : t;
  }

  Future<void> _cambiar(String estatus) async {
    if (estatus == 'Aprobada') {
      final seguro = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Aprobar solicitud'),
          content: Text('¿Aprobar ${_v('folio')}? Se notificará al alumno por correo.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: UTSCColors.aprobada, minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aprobar'),
            ),
          ],
        ),
      );
      if (seguro != true) return;
    }
    setState(() => _procesando = true);
    await widget.onCambiar(estatus);
    if (!mounted) return;
    setState(() => _procesando = false);
  }

  Future<void> _abrir(String url) async {
    var abierto = false;
    try {
      abierto = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      abierto = false;
    }
    if (!abierto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el documento.')));
    }
  }

  void _verImagen(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(
                      height: 200,
                      child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white)))),
            ),
            Positioned(
              top: 4, right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- piezas de interfaz ----------

  Widget _seccion(String titulo, IconData icono, List<Widget> hijos) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UTSCColors.borde.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icono, size: 18, color: UTSCColors.naranja),
            const SizedBox(width: 8),
            Text(titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15, color: UTSCColors.naranja)),
          ]),
          const Divider(height: 18),
          ...hijos,
        ],
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 118,
              child: Text(etiqueta,
                  style: const TextStyle(fontSize: 12.5, color: UTSCColors.textoGris))),
          Expanded(
              child: SelectableText(valor,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _doc(String titulo, dynamic url, {bool imagen = false}) {
    final enlace = (url ?? '').toString().trim();
    final tiene = enlace.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: UTSCColors.fondo, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          if (tiene && imagen)
            GestureDetector(
              onTap: () => _verImagen(enlace),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: Image.network(enlace,
                    height: 190, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                        height: 80,
                        child: Center(child: Icon(Icons.broken_image_outlined)))),
              ),
            ),
          ListTile(
            dense: true,
            leading: Icon(
                imagen ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
                color: tiene ? UTSCColors.naranja : UTSCColors.textoGris),
            title: Text(titulo,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(tiene ? 'Toca para abrir' : 'No adjuntado',
                style: const TextStyle(fontSize: 12)),
            trailing: tiene ? const Icon(Icons.open_in_new, size: 18) : null,
            onTap: tiene ? () => _abrir(enlace) : null,
          ),
        ],
      ),
    );
  }

  Widget _encabezado() {
    final motivo = (_s['motivo_rechazo'] ?? '').toString();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(_v('folio'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17, color: UTSCColors.texto))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _color)),
                child: Text(_estatus,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _color)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Solicitud: ${_v('fecha_solicitud')}',
              style: const TextStyle(fontSize: 12.5, color: UTSCColors.textoGris)),
          if (_estatus == 'Rechazada') ...[
            const SizedBox(height: 10),
            Text(motivo.isNotEmpty ? 'Motivo: $motivo' : 'Sin motivo registrado',
                style: TextStyle(
                    fontSize: 13,
                    color: UTSCColors.rechazada,
                    fontStyle: motivo.isNotEmpty ? FontStyle.normal : FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  List<Widget> _contenido() {
    if (_esInsc) {
      return [
        _seccion('Datos personales', Icons.person_outline, [
          _fila('Nombre', _v('nombre')),
          _fila('CURP', _v('curp')),
          _fila('Nacimiento', _v('fecha_nacimiento')),
          _fila('Teléfono', _v('telefono')),
          _fila('Matrícula', _v('usuario')),
        ]),
        _seccion('Académicos y contacto', Icons.school_outlined, [
          _fila('Carrera', _v('carrera')),
          _fila('Contacto de emergencia', _v('contacto_emergencia_nombre')),
          _fila('Tel. del contacto', _v('contacto_emergencia_tel')),
        ]),
        _seccion('Documentos', Icons.folder_open_outlined, [
          _doc('Fotografía', _s['fotografia'], imagen: true),
          _doc('Acta de nacimiento', _s['doc_acta']),
          _doc('Certificado de bachillerato', _s['doc_cert']),
          _doc('Comprobante de pago', _s['comprobante']),
        ]),
      ];
    }
    final materias = (_s['materias'] as List?) ?? const [];
    final estadia = _s['es_estadia'] == true;
    final cuatri = _v('cuatrimestre');
    return [
      _seccion('Datos del alumno', Icons.person_outline, [
        _fila('Nombre', _v('nombre')),
        _fila('Matrícula', _v('matricula')),
        _fila('Correo', _v('correo')),
        _fila('Teléfono', _v('telefono')),
      ]),
      _seccion('Carrera y materias', Icons.school_outlined, [
        _fila('Carrera', _v('carrera')),
        _fila('Cuatrimestre', cuatri == '—' ? cuatri : '$cuatri°'),
        if (estadia)
          _fila('Modalidad', 'Estadía')
        else
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: materias
                  .map((m) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: UTSCColors.naranja,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(m.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ))
                  .toList(),
            ),
          ),
      ]),
      _seccion('Pago', Icons.receipt_long_outlined, [
        _fila('Referencia', _v('referencia_pago')),
        _fila('Fecha de pago', _v('fecha_pago')),
        const SizedBox(height: 6),
        _doc('Comprobante de pago', _s['comprobante']),
      ]),
    ];
  }

  Widget _seguimiento() {
    final hayRevision = _v('fecha_revision') != '—';
    if (!hayRevision) return const SizedBox.shrink();
    return _seccion('Seguimiento', Icons.fact_check_outlined, [
      _fila('Última revisión', _v('fecha_revision')),
      _fila('Revisado por', _v('revisado_por')),
    ]);
  }

  Widget _barraAcciones() {
    final enRevision = _estatus == 'En revisión';
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: enRevision
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _procesando ? null : () => _cambiar('Rechazada'),
                        icon: const Icon(Icons.close),
                        label: const Text('Rechazar', maxLines: 1, softWrap: false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: UTSCColors.rechazada,
                          side: const BorderSide(color: UTSCColors.rechazada),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _procesando ? null : () => _cambiar('Aprobada'),
                        icon: const Icon(Icons.check),
                        label: const Text('Aprobar', maxLines: 1, softWrap: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UTSCColors.aprobada,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                )
              : OutlinedButton.icon(
                  onPressed: _procesando ? null : () => _cambiar('En revisión'),
                  icon: const Icon(Icons.hourglass_empty),
                  label: const Text('Regresar a "En revisión"'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: UTSCColors.revision,
                    side: const BorderSide(color: UTSCColors.revision),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UTSCColors.fondo,
      appBar: AppBar(
        title: Text(_esInsc ? 'Inscripción' : 'Reinscripción'),
        backgroundColor: UTSCColors.verde,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _encabezado(),
          ..._contenido(),
          _seguimiento(),
        ],
      ),
      bottomNavigationBar: _barraAcciones(),
    );
  }
}
