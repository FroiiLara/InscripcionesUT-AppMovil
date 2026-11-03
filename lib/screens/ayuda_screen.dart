import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/api_service.dart';
import 'faq_widgets.dart';
import 'nueva_consulta_screen.dart';
import 'consulta_detalle_screen.dart';

/// Ayuda del alumno: preguntas frecuentes + sus consultas con Control Escolar.
class AyudaScreen extends StatefulWidget {
  const AyudaScreen({super.key});
  @override
  State<AyudaScreen> createState() => _AyudaScreenState();
}

class _AyudaScreenState extends State<AyudaScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Material(
        color: Colors.white,
        child: TabBar(
          controller: _tabs,
          labelColor: UTSCColors.verde,
          indicatorColor: UTSCColors.naranja,
          tabs: const [Tab(text: 'Preguntas frecuentes'), Tab(text: 'Mis consultas')],
        ),
      ),
      Expanded(
        child: TabBarView(controller: _tabs, children: [
          FaqLista(onNuevaConsulta: () => _tabs.animateTo(1)),
          const _MisConsultas(),
        ]),
      ),
    ]);
  }
}

/// Lista de preguntas frecuentes con búsqueda y filtro por categoría.
class FaqLista extends StatefulWidget {
  final VoidCallback? onNuevaConsulta;
  const FaqLista({super.key, this.onNuevaConsulta});
  @override
  State<FaqLista> createState() => _FaqListaState();
}

class _FaqListaState extends State<FaqLista> {
  final _busqueda = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _faqs = [];
  List<String> _categorias = [];
  String _categoria = '';
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    final d = await ApiService.getFaqs(q: _busqueda.text.trim(), categoria: _categoria);
    if (!mounted) return;
    if (d == null) {
      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar las preguntas frecuentes.';
      });
      return;
    }
    setState(() {
      _faqs = (d['faqs'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _categorias = (d['categorias'] as List? ?? []).map((e) => e.toString()).toList();
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          controller: _busqueda,
          maxLength: 60,
          decoration: const InputDecoration(
              counterText: '',
              hintText: 'Busca tu duda (certificado, pago…)',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder()),
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), _cargar);
          },
        ),
      ),
      SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final c in ['', ..._categorias])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: ChoiceChip(
                  label: Text(c.isEmpty ? 'Todas' : c),
                  selected: _categoria == c,
                  selectedColor: UTSCColors.naranjaClaro,
                  onSelected: (_) {
                    _categoria = c;
                    _cargar();
                  },
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: _cargando
            ? const Center(child: CircularProgressIndicator(color: UTSCColors.verde))
            : _error != null
                ? EstadoVacio(_error!, onReintentar: _cargar)
                : RefreshIndicator(
                    onRefresh: _cargar,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        if (_faqs.isEmpty)
                          const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                  child: Text('No encontramos preguntas con ese criterio.',
                                      style: TextStyle(color: UTSCColors.textoGris)))),
                        for (final f in _faqs)
                          Card(
                            child: ExpansionTile(
                              title: Text(f['pregunta']?.toString() ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text(f['categoria']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 11, color: UTSCColors.textoGris)),
                              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              expandedCrossAxisAlignment: CrossAxisAlignment.start,
                              children: [Text(f['respuesta']?.toString() ?? '')],
                            ),
                          ),
                        if (widget.onNuevaConsulta != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: UTSCColors.naranjaClaro, borderRadius: BorderRadius.circular(12)),
                            child: Column(children: [
                              const Text('¿No encontraste tu respuesta?',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: widget.onNuevaConsulta,
                                icon: const Icon(Icons.chat_outlined),
                                label: const Text('Preguntar a Control Escolar'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: UTSCColors.naranja, foregroundColor: Colors.white),
                              ),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
    ]);
  }
}

class _MisConsultas extends StatefulWidget {
  const _MisConsultas();
  @override
  State<_MisConsultas> createState() => _MisConsultasState();
}

class _MisConsultasState extends State<_MisConsultas> {
  List<Map<String, dynamic>> _lista = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    final d = await ApiService.getConsultas();
    if (!mounted) return;
    if (d == null) {
      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar tus consultas.';
      });
      return;
    }
    setState(() {
      _lista = (d['consultas'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _cargando = false;
    });
  }

  Future<void> _nueva() async {
    final creada = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const NuevaConsultaScreen()));
    if (creada == true) _cargar();
  }

  Future<void> _abrir(String folio) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => ConsultaDetalleScreen(folio: folio)));
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nueva,
        backgroundColor: UTSCColors.naranja,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva consulta'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: UTSCColors.verde))
          : _error != null
              ? EstadoVacio(_error!, onReintentar: _cargar)
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: _lista.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 80),
                          EstadoVacio(
                              'Aún no tienes consultas.\nRevisa las preguntas frecuentes o crea una nueva.')
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                          itemCount: _lista.length,
                          itemBuilder: (_, i) {
                            final c = _lista[i];
                            final nuevo = c['no_leido_alumno'] == true;
                            return Card(
                              child: ListTile(
                                onTap: () => _abrir(c['folio'].toString()),
                                leading: nuevo
                                    ? const Icon(Icons.circle, color: UTSCColors.naranja, size: 12)
                                    : const Icon(Icons.chat_bubble_outline, color: UTSCColors.textoGris),
                                title: Text(c['asunto']?.toString() ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontWeight: nuevo ? FontWeight.bold : FontWeight.w600)),
                                subtitle: Text(
                                    '${c['folio']} · ${c['actualizada']}\n${c['ultimo'] ?? ''}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                isThreeLine: true,
                                trailing: EstatusChip(c['estatus']?.toString() ?? ''),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
