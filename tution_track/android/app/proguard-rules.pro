# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in ${sdk.dir}/tools/proguard/proguard-android.txt

# Flutter-specific rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Sign-In
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }

# Keep model classes for JSON serialization
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Prevent stripping of required Bouncy Castle classes (used by flutter_secure_storage)
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# Play Core & Split Install (Flutter deferred components)
-dontwarn com.google.android.play.core.**

