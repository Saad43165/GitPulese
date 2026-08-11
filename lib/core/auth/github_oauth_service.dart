import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../constants/oauth_constants.dart';

class GitHubOAuthService {
  /// Returns the access token on success, null if user cancelled, throws on error.
  static Future<String?> signIn() async {
    final authUrl = Uri.https('github.com', '/login/oauth/authorize', {
      'client_id': OAuthConstants.clientId,
      'redirect_uri': OAuthConstants.callbackUrl,
      'scope': OAuthConstants.scopes,
    }).toString();

    String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: OAuthConstants.callbackScheme,
      );
    } on PlatformException catch (e) {
      // User dismissed the browser — not an error, just cancelled
      if (e.code == 'CANCELED' || e.code == 'org.openid.appauth.general' ) {
        return null;
      }
      throw Exception('Authentication failed: ${e.message}');
    }

    final uri = Uri.parse(result);
    final code = uri.queryParameters['code'];
    if (code == null) return null;

    try {
      final dio = Dio();
      final response = await dio.post(
        OAuthConstants.tokenEndpoint,
        data: {
          'client_id': OAuthConstants.clientId,
          'client_secret': OAuthConstants.clientSecret,
          'code': code,
        },
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (status) => true,
        ),
      );

      // GitHub can return data as JSON or as formUrlEncoded string depending on headers/mood
      var data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          data = Uri.splitQueryString(data);
        }
      }

      if (data is Map) {
        final token = data['access_token'] as String?;
        if (token == null || token.isEmpty) {
          throw Exception(data['error_description'] as String? ?? data['error'] as String? ?? 'No access token returned');
        }
        return token;
      }
      throw Exception('Invalid response format from GitHub');
    } on DioException catch (e) {
      throw Exception('Token exchange failed: ${e.message}');
    }
  }
}
