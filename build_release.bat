@echo off
REM ============================================================
REM  Compila la APK de RELEASE con el codigo Dart OFUSCADO.
REM  Guarda la carpeta build\symbols: sin ella no se pueden leer
REM  los errores (stack traces) de la app publicada.
REM ============================================================
call flutter clean
call flutter pub get
call flutter build apk --release --obfuscate --split-debug-info=build/symbols
echo.
echo APK lista en: build\app\outputs\flutter-apk\app-release.apk
echo Simbolos (guardalos, NO los publiques): build\symbols
