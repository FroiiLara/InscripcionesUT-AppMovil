import 'package:flutter/foundation.dart';

/// Mensajes de depuración. En la app publicada (release) NO se imprime nada,
/// así no se filtran URLs, respuestas del servidor ni datos del usuario en el log del teléfono.
void logDebug(String mensaje) {
  if (kDebugMode) debugPrint(mensaje);
}
