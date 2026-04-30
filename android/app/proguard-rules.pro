# Flutter/Dart
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.lifecycle.**

# Google Sign-In + Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Firebase (Auth, Core, Firestore, Storage)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.recaptcha.** { *; }
-dontwarn com.google.android.recaptcha.**

# Google APIs
-keep class com.google.api.** { *; }
-dontwarn com.google.api.**

# Guava / HTTP
-keep class com.google.common.** { *; }
-dontwarn com.google.common.**

# gRPC + Protobuf (Firestore)
-keep class io.grpc.** { *; }
-dontwarn io.grpc.**
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# OkHttp (Firebase internal)
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-keep class okio.** { *; }
-dontwarn okio.**

# Gson
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes Exceptions

# Suppress warnings
-dontwarn javax.annotation.**
-dontwarn com.google.errorprone.**
-dontwarn com.google.j2objc.**
-dontwarn sun.misc.**
