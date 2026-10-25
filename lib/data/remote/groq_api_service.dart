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

  // Models tried in order — falls through on model errors / decommissioned models.
  static const _models = [
    'llama-3.3-70b-versatile',
    'llama-3.1-70b-versatile',
    'gemma2-9b-it',
    'llama3-70b-8192',
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

  /// General-purpose prompt — use when none of the typed methods fit.
  Future<String> queryGroq(String prompt) async {
    return _chat(
      system: 'You are a helpful AI assistant for developers.',
      user: prompt.length > _maxCodeChars ? prompt.substring(0, _maxCodeChars) : prompt,
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

        // Try next model for: 404, decommissioned/unsupported model errors, server errors.
        // Stop immediately for auth (401), rate limit (429), or bad input (413).
        final status = e.response?.statusCode ?? 0;
        final msg = err.message.toLowerCase();
        final stopNow = status == 401 || status == 429 || status == 413;
        final isModelError = !stopNow && (
            status == 404 ||
            status == 0 ||
            status >= 500 ||
            msg.contains('model') ||
            msg.contains('decommission') ||
            msg.contains('deprecated') ||
            msg.contains('not found') ||
            msg.contains('not supported') ||
            (status == 400 && !msg.contains('token'))
        );
        if (!isModelError) break;
      }
    }

    throw lastError ?? const GroqApiException('Could not reach the AI service.');
  }
}

// ── Exception ─────────────────────────────────────────────────────────────────

class GroqApiException implements Exception {
  final String message;
  final int? statusCode;
  const GroqApiException(this.message, {this.statusCode});

  /// True when the error is a rate-limit (429) response from Groq.
  bool get isQuotaExceeded => statusCode == 429;

  factory GroqApiException.fromDioError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final serverMsg = _extractMsg(data);

    if (status == 401) {
      return GroqApiException(
          'Invalid Groq API key. Go to Settings → AI Key and paste a valid key from console.groq.com.',
          statusCode: status);
    }
    if (status == 429) {
      return GroqApiException('Rate limit reached. Please wait a moment and try again.', statusCode: 429);
    }
    if (status == 413) {
      return GroqApiException('Input too large for the AI model. Try with a shorter file.', statusCode: status);
    }
    if (status != null && status >= 500) {
      return GroqApiException('Groq server error ($status)${serverMsg != null ? ': $serverMsg' : ''}. Try again in a moment.', statusCode: status);
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
