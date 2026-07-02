import 'dart:math' as math;

class GhOwner {
  final int id;
  final String login;
  final String avatarUrl;
  final String htmlUrl;
  final String type; // "User" or "Organization"

  GhOwner({
    required this.id,
    required this.login,
    required this.avatarUrl,
    required this.htmlUrl,
    required this.type,
  });

  factory GhOwner.fromJson(Map<String, dynamic> json) {
    return GhOwner(
      id: json['id'] as int,
      login: json['login'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      type: json['type'] as String? ?? 'User',
    );
  }
}

class GhLicense {
  final String key;
  final String name;
  final String? spdxId;

  GhLicense({required this.key, required this.name, this.spdxId});

  factory GhLicense.fromJson(Map<String, dynamic> json) {
    return GhLicense(
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      spdxId: json['spdx_id'] as String?,
    );
  }
}

class GhRepo {
  final int id;
  final String name;
  final String fullName;
  final GhOwner owner;
  final String? description;
  final String htmlUrl;
  final String? language;
  final int stargazersCount;
  final int forksCount;
  final int watchersCount;
  final int openIssuesCount;
  final int subscribersCount;
  final int size; // KB
  final String defaultBranch;
  final bool fork;
  final bool archived;
  final bool disabled;
  final GhLicense? license;
  final List<String> topics;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime pushedAt;
  final String? homepage;

  GhRepo({
    required this.id,
    required this.name,
    required this.fullName,
    required this.owner,
    required this.htmlUrl,
    required this.stargazersCount,
    required this.forksCount,
    required this.watchersCount,
    required this.openIssuesCount,
    required this.subscribersCount,
    required this.size,
    required this.defaultBranch,
    required this.fork,
    required this.archived,
    required this.disabled,
    required this.topics,
    required this.createdAt,
    required this.updatedAt,
    required this.pushedAt,
    this.description,
    this.language,
    this.license,
    this.homepage,
  });

  factory GhRepo.fromJson(Map<String, dynamic> json) {
    return GhRepo(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      owner: GhOwner.fromJson(json['owner'] as Map<String, dynamic>),
      description: json['description'] as String?,
      htmlUrl: json['html_url'] as String? ?? '',
      language: json['language'] as String?,
      stargazersCount: json['stargazers_count'] as int? ?? 0,
      forksCount: json['forks_count'] as int? ?? 0,
      watchersCount: json['watchers_count'] as int? ?? 0,
      openIssuesCount: json['open_issues_count'] as int? ?? 0,
      subscribersCount: json['subscribers_count'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      defaultBranch: json['default_branch'] as String? ?? 'main',
      fork: json['fork'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      disabled: json['disabled'] as bool? ?? false,
      license: json['license'] != null
          ? GhLicense.fromJson(json['license'] as Map<String, dynamic>)
          : null,
      topics: (json['topics'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      pushedAt: DateTime.tryParse(json['pushed_at'] as String? ?? '') ??
          DateTime.now(),
      homepage: json['homepage'] as String?,
    );
  }

  /// A real, locally-computed "health score" (0-100) derived purely from
  /// repo metadata already returned by the GitHub API. No mocked numbers.
  int get healthScore {
    double score = 0;

    final daysSincePush = DateTime.now().difference(pushedAt).inDays;
    if (daysSincePush <= 30) {
      score += 40;
    } else if (daysSincePush <= 180) {
      score += 28;
    } else if (daysSincePush <= 365) {
      score += 15;
    } else if (daysSincePush <= 730) {
      score += 6;
    }

    if (stargazersCount > 0) {
      final starScore = stargazersCount.toDouble().clamp(1, 200000);
      final normalized = (math.log(starScore) / math.log(200000)) * 25;
      score += normalized.clamp(0, 25);
    }

    if (stargazersCount > 0) {
      final ratio = openIssuesCount / stargazersCount;
      if (ratio < 0.02) {
        score += 20;
      } else if (ratio < 0.05) {
        score += 14;
      } else if (ratio < 0.1) {
        score += 8;
      } else {
        score += 2;
      }
    } else if (openIssuesCount == 0) {
      score += 10;
    }

    if (!archived && !disabled) score += 8;
    if (license != null) score += 4;
    if (description != null && description!.trim().isNotEmpty) score += 3;

    return score.clamp(0, 100).round();
  }

  String get healthLabel {
    final s = healthScore;
    if (s >= 75) return 'Excellent';
    if (s >= 55) return 'Healthy';
    if (s >= 35) return 'Moderate';
    return 'At Risk';
  }
}

class GhCommit {
  final String sha;
  final String message;
  final String authorName;
  final String? authorAvatarUrl;
  final DateTime date;
  final String htmlUrl;

  GhCommit({
    required this.sha,
    required this.message,
    required this.authorName,
    this.authorAvatarUrl,
    required this.date,
    required this.htmlUrl,
  });

  factory GhCommit.fromJson(Map<String, dynamic> json) {
    final commit = json['commit'] as Map<String, dynamic>? ?? {};
    final author = commit['author'] as Map<String, dynamic>? ?? {};
    final authorInfo = json['author'] as Map<String, dynamic>?;

    return GhCommit(
      sha: json['sha'] as String? ?? '',
      message: commit['message'] as String? ?? 'No message',
      authorName: author['name'] as String? ?? 'Unknown',
      authorAvatarUrl: authorInfo?['avatar_url'] as String?,
      date: DateTime.tryParse(author['date'] as String? ?? '') ?? DateTime.now(),
      htmlUrl: json['html_url'] as String? ?? '',
    );
  }
}
