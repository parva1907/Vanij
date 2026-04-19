# Keep Firebase SDK classes — they use reflection.
-keep class com.google.firebase.** { *; }
-keep class io.flutter.** { *; }
-dontwarn com.google.firebase.**
