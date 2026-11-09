# Políticas de permisos – App móvil Inscripciones UTSC (Android e iOS)

## Principios aplicados
1. **Contexto:** el permiso se pide solo cuando el usuario toca la función que lo necesita (nunca al abrir la app).
2. **Justificación previa:** antes del aviso del sistema se muestra un diálogo propio que explica para qué se usa y qué pasa si se niega.
3. **Degradación elegante:** si se niega, la función tiene una alternativa y la app sigue funcionando.
4. **Bloqueo permanente:** si el usuario marca "No volver a preguntar", se ofrece abrir los Ajustes del sistema.
5. **Mínimo necesario:** ubicación solo "en uso" (sin segundo plano), contactos solo lectura, sin acceso a llamadas ni SMS recibidos.
6. **Transparencia:** pantalla *Perfil → Permisos de la aplicación* con el estado de cada permiso y acceso a Ajustes.

## Matriz de permisos
| Permiso | Para qué se usa | Dónde | Android (Manifest) | iOS (Info.plist) | Si se niega |
|---|---|---|---|---|---|
| Cámara | Foto y documentos | Inscripción → fotografía | `CAMERA` | `NSCameraUsageDescription` | Elegir de galería |
| Micrófono | Dictado por voz | Nueva consulta (icono de micrófono) | `RECORD_AUDIO` | `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` | Escribir con teclado |
| GPS | Ruta hacia la UTSC | Soporte → Cómo llegar | `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | `NSLocationWhenInUseUsageDescription` | Mapa solo con destino |
| Almacenamiento | Elegir documentos de la galería | Inscripción y reinscripción | `READ_MEDIA_IMAGES` (Android 13+), `READ_EXTERNAL_STORAGE` (≤ 12) | `NSPhotoLibraryUsageDescription` | Tomar con cámara |
| Contactos | Contacto de emergencia | Inscripción → Elegir de mis contactos | `READ_CONTACTS` | `NSContactsUsageDescription` | Captura manual |
| SMS | Mensaje a Control Escolar | Soporte → Enviar SMS | `SEND_SMS` | No aplica (iOS no lo permite) | Consultas en la app / correo |
| Llamadas | Llamar a Control Escolar | Soporte → Llamar | `CALL_PHONE` | No aplica (iOS pide confirmación al marcar) | Marcar manualmente |

En iOS, SMS y llamadas no son permisos de la app: el sistema muestra su propia confirmación al abrir Mensajes o el marcador, por eso la app los marca como "No requerido".

## Archivos
- `lib/services/permisos_service.dart` – lógica central (estado, justificación, solicitud, Ajustes).
- `lib/screens/permisos_screen.dart` – centro de permisos del usuario.
- Integraciones: `inscripcion_screen`, `reinscripcion_screen`, `soporte_screen`, `nueva_consulta_screen`, `perfil_screen`.
- `android/app/src/main/AndroidManifest.xml` y `ios/Runner/Info.plist` – declaraciones.

## Pasos manuales
1. `flutter pub get` (nuevos paquetes: permission_handler, geolocator, flutter_contacts, speech_to_text).
2. **iOS (en Mac):** el paquete permission_handler requiere activar cada permiso en `ios/Podfile`. Dentro de `post_install`, en el bloque `target.build_configurations.each do |config|`, agrega:
```ruby
config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)',
  'PERMISSION_CAMERA=1', 'PERMISSION_MICROPHONE=1', 'PERMISSION_LOCATION=1',
  'PERMISSION_PHOTOS=1', 'PERMISSION_CONTACTS=1', 'PERMISSION_SPEECH_RECOGNIZER=1']
```
   Luego `cd ios && pod install`.
3. **Google Play:** `SEND_SMS` y `CALL_PHONE` son permisos restringidos; para publicar hay que llenar la *Declaración de permisos* o retirarlos (la app funciona igual con el marcador y Mensajes del sistema).
4. Prueba de cada flujo: permitir, negar, "no volver a preguntar" y reactivar desde Ajustes.
