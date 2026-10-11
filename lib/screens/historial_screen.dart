import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/api_service.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});
  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _cargando = true;
  List<dynamic> _inscripciones   = [];
  List<dynamic> _reinscripciones = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final data = await ApiService.getHistorial();
    setState(() {
      _cargando = false;
      if (data != null) {
        _inscripciones   = data['inscripciones']   ?? [];
        _reinscripciones = data['reinscripciones'] ?? [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: UTSCColors.verde,
          child: TabBar(
            controller: _tabCtrl,
            indicatorColor: UTSCColors.naranja,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: 'Inscripciones (${_inscripciones.length})'),
              Tab(text: 'Reinscripciones (${_reinscripciones.length})'),
            ],
          ),
        ),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator(color: UTSCColors.verde))
              : RefreshIndicator(
                  color: UTSCColors.verde,
                  onRefresh: _cargar,
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _Lista(solicitudes: _inscripciones, tipo: 'inscripcion',
                          vacio: 'No tienes inscripciones registradas.'),
                      _Lista(solicitudes: _reinscripciones, tipo: 'reinscripcion',
                          vacio: 'No tienes reinscripciones registradas.'),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _Lista extends StatelessWidget {
  final List<dynamic> solicitudes;
  final String tipo, vacio;
  const _Lista({required this.solicitudes, required this.tipo, required this.vacio});

  @override
  Widget build(BuildContext context) {
    if (solicitudes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(vacio, style: const TextStyle(color: UTSCColors.textoGris, fontSize: 15)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: solicitudes.length,
      itemBuilder: (_, i) => _Tarjeta(solicitud: solicitudes[i], tipo: tipo),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final dynamic solicitud;
  final String tipo;
  const _Tarjeta({required this.solicitud, required this.tipo});

  Color get _color {
    final e = solicitud['estatus'] ?? '';
    if (e == 'Aprobada')  return UTSCColors.aprobada;
    if (e == 'Rechazada') return UTSCColors.rechazada;
    return UTSCColors.revision;
  }

  Color get _fondo {
    final e = solicitud['estatus'] ?? '';
    if (e == 'Aprobada')  return UTSCColors.aprobadaFondo;
    if (e == 'Rechazada') return UTSCColors.rechazadaFondo;
    return UTSCColors.revisionFondo;
  }

  IconData get _icono {
    final e = solicitud['estatus'] ?? '';
    if (e == 'Aprobada')  return Icons.check_circle_outline;
    if (e == 'Rechazada') return Icons.cancel_outlined;
    return Icons.hourglass_empty_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final folio   = solicitud['folio']           ?? 'Sin folio';
    final fecha   = solicitud['fecha_solicitud'] ?? '';
    final estatus = solicitud['estatus']         ?? 'En revisión';
    final carrera = solicitud['carrera']         ?? '';
    final materias= solicitud['materias']        as List? ?? [];
    final motivo  = (solicitud['motivo_rechazo'] ?? '').toString();
    final rechazada = estatus == 'Rechazada';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(folio, style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15, color: UTSCColors.verde)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _fondo,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _color),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_icono, size: 14, color: _color),
                      const SizedBox(width: 4),
                      Text(estatus, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _color)),
                    ],
                  ),
                ),
              ],
            ),
            if (carrera.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.school_outlined, size: 14, color: UTSCColors.textoGris),
                const SizedBox(width: 6),
                Expanded(child: Text(carrera, style: const TextStyle(fontSize: 13))),
              ]),
            ],
            if (tipo == 'reinscripcion' && materias.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4, runSpacing: 4,
                children: materias.map((m) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: UTSCColors.verde, borderRadius: BorderRadius.circular(20)),
                  child: Text(m.toString(), style: const TextStyle(color: Colors.white, fontSize: 11)),
                )).toList(),
              ),
            ],
            if (rechazada) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: UTSCColors.rechazadaFondo,
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(left: BorderSide(color: UTSCColors.rechazada, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Motivo del rechazo',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: UTSCColors.rechazada)),
                    const SizedBox(height: 2),
                    Text(
                      motivo.isNotEmpty
                          ? motivo
                          : 'No se registró un motivo. Comunícate con Control Escolar.',
                      style: TextStyle(
                          fontSize: 13,
                          fontStyle: motivo.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                          color: UTSCColors.texto),
                    ),
                  ],
                ),
              ),
            ],
            if (fecha.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 13, color: UTSCColors.textoGris),
                const SizedBox(width: 6),
                Text(fecha, style: const TextStyle(fontSize: 12, color: UTSCColors.textoGris)),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
