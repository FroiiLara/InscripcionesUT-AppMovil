#!/usr/bin/env bash
# Compila la APK de RELEASE con el código Dart ofuscado.
# Guarda build/symbols: sin esa carpeta no se pueden leer los errores de la app publicada.
set -e
flutter clean
flutter pub get
flutter build apk --release --obfuscate --split-debug-info=build/symbols
echo "APK lista en: build/app/outputs/flutter-apk/app-release.apk"
echo "Símbolos (guárdalos, NO los publiques): build/symbols"
