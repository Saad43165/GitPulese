import 'repo_model.dart' show GhOwner;

class GhUser {
  final int id;
  final String login;
  final String avatarUrl;
  final String htmlUrl;
  final String type;
  final String? name;
  final String? bio;
  final String? company;
  final String? location;
  final String? blog;
  final String? twitterUsername;
  final int followers;
  final int following;
  final int publicRepos;
  final int publicGists;
  final DateTime? createdAt;

  GhUser({
    required this.id,
    required this.login,
    required this.avatarUrl,
    required this.htmlUrl,
    required this.type,
    this.name,
    this.bio,
    this.company,
    this.location,
    this.blog,
    this.twitterUsername,
    this.followers = 0,
    this.following = 0,
    this.publicRepos = 0,
    this.publicGists = 0,
    this.createdAt,
  });

  factory GhUser.fromJson(Map<String, dynamic> json) {
    return GhUser(
      id: json['id'] as int,
      login: json['login'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      type: json['type'] as String? ?? 'User',
      name: json['name'] as String?,
      bio: json['bio'] as String?,
      company: json['company'] as String?,
      location: json['location'] as String?,
      blog: json['blog'] as String?,
      twitterUsername: json['twitter_username'] as String?,
      followers: json['followers'] as int? ?? 0,
      following: json['following'] as int? ?? 0,
      publicRepos: json['public_repos'] as int? ?? 0,
      publicGists: json['public_gists'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class GhCodeResult {
  final String name;
  final String path;
  final String sha;
  final String htmlUrl;
  final String repoFullName;
  final String repoHtmlUrl;
  final int? score;

  GhCodeResult({
    required this.name,
    required this.path,
    required this.sha,
    required this.htmlUrl,
    required this.repoFullName,
    required this.repoHtmlUrl,
    this.score,
  });

  factory GhCodeResult.fromJson(Map<String, dynamic> json) {
    final repo = json['repository'] as Map<String, dynamic>?;
    return GhCodeResult(
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
      sha: json['sha'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      repoFullName: repo?['full_name'] as String? ?? '',
      repoHtmlUrl: repo?['html_url'] as String? ?? '',
      score: (json['score'] as num?)?.round(),
    );
  }

  String get extension {
    final idx = name.lastIndexOf('.');
    return idx == -1 ? '' : name.substring(idx + 1);
  }
}

class GhIssue {
  final int id;
  final int number;
  final String title;
  final String state;
  final String htmlUrl;
  final GhOwner user;
  final List<String> labels;
  final int comments;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPullRequest;
  final String repoFullName;

  GhIssue({
    required this.id,
    required this.number,
    required this.title,
    required this.state,
    required this.htmlUrl,
    required this.user,
    required this.labels,
    required this.comments,
    required this.createdAt,
    required this.updatedAt,
    required this.isPullRequest,
    required this.repoFullName,
  });

  factory GhIssue.fromJson(Map<String, dynamic> json) {
    final url = json['html_url'] as String? ?? '';
    // repo_url looks like https://api.github.com/repos/{owner}/{repo}
    final repoUrl = json['repository_url'] as String? ?? '';
    final parts = repoUrl.split('/');
    final repoFullName =
        parts.length >= 2 ? '${parts[parts.length - 2]}/${parts.last}' : '';

    return GhIssue(
      id: json['id'] as int,
      number: json['number'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      state: json['state'] as String? ?? 'open',
      htmlUrl: url,
      user: GhOwner.fromJson(json['user'] as Map<String, dynamic>),
      labels: (json['labels'] as List<dynamic>?)
              ?.map((l) => (l as Map<String, dynamic>)['name'].toString())
              .toList() ??
          const [],
      comments: json['comments'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      isPullRequest: json['pull_request'] != null,
      repoFullName: repoFullName,
    );
  }
}
