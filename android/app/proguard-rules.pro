# Flutter Core Keep Rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# WebRTC Native Bridge Keep Rules
-keep class com.cloudwebrtc.webrtc.** { *; }
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# Crypto & BouncyCastle / PointyCastle
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# Foreground Task & Image Processing
-keep class com.pravera.flutter_foreground_task.** { *; }
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

# Desugaring
-keep class j$.** { *; }
