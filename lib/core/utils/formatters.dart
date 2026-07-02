/// Formats large counts the way GitHub does: 1234 -> "1.2k", 1500000 -> "1.5M"
String formatCount(int count) {
  if (count < 1000) return count.toString();
  if (count < 1000000) {
    final k = count / 1000;
    return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
  }
  final m = count / 1000000;
  return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
}

String formatSize(int sizeKb) {
  if (sizeKb < 1024) return '$sizeKb KB';
  final mb = sizeKb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(1)} GB';
}
