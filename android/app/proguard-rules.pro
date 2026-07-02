# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Home Widget
-keep class es.antonborri.home_widget.** { *; }
-keep class com.gitpulse.app.TrendingWidgetProvider { *; }

# Path Provider & Share Plus
-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }

# Dio & Network
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

-dontwarn io.flutter.plugin.**
