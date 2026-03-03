# ──────────────────────────────────────────────────────────────────────────────
# AviQuest ProGuard / R8 Rules
# ──────────────────────────────────────────────────────────────────────────────

# Flutter wrapper — keep engine entry points
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Flutter Secure Storage native bridge
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep Hive native components
-keep class com.hivedb.** { *; }

# Prevent stripping of camera plugin
-keep class io.flutter.plugins.camera.** { *; }

# Prevent stripping of just_audio plugin
-keep class com.ryanheise.just_audio.** { *; }

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
}

# Obfuscation settings
-repackageclasses ''
-allowaccessmodification
-optimizationpasses 5

# Strip debug info
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable
