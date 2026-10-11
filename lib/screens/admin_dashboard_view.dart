import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/api_service.dart';

/// Dashboard del administrador: indicadores y gráficas dibujadas con widgets
/// propios (sin dependencias externas). Los datos vienen de /api/admin/dashboard.
class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});
  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView>
    with AutomaticKeepAliveClientMixin {
  static const _filtros = ['Todas', 'En revisión', 'Aprobada', 'Rechazada'];
  static const _cInsc = Color(0xFF1A5F5C);
  static const _cReinsc = UTSCColors.naranja;

  bool _cargando = true;
  String _estatus = 'Todas';
  Map<String, dynamic>? _d;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final data = await ApiService.getDashboard(estatus: _estatus);
    if (!mounted) return;
    setState(() {
      _d = data;
      _cargando = false;
    });
  }

  int _n(dynamic v) => (v is num) ? v.toInt() : 0;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_cargando && _d == null) {
      return const Center(child: CircularProgressIndicator(color: UTSCColors.verde));
    }
    final d = _d;
    if (d == null) {
      return RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
          SizedBox(height: 120),
          Icon(Icons.cloud_off, size: 56, color: Colors.grey),
          SizedBox(height: 10),
          Center(child: Text('No se pudo cargar el dashboard.\nDesliza hacia abajo para reintentar.',
              textAlign: TextAlign.center, style: TextStyle(color: UTSCColors.textoGris))),
        ]),
      );
    }

    final tot = (d['totales'] as Map).cast<String, dynamic>();
    final estTot = ((d['estatus'] as Map)['total'] as Map).cast<String, dynamic>();
    final tasa = d['tasa_aprobacion'];
    final carreras = (d['por_carrera'] as List).cast<Map<String, dynamic>>();
    final cuatris = (d['por_cuatrimestre'] as List).cast<Map<String, dynamic>>();
    final meses = (d['por_mes'] as List).cast<Map<String, dynamic>>();
    final edades = (d['edades'] as List).cast<Map<String, dynamic>>();

    return RefreshIndicator(
      color: UTSCColors.verde,
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Filtro de estatus
          const Text('Mostrar solicitudes', style: TextStyle(fontSize: 12, color: UTSCColors.textoGris)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: _filtros.map((f) => ChoiceChip(
              label: Text(f == 'Todas' ? 'Todas' : f, style: const TextStyle(fontSize: 12)),
              selected: _estatus == f,
              selectedColor: UTSCColors.naranjaClaro,
              onSelected: (_) {
                if (_estatus == f) return;
                setState(() => _estatus = f);
                _cargar();
              },
            )).toList(),
          ),
          const SizedBox(height: 14),

          // Indicadores
          Wrap(
            spacing: 10, runSpacing: 10,
            children: [
              _Kpi('${_n(tot['alumnos'])}', 'Alumnos distintos', Icons.groups_outlined),
              _Kpi('${_n(tot['inscripciones'])}', 'Inscripciones', Icons.school_outlined),
              _Kpi('${_n(tot['reinscripciones'])}', 'Reinscripciones', Icons.refresh),
              _Kpi('${_n(estTot['En revisión'])}', 'Pendientes', Icons.hourglass_empty),
              _Kpi(tasa == null ? 'N/D' : '$tasa%', 'Tasa de aprobación', Icons.verified_outlined),
            ],
          ),
          if (d['carrera_top'] != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: UTSCColors.naranjaClaro, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.emoji_events_outlined, color: UTSCColors.naranja),
                const SizedBox(width: 10),
                Expanded(child: Text('Carrera con más solicitudes: ${d['carrera_top']}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              ]),
            ),
          ],
          const SizedBox(height: 16),

          // Por carrera
          _Seccion(
            titulo: 'Solicitudes por carrera',
            leyenda: const [('Inscripciones', _cInsc), ('Reinscripciones', _cReinsc)],
            hijo: _BarrasCarrera(carreras: carreras, cInsc: _cInsc, cReinsc: _cReinsc),
          ),

          // Estatus
          _Seccion(
            titulo: 'Solicitudes por estatus',
            hijo: _DonaEstatus(
              valores: [_n(estTot['En revisión']), _n(estTot['Aprobada']), _n(estTot['Rechazada'])],
              colores: const [UTSCColors.revision, UTSCColors.aprobada, UTSCColors.rechazada],
              etiquetas: const ['En revisión', 'Aprobada', 'Rechazada'],
            ),
          ),

          // Cuatrimestre
          _Seccion(
            titulo: 'Reinscripciones por cuatrimestre',
            hijo: _Columnas(
              etiquetas: cuatris.map((c) => '${c['cuatrimestre']}°').toList(),
              series: [cuatris.map((c) => _n(c['total'])).toList()],
              colores: const [_cReinsc],
            ),
          ),

          // Por mes
          _Seccion(
            titulo: 'Solicitudes por mes (12 meses)',
            leyenda: const [('Inscripciones', _cInsc), ('Reinscripciones', _cReinsc)],
            hijo: _Columnas(
              etiquetas: meses.map((m) {
                final s = '${m['mes']}'; // AAAA-MM
                return '${s.substring(5)}/${s.substring(2, 4)}';
              }).toList(),
              series: [
                meses.map((m) => _n(m['inscripciones'])).toList(),
                meses.map((m) => _n(m['reinscripciones'])).toList(),
              ],
              colores: const [_cInsc, _cReinsc],
              etiquetaChica: true,
            ),
          ),

          // Edades
          _Seccion(
            titulo: 'Edad de los aspirantes',
            hijo: _Columnas(
              etiquetas: edades.map((e) => '${e['rango']}').toList(),
              series: [edades.map((e) => _n(e['total'])).toList()],
              colores: const [_cInsc],
            ),
          ),
          Center(
            child: Text('Actualizado: ${d['generado']} UTC',
                style: const TextStyle(fontSize: 11, color: UTSCColors.textoGris)),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Widgets de apoyo ─────────────────────────

class _Kpi extends StatelessWidget {
  final String valor, etiqueta;
  final IconData icono;
  const _Kpi(this.valor, this.etiqueta, this.icono);

  @override
  Widget build(BuildContext context) {
    final ancho = (MediaQuery.of(context).size.width - 32 - 10) / 2;
    return Container(
      width: ancho,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UTSCColors.borde.withOpacity(0.6)),
      ),
      child: Row(children: [
        Icon(icono, color: UTSCColors.verde, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: UTSCColors.texto)),
            Text(etiqueta, style: const TextStyle(fontSize: 11, color: UTSCColors.textoGris)),
          ]),
        ),
      ]),
    );
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final Widget hijo;
  final List<(String, Color)> leyenda;
  const _Seccion({required this.titulo, required this.hijo, this.leyenda = const []});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: UTSCColors.texto)),
          if (leyenda.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 14, children: leyenda.map((l) => Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: l.$2, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(l.$1, style: const TextStyle(fontSize: 11, color: UTSCColors.textoGris)),
            ])).toList()),
          ],
          const SizedBox(height: 12),
          hijo,
        ]),
      ),
    );
  }
}

/// Barras horizontales apiladas (inscripciones + reinscripciones) por carrera.
class _BarrasCarrera extends StatelessWidget {
  final List<Map<String, dynamic>> carreras;
  final Color cInsc, cReinsc;
  const _BarrasCarrera({required this.carreras, required this.cInsc, required this.cReinsc});

  int _n(dynamic v) => (v is num) ? v.toInt() : 0;

  @override
  Widget build(BuildContext context) {
    final maximo = carreras.fold<int>(0, (m, c) => math.max(m, _n(c['total'])));
    if (maximo == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('Sin datos', style: TextStyle(color: UTSCColors.textoGris))),
      );
    }
    return Column(
      children: carreras.map((c) {
        final insc = _n(c['inscripciones']);
        final reinsc = _n(c['reinscripciones']);
        final total = _n(c['total']);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${c['nombre']}', style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Expanded(
                child: LayoutBuilder(builder: (_, box) {
                  final ancho = box.maxWidth * total / maximo;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: ancho, height: 16,
                        child: total == 0
                            ? null
                            : Row(children: [
                                if (insc > 0) Expanded(flex: insc, child: Container(color: cInsc)),
                                if (reinsc > 0) Expanded(flex: reinsc, child: Container(color: cReinsc)),
                              ]),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 34,
                child: Text('$total', textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ]),
            Text('Insc. $insc · Reinsc. $reinsc',
                style: const TextStyle(fontSize: 10, color: UTSCColors.textoGris)),
          ]),
        );
      }).toList(),
    );
  }
}

/// Gráfica de columnas con una o varias series agrupadas.
class _Columnas extends StatelessWidget {
  final List<String> etiquetas;
  final List<List<int>> series;
  final List<Color> colores;
  final bool etiquetaChica;
  const _Columnas({
    required this.etiquetas, required this.series, required this.colores,
    this.etiquetaChica = false,
  });

  @override
  Widget build(BuildContext context) {
    var maximo = 0;
    for (final s in series) {
      for (final v in s) { maximo = math.max(maximo, v); }
    }
    const altoMax = 130.0;
    final fuente = etiquetaChica ? 8.5 : 10.5;

    final columnas = List.generate(etiquetas.length, (i) {
      return Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(series.length, (k) {
              final v = series[k][i];
              final h = maximo == 0 ? 0.0 : altoMax * v / maximo;
              return Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (!etiquetaChica || series.length == 1)
                      Text(v == 0 ? '' : '$v', style: const TextStyle(fontSize: 9, color: UTSCColors.textoGris)),
                    Container(
                      height: math.max(h, v > 0 ? 2.0 : 0.0),
                      decoration: BoxDecoration(
                        color: colores[k],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ),
                  ]),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(etiquetas[i], style: TextStyle(fontSize: fuente, color: UTSCColors.textoGris), maxLines: 1),
        ]),
      );
    });

    if (maximo == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('Sin datos', style: TextStyle(color: UTSCColors.textoGris))),
      );
    }
    return SizedBox(
      height: altoMax + 40,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: columnas),
    );
  }
}

/// Dona de estatus con leyenda.
class _DonaEstatus extends StatelessWidget {
  final List<int> valores;
  final List<Color> colores;
  final List<String> etiquetas;
  const _DonaEstatus({required this.valores, required this.colores, required this.etiquetas});

  @override
  Widget build(BuildContext context) {
    final total = valores.fold<int>(0, (a, b) => a + b);
    return Row(children: [
      SizedBox(
        width: 130, height: 130,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(size: const Size(130, 130), painter: _DonaPainter(valores, colores)),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$total', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text('solicitudes', style: TextStyle(fontSize: 10, color: UTSCColors.textoGris)),
          ]),
        ]),
      ),
      const SizedBox(width: 18),
      Expanded(
        child: Column(
          children: List.generate(etiquetas.length, (i) {
            final pct = total == 0 ? 0 : (valores[i] * 100 / total).round();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: colores[i], shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(etiquetas[i], style: const TextStyle(fontSize: 13))),
                Text('${valores[i]} ($pct%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            );
          }),
        ),
      ),
    ]);
  }
}

class _DonaPainter extends CustomPainter {
  final List<int> valores;
  final List<Color> colores;
  _DonaPainter(this.valores, this.colores);

  @override
  void paint(Canvas canvas, Size size) {
    const grosor = 22.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: math.min(size.width, size.height) / 2 - grosor / 2,
    );
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor;
    final total = valores.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      pincel.color = Colors.grey.shade300;
      canvas.drawArc(rect, 0, 2 * math.pi, false, pincel);
      return;
    }
    var inicio = -math.pi / 2;
    for (var i = 0; i < valores.length; i++) {
      if (valores[i] <= 0) continue;
      final barrido = 2 * math.pi * valores[i] / total;
      pincel.color = colores[i];
      canvas.drawArc(rect, inicio, barrido, false, pincel);
      inicio += barrido;
    }
  }

  @override
  bool shouldRepaint(covariant _DonaPainter old) => true;
}
