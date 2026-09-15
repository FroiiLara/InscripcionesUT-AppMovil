import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});
  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  Map<String, dynamic>? _perfil;
  bool _cargando = true;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    final data = await ApiService.getPerfil();
    setState(() { _perfil = data; _cargando = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UTSCColors.fondo,
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: UTSCColors.verde))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: UTSCColors.verde,
                    child: Text(
                      (_perfil?['usuario'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_perfil?['usuario'] ?? 'Usuario',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: UTSCColors.verde)),
                  const SizedBox(height: 4),
                  Text(_perfil?['es_admin'] == true ? 'Administrador' : 'Alumno',
                      style: const TextStyle(color: UTSCColors.textoGris, fontSize: 14)),
                  const SizedBox(height: 28),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _ItemPerfil(icono: Icons.badge_outlined,   etiqueta: 'Matrícula', valor: _perfil?['matricula'] ?? '—'),
                          const Divider(height: 24),
                          _ItemPerfil(icono: Icons.person_outline,   etiqueta: 'Nombre',    valor: _perfil?['usuario']  ?? '—'),
                          const Divider(height: 24),
                          _ItemPerfil(icono: Icons.email_outlined,   etiqueta: 'Correo',    valor: _perfil?['email']    ?? '—'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Abriendo aviso de privacidad...'))),
                    icon: const Icon(Icons.description_outlined, color: UTSCColors.verde),
                    label: const Text('Aviso de Privacidad', style: TextStyle(color: UTSCColors.verde)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: UTSCColors.verde),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await ApiService.clearToken();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UTSCColors.error,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ItemPerfil extends StatelessWidget {
  final IconData icono;
  final String etiqueta, valor;
  const _ItemPerfil({required this.icono, required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, color: UTSCColors.verde, size: 22),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiqueta, style: const TextStyle(fontSize: 12, color: UTSCColors.textoGris)),
            Text(valor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: UTSCColors.texto)),
          ],
        ),
      ],
    );
  }
}
