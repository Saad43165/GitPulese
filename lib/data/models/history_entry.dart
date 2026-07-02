/// Represents one real, persisted history entry — either a search query
/// the user ran, or a repo/user they opened.
class HistoryEntry {
  final int? id;
  final String type; // 'search_repo' | 'search_code' | 'search_user' | 'search_issue' | 'viewed_repo' | 'viewed_user'
  final String query; // search text OR full_name/login of viewed item
  final String? subtitle; // e.g. description, or language filter used
  final String? avatarUrl;
  final DateTime timestamp;

  HistoryEntry({
    this.id,
    required this.type,
    required this.query,
    this.subtitle,
    this.avatarUrl,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'query': query,
      'subtitle': subtitle,
      'avatarUrl': avatarUrl,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      id: map['id'] as int?,
      type: map['type'] as String,
      query: map['query'] as String,
      subtitle: map['subtitle'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  bool get isSearch => type.startsWith('search_');
}
