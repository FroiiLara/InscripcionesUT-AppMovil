import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/api_service.dart';
import 'consulta_detalle_screen.dart';
import 'faq_widgets.dart';

/// Control Escolar: bandeja de consultas y administración de preguntas frecuentes.
class ConsultasAdminScreen extends StatefulWidget {
  const ConsultasAdminScreen({super.key});
  @override
  State<ConsultasAdminScreen> createState() => _ConsultasAdminScreenState();
}

class _ConsultasAdminScreenState extends State<ConsultasAdminScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'Bandeja'), Tab(text: 'Preguntas frecuentes')],
        ),
      ),
      Expanded(child: TabBarView(controller: _tabs, children: const [_Bandeja(), _FaqsAdmin()])),
    ]);
  }
}

class _Bandeja extends StatefulWidget {
  const _Bandeja();
  @override
  State<_Bandeja> createState() => _BandejaState();
}

class _BandejaState extends State<_Bandeja> {
  final _busqueda = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _lista = [];
  Map<String, dynamic> _conteo = {};
  String _estatus = '';
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
    final d = await ApiService.getConsultasAdmin(estatus: _estatus, q: _busqueda.text.trim());
    if (!mounted) return;
    if (d == null) {
      setState(() {
        _cargando = false;
        _error = 'No se pudo cargar la bandeja.';
      });
      return;
    }
    setState(() {
      _lista = (d['consultas'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _conteo = Map<String, dynamic>.from(d['conteo'] as Map? ?? {});
      _cargando = false;
    });
  }

  Future<void> _abrir(String folio) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ConsultaDetalleScreen(folio: folio, admin: true)));
    _cargar();
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
              hintText: 'Folio, matrícula, nombre o asunto',
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
            for (final e in ['', 'Abierta', 'Respondida', 'Cerrada'])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: ChoiceChip(
                  label: Text(e.isEmpty ? 'Todas' : '$e (${_conteo[e] ?? 0})'),
                  selected: _estatus == e,
                  selectedColor: UTSCColors.naranjaClaro,
                  onSelected: (_) {
                    _estatus = e;
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
                    child: _lista.isEmpty
                        ? ListView(children: const [SizedBox(height: 80), EstadoVacio('No hay consultas.')])
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _lista.length,
                            itemBuilder: (_, i) {
                              final c = _lista[i];
                              final nuevo = c['no_leido_admin'] == true;
                              return Card(
                                child: ListTile(
                                  onTap: () => _abrir(c['folio'].toString()),
                                  leading: nuevo
                                      ? const Icon(Icons.circle, color: UTSCColors.naranja, size: 12)
                                      : const Icon(Icons.chat_bubble_outline, color: UTSCColors.textoGris),
                                  title: Text(c['asunto']?.toString() ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: nuevo ? FontWeight.bold : FontWeight.w600)),
                                  subtitle: Text(
                                      '${c['nombre']} (${c['usuario']})\n${c['folio']} · ${c['categoria']} · ${c['actualizada']}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  isThreeLine: true,
                                  trailing: EstatusChip(c['estatus']?.toString() ?? ''),
                                ),
                              );
                            },
                          ),
                  ),
      ),
    ]);
  }
}

class _FaqsAdmin extends StatefulWidget {
  const _FaqsAdmin();
  @override
  State<_FaqsAdmin> createState() => _FaqsAdminState();
}

