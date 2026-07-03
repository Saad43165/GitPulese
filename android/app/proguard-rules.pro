# Flutter core
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.plugin.**

# Flutter embedding
-keep class io.flutter.embedding.** { *; }

# Home Widget / App Widgets
-keep class es.antonborri.home_widget.** { *; }
-keep class com.gitpulse.app.TrendingWidgetProvider { *; }
-keep class com.gitpulse.app.OverviewWidgetProvider { *; }
-keep class com.gitpulse.app.TopRepoWidgetProvider { *; }
-keep class com.gitpulse.app.ContributionWidgetProvider { *; }
-keep class com.gitpulse.app.LanguageWidgetProvider { *; }

# Path Provider & Share Plus
-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }

# Dio & OkHttp networking
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Workmanager — critical: must keep dispatcher entry point
-keep class androidx.work.** { *; }
-keep class be.tramckrijte.workmanager.** { *; }
-keepclassmembers class * extends androidx.work.Worker { *; }
-keepclassmembers class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# flutter_local_notifications
-keep class com.dexterous.** { *; }
-keep class androidx.core.app.NotificationCompat** { *; }
-dontwarn com.dexterous.**

# Shared Preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Cached network image / http
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Google Play Core (In App Review)
-keep class com.google.android.play.core.review.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.**

# Gson / JSON (used by workmanager internally)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
