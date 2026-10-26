import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';
import '../services/api_service.dart';
import 'inscripcion_screen.dart';
import 'reinscripcion_screen.dart';
import 'historial_screen.dart';
import 'perfil_screen.dart';
import 'soporte_screen.dart';
import 'admin_panel_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int    _tabActual     = 0;
  String _nombreUsuario = '';
  bool   _esAdmin       = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nombreUsuario = prefs.getString('usuario_nombre') ?? 'Usuario';
      _esAdmin       = prefs.getBool('es_admin') ?? false;
    });
  }

  Future<void> _cerrarSesion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: UTSCColors.error),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ApiService.cerrarSesion(); // revoca la sesión en el servidor
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  List<Widget> get _pantallas => [
    _PantallaInicio(nombreUsuario: _nombreUsuario, esAdmin: _esAdmin),
    const HistorialScreen(),
    const PerfilScreen(),
    if (_esAdmin) const AdminPanelScreen(),
  ];

  List<BottomNavigationBarItem> get _navItems => [
    const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
    const BottomNavigationBarItem(
        icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'Historial'),
    const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
    if (_esAdmin)
      const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_outlined),
          activeIcon: Icon(Icons.admin_panel_settings),
          label: 'Admin'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: UTSCColors.verde,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.school_rounded, size: 22),
            SizedBox(width: 8),
            Text('UTSC', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.headset_mic_outlined),
            tooltip: 'Soporte',
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SoporteScreen())),
          ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: UTSCColors.naranja,
              radius: 16,
              child: Text(
                _nombreUsuario.isNotEmpty ? _nombreUsuario[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            onSelected: (val) {
              if (val == 'perfil') setState(() => _tabActual = 2);
              if (val == 'cerrar') _cerrarSesion();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(_nombreUsuario,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: UTSCColors.verde)),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'perfil',
                child: Row(children: [
                  Icon(Icons.person_outline, color: UTSCColors.verde), SizedBox(width: 8), Text('Mi Perfil')])),
              const PopupMenuItem(value: 'cerrar',
                child: Row(children: [
                  Icon(Icons.logout, color: UTSCColors.error), SizedBox(width: 8),
                  Text('Cerrar sesión', style: TextStyle(color: UTSCColors.error))])),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _pantallas[_tabActual],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabActual,
        onTap: (i) => setState(() => _tabActual = i),
        selectedItemColor: UTSCColors.verde,
        unselectedItemColor: UTSCColors.textoGris,
        type: BottomNavigationBarType.fixed,
        items: _navItems,
      ),
    );
  }
}

// ── Pantalla de inicio (tab 0) ────────────────────────────────
class _PantallaInicio extends StatelessWidget {
  final String nombreUsuario;
  final bool esAdmin;
  const _PantallaInicio({required this.nombreUsuario, required this.esAdmin});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bienvenida
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [UTSCColors.verde, Color(0xFF27AE60)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.waving_hand, color: Colors.white, size: 28),
                const SizedBox(height: 8),
                Text('Bienvenido,',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14)),
                Text(nombreUsuario,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(esAdmin ? 'Panel Administrativo' : 'Sistema de Inscripciones UTSC',
                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text('Trámites',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: UTSCColors.texto)),
          const SizedBox(height: 14),

          _TarjetaTramite(
            icono: Icons.school_outlined,
            titulo: 'Inscripción',
            subtitulo: 'Nuevo ingreso a la UTSC',
            color: UTSCColors.verde,
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const InscripcionScreen())),
          ),
          const SizedBox(height: 12),

          _TarjetaTramite(
            icono: Icons.refresh_outlined,
            titulo: 'Reinscripción',
            subtitulo: 'Continuación de estudios',
            color: UTSCColors.naranja,
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const ReinscripcionScreen())),
          ),
          const SizedBox(height: 24),

          const Text('Información UTSC',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: UTSCColors.texto)),
          const SizedBox(height: 14),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _InfoRow(icono: Icons.phone_outlined, texto: '(81) 81-24-84-00'),
                  const Divider(height: 20),
                  _InfoRow(icono: Icons.email_outlined, texto: 'utsc@utsc.edu.mx'),
                  const Divider(height: 20),
                  _InfoRow(icono: Icons.location_on_outlined,
                      texto: 'Carretera Monterrey-Saltillo Km. 61.5\nSanta Catarina, N.L.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _TarjetaTramite extends StatelessWidget {
  final IconData icono;
  final String titulo, subtitulo;
  final Color color;
  final VoidCallback onTap;
  const _TarjetaTramite({required this.icono, required this.titulo,
      required this.subtitulo, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icono, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 2),
                    Text(subtitulo, style: const TextStyle(fontSize: 13, color: UTSCColors.textoGris)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _InfoRow({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: UTSCColors.verde, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(texto, style: const TextStyle(fontSize: 14, color: UTSCColors.texto))),
      ],
    );
  }
}
