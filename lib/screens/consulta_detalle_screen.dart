import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/api_service.dart';
import 'faq_widgets.dart';

/// Conversación de una consulta. Con [admin] = true muestra las acciones de Control Escolar.
class ConsultaDetalleScreen extends StatefulWidget {
  final String folio;
  final bool admin;
  const ConsultaDetalleScreen({super.key, required this.folio, this.admin = false});
  @override
  State<ConsultaDetalleScreen> createState() => _ConsultaDetalleScreenState();
}

class _ConsultaDetalleScreenState extends State<ConsultaDetalleScreen> {
  final _texto = TextEditingController();
  final _scroll = ScrollController();
  Map<String, dynamic>? _c;
  bool _cargando = true;
  bool _enviando = false;
  bool _cerrarAlResponder = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _texto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = _c == null;
      _error = null;
    });
    final d = await ApiService.getConsulta(widget.folio, admin: widget.admin);
    if (!mounted) return;
    if (d == null || d['consulta'] == null) {
      setState(() {
        _cargando = false;
        _error = 'No se pudo cargar la consulta.';
      });
      return;
    }
    setState(() {
      _c = Map<String, dynamic>.from(d['consulta'] as Map);
      _cargando = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _aviso(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: error ? UTSCColors.error : null, content: Text(msg)));
  }

  Future<void> _enviar() async {
    final t = _texto.text.trim();
    if (t.isEmpty) return;
    setState(() => _enviando = true);
    final r = await ApiService.enviarMensaje(widget.folio, t,
        admin: widget.admin, cerrar: _cerrarAlResponder);
    if (!mounted) return;
    setState(() => _enviando = false);
    if (r['ok'] == true) {
      _texto.clear();
      _cerrarAlResponder = false;
      await _cargar();
    } else {
      _aviso(r['mensaje'].toString(), error: true);
    }
  }

  Future<void> _cambiarEstatus(String estatus) async {
    final r = widget.admin
        ? await ApiService.cambiarEstatusConsulta(widget.folio, estatus)
        : await ApiService.cerrarConsulta(widget.folio);
    if (!mounted) return;
    _aviso(r['mensaje'].toString(), error: r['ok'] != true);
    if (r['ok'] == true) _cargar();
  }

  Future<void> _confirmarCerrar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar consulta'),
        content: const Text('¿Ya resolviste tu duda?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar')),
        ],
      ),
    );
    if (ok == true) _cambiarEstatus('Cerrada');
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final cerrada = c?['estatus'] == 'Cerrada';
    return Scaffold(
      backgroundColor: UTSCColors.fondo,
      appBar: AppBar(
        backgroundColor: UTSCColors.verde,
        foregroundColor: Colors.white,
        title: Text(widget.folio, style: const TextStyle(fontSize: 16)),
        actions: [
          if (c != null && !cerrada)
            TextButton.icon(
              onPressed: widget.admin ? () => _cambiarEstatus('Cerrada') : _confirmarCerrar,
              icon: const Icon(Icons.lock_outline, color: Colors.white, size: 18),
              label: const Text('Cerrar', style: TextStyle(color: Colors.white)),
            ),
          if (c != null && cerrada && widget.admin)
            TextButton.icon(
              onPressed: () => _cambiarEstatus('Abierta'),
              icon: const Icon(Icons.replay, color: Colors.white, size: 18),
              label: const Text('Reabrir', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: UTSCColors.verde))
          : _error != null
              ? EstadoVacio(_error!, onReintentar: _cargar)
              : Column(children: [
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        EstatusChip(c!['estatus'].toString()),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(c['categoria'].toString(),
                                style: const TextStyle(color: UTSCColors.textoGris, fontSize: 12))),
                      ]),
                      const SizedBox(height: 6),
                      Text(c['asunto'].toString(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (widget.admin)
                        Text('${c['nombre']} (${c['usuario']})',
                            style: const TextStyle(color: UTSCColors.textoGris, fontSize: 12)),
                    ]),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(14),
                        children: [
                          for (final m in (c['mensajes'] as List? ?? []))
                            _Burbuja(m: Map<String, dynamic>.from(m as Map), admin: widget.admin),
                        ],
                      ),
                    ),
                  ),
                  if (cerrada && !widget.admin)
                    Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: const EdgeInsets.all(14),
                      child: const Text('Esta consulta está cerrada. Para otra duda, crea una nueva consulta.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: UTSCColors.textoGris)),
                    )
                  else
                    SafeArea(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Expanded(
                              child: TextField(
                                controller: _texto,
                                minLines: 1,
                                maxLines: 5,
                                maxLength: 2000,
                                decoration: InputDecoration(
                                    counterText: '',
                                    hintText: widget.admin ? 'Responder al alumno…' : 'Escribe un mensaje…',
                                    border: const OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _enviando ? null : _enviar,
                              style: IconButton.styleFrom(backgroundColor: UTSCColors.naranja),
                              icon: _enviando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.send),
                            ),
                          ]),
                          if (widget.admin)
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _cerrarAlResponder,
                              onChanged: (v) => setState(() => _cerrarAlResponder = v ?? false),
                              title: const Text('Cerrar al responder', style: TextStyle(fontSize: 13)),
                            ),
                        ]),
                      ),
                    ),
                ]),
    );
  }
}

class _Burbuja extends StatelessWidget {
  final Map<String, dynamic> m;
  final bool admin;
  const _Burbuja({required this.m, required this.admin});

  @override
  Widget build(BuildContext context) {
    final deAdmin = m['de'] == 'admin';
    // El que mira ve sus propios mensajes a la derecha.
    final mio = admin ? deAdmin : !deAdmin;
    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: deAdmin ? UTSCColors.aprobadaFondo : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: deAdmin ? UTSCColors.aprobada.withOpacity(0.3) : UTSCColors.borde),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(deAdmin ? 'Control Escolar' : (m['autor']?.toString().isNotEmpty == true ? m['autor'].toString() : 'Alumno'),
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: deAdmin ? UTSCColors.aprobada : UTSCColors.textoGris)),
          const SizedBox(height: 4),
          Text(m['texto']?.toString() ?? ''),
          const SizedBox(height: 6),
          Align(
              alignment: Alignment.centerRight,
              child: Text(m['fecha']?.toString() ?? '',
                  style: const TextStyle(fontSize: 10, color: UTSCColors.textoGris))),
        ]),
      ),
    );
  }
}
