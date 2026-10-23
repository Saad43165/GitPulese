import 'dart:convert';
import 'package:dio/dio.dart';

/// Calls the Groq API directly from the app.
/// Get a free key at https://console.groq.com (no credit card required).
///
/// The key is stored securely on-device via flutter_secure_storage and
/// entered once by the user in Settings → AI Key.
class GroqApiService {
  static const _groqBaseUrl = 'https://api.groq.com/openai/v1';
  static const _maxCodeChars = 12000;
  static const _maxRepos = 30;

  // Models tried in order — falls through on 404/decommissioned model errors.
  static const _models = [
    'llama-3.1-8b-instant',
    'llama-3.3-70b-versatile',
    'gemma2-9b-it',
  ];

  final String _apiKey;

  GroqApiService(this._apiKey);

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<String> summarizeRepo({
    required String repoFullName,
    required String? description,
    required String? readme,
    required String? primaryLanguage,
    required List<String> topics,
  }) async {
    final prompt =
        'You are an expert developer assistant. Summarize the following GitHub '
        'repository in 3–4 concise paragraphs covering its purpose, tech stack, '
        'key features, and who would benefit from it.\n\n'
        'Repository: $repoFullName\n'
        'Language: ${primaryLanguage ?? 'Unknown'}\n'
        'Topics: ${topics.join(', ')}\n'
        'Description: ${description ?? 'None'}\n'
        'README excerpt:\n'
        '${readme != null ? readme.substring(0, readme.length.clamp(0, 2000)) : 'No README available'}';

    return _chat(
      system: 'You are a senior software engineer who writes clear, insightful repository summaries.',
      user: prompt,
    );
  }

  Future<String> analyzeDeveloper({
    required String username,
    required String? bio,
    required List<Map<String, dynamic>> repos,
  }) async {
    final repoList = repos
        .take(_maxRepos)
        .map((r) =>
            '- ${r['name']} (${r['language'] ?? 'unknown'}, ⭐${r['stars']}): '
            '${(r['description'] as String? ?? 'No description').substring(0, (r['description'] as String? ?? '').length.clamp(0, 200))}')
        .join('\n');

    final prompt = 'Analyze the GitHub profile of developer "@$username".\n'
        'Bio: ${bio ?? 'None'}\n'
        'Repositories:\n$repoList\n\n'
        'Write a 2–3 paragraph developer profile covering their primary domain, '
        'coding style, technology preferences, and standout projects.';

    return _chat(
      system: 'You are a senior engineering recruiter who writes insightful developer profiles based on GitHub activity.',
      user: prompt,
    );
  }

  Future<String> explainCode({
    required String filename,
    required String code,
  }) async {
    final trimmed = code.length > _maxCodeChars ? code.substring(0, _maxCodeChars) : code;
    return _chat(
      system: 'You are an expert code reviewer. Provide clear, structured, and actionable analysis.',
      user: 'File: $filename\n\n$trimmed',
    );
  }

  // ── Core chat call with model fallback ────────────────────────────────────

  Future<String> _chat({
    required String system,
    required String user,
  }) async {
    final dio = Dio(BaseOptions(
      baseUrl: _groqBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
    ));

    GroqApiException? lastError;

    for (final model in _models) {
      try {
        final response = await dio.post(
          '/chat/completions',
          data: {
            'model': model,
            'messages': [
              {'role': 'system', 'content': system},
              {'role': 'user', 'content': user},
            ],
            'temperature': 0.4,
            'max_tokens': 2048,
          },
        );

        final content =
            (response.data as Map?)?['choices']?[0]?['message']?['content'] as String?;
        if (content != null && content.trim().isNotEmpty) return content.trim();

        lastError = const GroqApiException('Groq returned an empty response.');
      } on DioException catch (e) {
        final err = GroqApiException.fromDioError(e);
        lastError = err;

        // Only try the next model for model-related errors (404, bad_request mentioning model).
        final status = e.response?.statusCode ?? 0;
        final msg = err.message.toLowerCase();
        final isModelError =
            status == 404 || (status == 400 && msg.contains('model'));
        if (!isModelError) break;
      }
    }

    throw lastError ?? const GroqApiException('Could not reach the AI service.');
  }
}

// ── Exception ─────────────────────────────────────────────────────────────────

class GroqApiException implements Exception {
  final String message;
  const GroqApiException(this.message);

  factory GroqApiException.fromDioError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final serverMsg = _extractMsg(data);

    if (status == 401) {
      return const GroqApiException(
          'Invalid Groq API key. Go to Settings → AI Key and paste a valid key from console.groq.com.');
    }
    if (status == 429) {
      return const GroqApiException('Rate limit reached. Please wait a moment and try again.');
    }
    if (status == 413) {
      return const GroqApiException('Input too large for the AI model. Try with a shorter file.');
    }
    if (status != null && status >= 500) {
      return GroqApiException('Groq server error ($status)${serverMsg != null ? ': $serverMsg' : ''}. Try again in a moment.');
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const GroqApiException(
          'Request timed out. Check your internet connection and try again.');
    }
    if (e.type == DioExceptionType.connectionError) {
      return const GroqApiException(
          'Could not connect to Groq. Check your internet connection.');
    }
    if (serverMsg != null) return GroqApiException('AI error: $serverMsg');
    return const GroqApiException('Could not reach the AI service. Please try again.');
  }

  static String? _extractMsg(dynamic data) {
    if (data is Map) {
      final err = data['error'];
      if (err is String) return err;
      if (err is Map) return err['message'] as String?;
    }
    return null;
  }

  @override
  String toString() => message;
}
