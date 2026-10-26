# Reglas de R8 / ProGuard para la versión release.
# Flutter y sus plugins ya incluyen sus propias reglas; estas cubren el almacenamiento
# seguro (Tink) y evitan avisos que detienen la compilación.

# flutter_secure_storage (EncryptedSharedPreferences / Tink)
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**

# local_auth (biometría)
-keep class androidx.biometric.** { *; }

# Play Core (Flutter lo referencia opcionalmente; no se usa)
-dontwarn com.google.android.play.core.**
