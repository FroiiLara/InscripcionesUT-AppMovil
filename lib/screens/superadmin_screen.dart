import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/api_service.dart';

/// Administración del sistema (solo Super Admin): cuentas y roles.
/// No muestra solicitudes ni trámites: eso es del Admin (Control Escolar) y del alumno.
class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});
  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  static const _roles = ['alumno', 'admin', 'super_admin'];
  static const _etiquetas = {
    'alumno': 'Alumno',
    'admin': 'Administrador',
    'super_admin': 'Super Administrador',
  };

  final _busquedaCtrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _usuarios = [];
  Map<String, dynamic> _conteo = {};
  String _filtroRol = '';
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
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    final data = await ApiService.getUsuarios(
        q: _busquedaCtrl.text.trim(), rol: _filtroRol);
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _cargando = false;
        _error = 'No se pudo cargar la lista de usuarios.';
      });
      return;
    }
    final lista = (data['usuarios'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    setState(() {
      _usuarios = lista;
      _conteo = Map<String, dynamic>.from((data['conteo'] as Map?) ?? {});
      _cargando = false;
    });
  }

  void _alBuscar(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _cargar);
  }

  void _aviso(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: error ? UTSCColors.error : UTSCColors.verde,
    ));
  }

  Future<void> _ejecutar(Future<Map<String, dynamic>> Function() accion) async {
    final r = await accion();
    _aviso(r['mensaje']?.toString() ?? '', error: r['ok'] != true);
    if (r['ok'] == true) await _cargar();
  }

  Future<bool> _confirmar(String titulo, String texto, {bool peligro = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: peligro ? UTSCColors.error : UTSCColors.verde),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _cambiarRol(Map<String, dynamic> u) async {
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Rol de ${u['usuario']}'),
        children: [
          for (final r in _roles)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r),
              child: Row(children: [
                Icon(
                  r == u['rol'] ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: UTSCColors.verde,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(_etiquetas[r]!),
              ]),
            ),
        ],
      ),
    );
    if (nuevo == null || nuevo == u['rol']) return;
    final ok = await _confirmar('Cambiar rol',
        '${u['usuario']} (${u['matricula']}) pasará a ser ${_etiquetas[nuevo]}. Se cerrarán sus sesiones.');
    if (ok) await _ejecutar(() => ApiService.cambiarRolUsuario(u['matricula'], nuevo));
  }

  Future<void> _alElegir(String accion, Map<String, dynamic> u) async {
    final m = u['matricula'].toString();
    switch (accion) {
      case 'rol':
        await _cambiarRol(u);
        break;
      case 'desbloquear':
        await _ejecutar(() => ApiService.desbloquearUsuario(m));
        break;
      case 'sesiones':
        if (await _confirmar('Cerrar sesiones', '¿Cerrar todas las sesiones de $m?')) {
          await _ejecutar(() => ApiService.cerrarSesionesUsuario(m));
        }
        break;
      case 'eliminar':
        if (await _confirmar('Eliminar cuenta',
            '¿Eliminar la cuenta $m? Esta acción no se puede deshacer.',
            peligro: true)) {
          await _ejecutar(() => ApiService.eliminarUsuario(m));
        }
        break;
    }
  }

  Color _colorRol(String rol) {
    switch (rol) {
      case 'super_admin':
        return const Color(0xFF4527A0);
      case 'admin':
        return UTSCColors.naranja;
      default:
        return const Color(0xFF1565C0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UTSCColors.fondo,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _Stat(numero: '${_conteo['alumno'] ?? 0}', etiqueta: 'Alumnos', color: _colorRol('alumno')),
                const SizedBox(width: 8),
                _Stat(numero: '${_conteo['admin'] ?? 0}', etiqueta: 'Admins', color: _colorRol('admin')),
                const SizedBox(width: 8),
                _Stat(numero: '${_conteo['super_admin'] ?? 0}', etiqueta: 'Super', color: _colorRol('super_admin')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _busquedaCtrl,
              onChanged: _alBuscar,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Buscar por matrícula, nombre o correo',
                prefixIcon: Icon(Icons.search, color: UTSCColors.verde),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final f in const [
                  ['', 'Todos'],
                  ['alumno', 'Alumnos'],
                  ['admin', 'Admins'],
                  ['super_admin', 'Super admins'],
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f[1]),
                      selected: _filtroRol == f[0],
                      selectedColor: UTSCColors.verde.withOpacity(0.2),
                      onSelected: (_) {
                        setState(() => _filtroRol = f[0]);
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
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, style: const TextStyle(color: UTSCColors.error)),
                            const SizedBox(height: 8),
                            OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: UTSCColors.verde,
                        onRefresh: _cargar,
                        child: _usuarios.isEmpty
                            ? ListView(children: const [
                                SizedBox(height: 80),
                                Center(
                                    child: Text('Sin resultados.',
                                        style: TextStyle(color: UTSCColors.textoGris))),
                              ])
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                itemCount: _usuarios.length,
                                itemBuilder: (_, i) => _tarjeta(_usuarios[i]),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> u) {
    final rol = u['rol'].toString();
    final esYo = u['es_yo'] == true;
    final fijo = u['fijo'] == true;
    final bloqueado = u['bloqueado'] == true;
    final intentos = (u['intentos'] is num) ? (u['intentos'] as num).toInt() : 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _colorRol(rol).withOpacity(0.15),
              child: Text(
                u['usuario'].toString().isNotEmpty ? u['usuario'].toString()[0].toUpperCase() : '?',
                style: TextStyle(color: _colorRol(rol), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u['usuario'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: UTSCColors.texto)),
                  Text('${u['matricula']} · ${u['email']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: UTSCColors.textoGris)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _colorRol(rol).withOpacity(0.12),
                          border: Border.all(color: _colorRol(rol)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_etiquetas[rol] ?? rol,
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold, color: _colorRol(rol))),
                      ),
                      if (fijo) const Icon(Icons.lock, size: 14, color: UTSCColors.textoGris),
                      if (bloqueado)
                        const Text('Bloqueada',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold, color: UTSCColors.error)),
                      if (esYo)
                        const Text('Tú',
                            style: TextStyle(fontSize: 11, color: UTSCColors.textoGris)),
                    ],
                  ),
                ],
              ),
            ),
            if (!esYo)
              PopupMenuButton<String>(
                tooltip: 'Acciones',
                onSelected: (a) => _alElegir(a, u),
                itemBuilder: (_) => [
                  if (!fijo)
                    const PopupMenuItem(
                        value: 'rol',
                        child: Row(children: [
                          Icon(Icons.swap_horiz, color: UTSCColors.verde),
                          SizedBox(width: 8),
                          Text('Cambiar rol'),
                        ])),
                  if (bloqueado || intentos > 0)
                    const PopupMenuItem(
                        value: 'desbloquear',
                        child: Row(children: [
                          Icon(Icons.lock_open, color: UTSCColors.naranja),
                          SizedBox(width: 8),
                          Text('Desbloquear'),
                        ])),
                  const PopupMenuItem(
                      value: 'sesiones',
                      child: Row(children: [
                        Icon(Icons.logout, color: UTSCColors.naranja),
                        SizedBox(width: 8),
                        Text('Cerrar sesiones'),
                      ])),
                  if (!fijo && rol != 'super_admin')
                    const PopupMenuItem(
                        value: 'eliminar',
                        child: Row(children: [
                          Icon(Icons.delete_outline, color: UTSCColors.error),
                          SizedBox(width: 8),
                          Text('Eliminar cuenta', style: TextStyle(color: UTSCColors.error)),
                        ])),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String numero, etiqueta;
  final Color color;
  const _Stat({required this.numero, required this.etiqueta, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Text(numero,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(etiqueta,
                style: const TextStyle(fontSize: 11, color: UTSCColors.textoGris)),
          ],
        ),
      ),
    );
  }
}
