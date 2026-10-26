import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/secure_store.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
bool _irAlLoginEnCurso = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Borra datos sensibles que versiones anteriores guardaban en texto plano.
  await SecureStore.migrarDatosAntiguos();
  // Si la sesión ya no se puede renovar (token vencido/revocado), volver al login.
  ApiService.onSesionExpirada = () {
    final nav = navigatorKey.currentState;
    if (nav == null || _irAlLoginEnCurso) return;
    _irAlLoginEnCurso = true;
    nav.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(
            mensajeInicial: 'Tu sesión expiró. Inicia sesión de nuevo.'),
      ),
      (_) => false,
    );
    Future.delayed(const Duration(seconds: 2), () => _irAlLoginEnCurso = false);
  };
  ApiService.wakeUp(); // despierta Render en segundo plano
  runApp(const UTSCApp());
}

class UTSCApp extends StatelessWidget {
  const UTSCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'UTSC Inscripciones',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A5F5C),
          primary: const Color(0xFF1A5F5C),
          secondary: const Color(0xFFE65C00),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A5F5C),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF1A5F5C),
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
