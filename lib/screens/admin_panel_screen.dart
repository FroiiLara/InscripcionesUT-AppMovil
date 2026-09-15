import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/api_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _cargando = true;
  List<dynamic> _inscripciones   = [];
  List<dynamic> _reinscripciones = [];

  int get _totalInsc       => _inscripciones.length;
  int get _pendInsc        => _inscripciones.where((s) => s['estatus'] == 'En revisión').length;
  int get _totalReinsc     => _reinscripciones.length;
  int get _pendReinsc      => _reinscripciones.where((s) => s['estatus'] == 'En revisión').length;

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
    final data = await ApiService.getSolicitudesAdmin();
    setState(() {
      _cargando = false;
      if (data != null) {
        _inscripciones   = data['inscripciones']   ?? [];
        _reinscripciones = data['reinscripciones'] ?? [];
      }
    });
  }

  Future<void> _cambiarEstatus(dynamic sol, String tipo, String nuevoEstatus) async {
    final folio = sol['folio'] ?? '';
    final ok = await ApiService.actualizarEstatus(folio: folio, tipo: tipo, estatus: nuevoEstatus);
    if (ok) {
      setState(() => sol['estatus'] = nuevoEstatus);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$folio → $nuevoEstatus'),
        backgroundColor: nuevoEstatus == 'Aprobada' ? UTSCColors.aprobada : UTSCColors.rechazada,
      ));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error al actualizar. Intenta de nuevo.'), backgroundColor: UTSCColors.error));
    }
  }

  void _dialogo(dynamic sol, String tipo) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text('Cambiar estatus — ${sol['folio']}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(backgroundColor: UTSCColors.aprobadaFondo,
                  child: Icon(Icons.check, color: UTSCColors.aprobada)),
              title: const Text('Aprobar solicitud'),
              subtitle: const Text('Se notificará al alumno por correo'),
              onTap: () { Navigator.pop(context); _cambiarEstatus(sol, tipo, 'Aprobada'); },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: UTSCColors.rechazadaFondo,
                  child: Icon(Icons.close, color: UTSCColors.rechazada)),
              title: const Text('Rechazar solicitud'),
              subtitle: const Text('Se notificará al alumno por correo'),
              onTap: () { Navigator.pop(context); _cambiarEstatus(sol, tipo, 'Rechazada'); },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: UTSCColors.revisionFondo,
                  child: Icon(Icons.hourglass_empty, color: UTSCColors.revision)),
              title: const Text('Marcar en revisión'),
              onTap: () { Navigator.pop(context); _cambiarEstatus(sol, tipo, 'En revisión'); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de estadísticas
        Container(
          color: UTSCColors.verde,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              _Stat(numero: _totalInsc,   etiqueta: 'Inscripciones',   icono: Icons.school_outlined),
              const SizedBox(width: 8),
              _Stat(numero: _pendInsc,    etiqueta: 'Pendientes',      icono: Icons.hourglass_empty),
              const SizedBox(width: 8),
              _Stat(numero: _totalReinsc, etiqueta: 'Reinscripciones', icono: Icons.refresh),
              const SizedBox(width: 8),
              _Stat(numero: _pendReinsc,  etiqueta: 'Pendientes',      icono: Icons.hourglass_empty),
            ],
          ),
        ),
        // Tabs
        Container(
          color: UTSCColors.verde,
          child: TabBar(
            controller: _tabCtrl,
            indicatorColor: UTSCColors.naranja, indicatorWeight: 3,
            labelColor: Colors.white, unselectedLabelColor: Colors.white60,
            tabs: [Tab(text: 'Inscripciones ($_totalInsc)'), Tab(text: 'Reinscripciones ($_totalReinsc)')],
          ),
        ),
        // Contenido
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator(color: UTSCColors.verde))
              : RefreshIndicator(
                  color: UTSCColors.verde, onRefresh: _cargar,
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _inscripciones.isEmpty
                          ? _Vacio('No hay solicitudes de inscripción.')
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _inscripciones.length,
                              itemBuilder: (_, i) => _Tarjeta(
                                solicitud: _inscripciones[i], tipo: 'inscripcion',
                                onAccion: () => _dialogo(_inscripciones[i], 'inscripcion'))),
                      _reinscripciones.isEmpty
                          ? _Vacio('No hay solicitudes de reinscripción.')
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _reinscripciones.length,
                              itemBuilder: (_, i) => _Tarjeta(
                                solicitud: _reinscripciones[i], tipo: 'reinscripcion',
                                onAccion: () => _dialogo(_reinscripciones[i], 'reinscripcion'))),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final dynamic solicitud;
  final String tipo;
  final VoidCallback onAccion;
  const _Tarjeta({required this.solicitud, required this.tipo, required this.onAccion});

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

  @override
  Widget build(BuildContext context) {
    final folio   = solicitud['folio']           ?? 'Sin folio';
    final nombre  = solicitud['nombre']          ?? solicitud['usuario'] ?? '—';
    final carrera = solicitud['carrera']         ?? '—';
    final fecha   = solicitud['fecha_solicitud'] ?? '';
    final estatus = solicitud['estatus']         ?? 'En revisión';
    final materias= solicitud['materias']        as List? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12), elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _color.withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(folio,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: UTSCColors.verde))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: _fondo, borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _color)),
                  child: Text(estatus, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _color)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [const Icon(Icons.person_outline, size: 15, color: UTSCColors.textoGris),
                const SizedBox(width: 6), Expanded(child: Text(nombre, style: const TextStyle(fontSize: 13)))]),
            const SizedBox(height: 4),
            Row(children: [const Icon(Icons.school_outlined, size: 15, color: UTSCColors.textoGris),
                const SizedBox(width: 6), Expanded(child: Text(carrera, style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis))]),
            if (tipo == 'reinscripcion' && materias.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 4, runSpacing: 4,
                  children: materias.map((m) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: UTSCColors.verde, borderRadius: BorderRadius.circular(20)),
                    child: Text(m.toString(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                  )).toList()),
            ],
            if (fecha.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [const Icon(Icons.calendar_today_outlined, size: 13, color: UTSCColors.textoGris),
                  const SizedBox(width: 6), Text(fecha, style: const TextStyle(fontSize: 12, color: UTSCColors.textoGris))]),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAccion,
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Cambiar estatus'),
              style: OutlinedButton.styleFrom(
                foregroundColor: UTSCColors.verde, side: const BorderSide(color: UTSCColors.verde),
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final int numero;
  final String etiqueta;
  final IconData icono;
  const _Stat({required this.numero, required this.etiqueta, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Icon(icono, color: Colors.white, size: 18),
          const SizedBox(height: 2),
          Text('$numero', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(etiqueta, style: const TextStyle(color: Colors.white70, fontSize: 9), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  final String msg;
  const _Vacio(this.msg);
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text(msg, style: const TextStyle(color: UTSCColors.textoGris, fontSize: 15)),
    ]));
  }
}
