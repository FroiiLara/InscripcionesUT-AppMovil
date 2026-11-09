import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/permisos_service.dart';

/// Centro de permisos: muestra para qué se usa cada permiso, su estado y permite gestionarlo.
class PermisosScreen extends StatefulWidget {
  const PermisosScreen({super.key});
  @override
  State<PermisosScreen> createState() => _PermisosScreenState();
}

class _PermisosScreenState extends State<PermisosScreen> with WidgetsBindingObserver {
  final Map<AppPermiso, EstadoPermiso> _estados = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver de Ajustes se refresca el estado.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _cargar();
  }

  Future<void> _cargar() async {
    for (final p in AppPermiso.values) {
      _estados[p] = await PermisosService.estado(p);
    }
    if (mounted) setState(() {});
  }

  Future<void> _gestionar(AppPermiso p) async {
    await PermisosService.asegurar(context, p);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UTSCColors.fondo,
      appBar: AppBar(
          backgroundColor: UTSCColors.verde,
          foregroundColor: Colors.white,
          title: const Text('Permisos de la aplicación')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
              'La app solo solicita un permiso cuando usas la función que lo necesita. Aquí puedes ver para qué se usa cada uno y cambiarlo cuando quieras.',
              style: TextStyle(color: UTSCColors.textoGris)),
          const SizedBox(height: 12),
          for (final p in AppPermiso.values) _tarjeta(p),
        ],
      ),
    );
  }

  Widget _tarjeta(AppPermiso p) {
    final i = PermisosService.info[p]!;
    final e = _estados[p];
    String texto;
    Color color;
    switch (e) {
      case EstadoPermiso.concedido:
        texto = 'Permitido';
        color = UTSCColors.aprobada;
        break;
      case EstadoPermiso.bloqueado:
        texto = 'Bloqueado';
        color = UTSCColors.error;
        break;
      case EstadoPermiso.noRequerido:
        texto = 'No requerido en este dispositivo';
        color = UTSCColors.textoGris;
        break;
      default:
        texto = 'Sin permitir';
        color = UTSCColors.revision;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(i.icono, color: UTSCColors.verde),
            const SizedBox(width: 10),
            Expanded(child: Text(i.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          Text(i.paraQue, style: const TextStyle(fontSize: 13)),
          if (e != null && e != EstadoPermiso.noRequerido && e != EstadoPermiso.concedido)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _gestionar(p),
                child: Text(e == EstadoPermiso.bloqueado ? 'Abrir Ajustes' : 'Permitir'),
              ),
            ),
          if (e == EstadoPermiso.concedido)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: PermisosService.abrirAjustes, child: const Text('Administrar en Ajustes')),
            ),
        ]),
      ),
    );
  }
}