class _FaqsAdminState extends State<_FaqsAdmin> {
  List<Map<String, dynamic>> _faqs = [];
  List<String> _categorias = [];
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
    final d = await ApiService.getFaqsAdmin();
    if (!mounted) return;
    if (d == null) {
      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar las preguntas.';
      });
      return;
    }
    setState(() {
      _faqs = (d['faqs'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _categorias = (d['categorias'] as List? ?? []).map((e) => e.toString()).toList();
      _cargando = false;
    });
  }

  void _aviso(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: error ? UTSCColors.error : null, content: Text(msg)));
  }

  Future<void> _editar([Map<String, dynamic>? faq]) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormFaq(faq: faq, categorias: _categorias),
    );
    if (guardado == true) _cargar();
  }

  Future<void> _alternar(Map<String, dynamic> f) async {
    final r = await ApiService.faqAdmin('publicar', {'id': f['id'], 'publicada': f['publicada'] != true});
    if (!mounted) return;
    if (r['ok'] != true) _aviso(r['mensaje'].toString(), error: true);
    _cargar();
  }

  Future<void> _eliminar(Map<String, dynamic> f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar pregunta'),
        content: Text(f['pregunta'].toString()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: UTSCColors.error),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ApiService.faqAdmin('eliminar', {'id': f['id']});
    if (!mounted) return;
    _aviso(r['mensaje'].toString(), error: r['ok'] != true);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(),
        backgroundColor: UTSCColors.naranja,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva pregunta'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: UTSCColors.verde))
          : _error != null
              ? EstadoVacio(_error!, onReintentar: _cargar)
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                    itemCount: _faqs.length,
                    itemBuilder: (_, i) {
                      final f = _faqs[i];
                      final visible = f['publicada'] == true;
                      return Card(
                        color: visible ? null : const Color(0xFFEEEEEE),
                        child: ListTile(
                          title: Text(f['pregunta'].toString(),
                              maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                          subtitle: Text('${f['categoria']}${visible ? '' : ' · OCULTA'}',
                              style: const TextStyle(fontSize: 11)),
                          onTap: () => _editar(f),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'editar') _editar(f);
                              if (v == 'publicar') _alternar(f);
                              if (v == 'eliminar') _eliminar(f);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'editar', child: Text('Editar')),
                              PopupMenuItem(value: 'publicar', child: Text(visible ? 'Ocultar' : 'Publicar')),
                              const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _FormFaq extends StatefulWidget {
  final Map<String, dynamic>? faq;
  final List<String> categorias;
  const _FormFaq({this.faq, required this.categorias});
  @override
  State<_FormFaq> createState() => _FormFaqState();
}

class _FormFaqState extends State<_FormFaq> {
  late final _pregunta = TextEditingController(text: widget.faq?['pregunta']?.toString() ?? '');
  late final _respuesta = TextEditingController(text: widget.faq?['respuesta']?.toString() ?? '');
  late String? _categoria = widget.faq?['categoria']?.toString();
  late bool _publicada = widget.faq == null ? true : widget.faq!['publicada'] == true;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _pregunta.dispose();
    _respuesta.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_categoria == null) {
      setState(() => _error = 'Elige una categoría.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final datos = {
      if (widget.faq != null) 'id': widget.faq!['id'],
      'categoria': _categoria,
      'pregunta': _pregunta.text.trim(),
      'respuesta': _respuesta.text.trim(),
      'publicada': _publicada,
    };
    final r = await ApiService.faqAdmin(widget.faq == null ? 'crear' : 'editar', datos);
    if (!mounted) return;
    if (r['ok'] == true) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _guardando = false;
        _error = r['mensaje'].toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.faq == null ? 'Nueva pregunta' : 'Editar pregunta',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _categoria,
            decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
            items: [for (final c in widget.categorias) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _categoria = v),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _pregunta,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Pregunta', border: OutlineInputBorder())),
          const SizedBox(height: 4),
          TextField(
              controller: _respuesta,
              maxLength: 2000,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                  labelText: 'Respuesta', alignLabelWithHint: true, border: OutlineInputBorder())),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Publicada'),
              value: _publicada,
              onChanged: (v) => setState(() => _publicada = v)),
          if (_error != null) Text(_error!, style: const TextStyle(color: UTSCColors.error)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(backgroundColor: UTSCColors.naranja, foregroundColor: Colors.white),
              child: _guardando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar'),
            ),
          ),
        ]),
      ),
    );
  }
}
