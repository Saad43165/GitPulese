import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';

/// Calls the GitPulse AI Worker (Cloudflare) which holds the Groq API key
/// server-side. Users never need to configure or provide any API key.
///
/// Worker: gitpulse-worker/src/index.js
/// Free tier: 100,000 requests/day, zero cold starts, global edge network.
class GroqApiService {
  GroqApiService();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.backendBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  Future<String> summarizeRepo({
    required String repoFullName,
    required String? description,
    required String? readme,
    required String? primaryLanguage,
    required List<String> topics,
  }) async {
    return _post('/ai/summarize', {
      'repoFullName': repoFullName,
      'description': description,
      'readme': readme,
      'primaryLanguage': primaryLanguage,
      'topics': topics,
    }, responseKey: 'summary');
  }

  Future<String> analyzeDeveloper({
    required String username,
    required String? bio,
    required List<Map<String, dynamic>> repos,
  }) async {
    return _post('/ai/analyze-user', {
      'username': username,
      'bio': bio,
      'repos': repos,
    }, responseKey: 'analysis');
  }

  Future<String> explainCode({
    required String filename,
    required String code,
  }) async {
    return _post('/ai/explain-code', {
      'filename': filename,
      'code': code,
    }, responseKey: 'explanation');
  }

  Future<String> _post(
    String path,
    Map<String, dynamic> data, {
    required String responseKey,
  }) async {
    try {
      final response = await _dio.post(path, data: data);

      final Map<String, dynamic> json;
      if (response.data is Map) {
        json = Map<String, dynamic>.from(response.data as Map);
      } else if (response.data is String) {
        json = Map<String, dynamic>.from(
            jsonDecode(response.data as String) as Map);
      } else {
        throw GroqApiException('Unexpected response format from AI service.');
      }

      final value = json[responseKey] as String?;
      if (value == null || value.trim().isEmpty) {
        throw GroqApiException('AI service returned an empty response.');
      }
      return value.trim();
    } on DioException catch (e) {
      throw GroqApiException.fromDioError(e);
    }
  }
}

class GroqApiException implements Exception {
  final String message;
  GroqApiException(this.message);

  factory GroqApiException.fromDioError(DioException e) {
    final status = e.response?.statusCode;

    if (status == 503) {
      return GroqApiException(
          'AI service is temporarily unavailable. Please try again shortly.');
    }
    if (status == 429) {
      return GroqApiException(
          'Rate limit reached. Please wait a minute and try again.');
    }
    if (status != null && status >= 500) {
      return GroqApiException(
          'AI server error ($status). Please try again in a moment.');
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return GroqApiException(
          'Request timed out. Please check your internet connection and try again.');
    }
    if (e.type == DioExceptionType.connectionError) {
      return GroqApiException(
          'Could not connect to the AI service. Check your internet connection.');
    }
    final data = e.response?.data;
    if (data is Map && data['error'] != null) {
      return GroqApiException('AI error: ${data['error']}');
    }
    return GroqApiException(
        'Could not reach the AI service. Please try again.');
  }

  @override
  String toString() => message;
}
