import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';

/// Calls OUR backend proxy's /ai/summarize route, which holds the real
/// Groq API key server-side. The app never sees or stores a Groq key —
/// this works identically for every user with zero setup.
class GroqApiService {
  GroqApiService();

  final Dio _dio = Dio();

  Future<String> summarizeRepo({
    required String repoFullName,
    required String? description,
    required String? readme,
    required String? primaryLanguage,
    required List<String> topics,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.backendBaseUrl}/ai/summarize',
        data: {
          'repoFullName': repoFullName,
          'description': description,
          'readme': readme,
          'primaryLanguage': primaryLanguage,
          'topics': topics,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final summary = response.data['summary'] as String?;
      if (summary == null || summary.trim().isEmpty) {
        throw GroqApiException('Empty summary returned.');
      }
      return summary.trim();
    } on DioException catch (e) {
      throw GroqApiException.fromDioError(e);
    }
  }

  Future<String> analyzeDeveloper({
    required String username,
    required String? bio,
    required List<Map<String, dynamic>> repos,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.backendBaseUrl}/ai/analyze-user',
        data: {
          'username': username,
          'bio': bio,
          'repos': repos,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final analysis = response.data['analysis'] as String?;
      if (analysis == null || analysis.trim().isEmpty) {
        throw GroqApiException('Empty analysis returned.');
      }
      return analysis.trim();
    } on DioException catch (e) {
      throw GroqApiException.fromDioError(e);
    }
  }

  Future<String> explainCode({
    required String filename,
    required String code,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.backendBaseUrl}/ai/explain-code',
        data: {
          'filename': filename,
          'code': code,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final explanation = response.data['explanation'] as String?;
      if (explanation == null || explanation.trim().isEmpty) {
        throw GroqApiException('Empty explanation returned.');
      }
      return explanation.trim();
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
      return GroqApiException('AI summaries are temporarily unavailable. Try again shortly.');
    }
    if (status == 429) {
      return GroqApiException('Too many requests right now. Try again in a minute.');
    }
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
      return GroqApiException('Request timed out — the server may be waking up (free tier), try again in 30s.');
    }
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return GroqApiException(data['message'] as String);
    }
    return GroqApiException('Could not reach the summary service.');
  }

  @override
  String toString() => message;
}
