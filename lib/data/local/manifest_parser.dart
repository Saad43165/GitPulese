/// Real, lightweight manifest parsing — no external packages needed since
/// we only need top-level dependency names, not full semver resolution.
class ManifestDependency {
  final String name;
  final String? version;
  ManifestDependency(this.name, this.version);
}

class ManifestParseResult {
  final String manifestType; // pubspec.yaml | package.json | requirements.txt
  final List<ManifestDependency> dependencies;
  ManifestParseResult(this.manifestType, this.dependencies);
}

/// Licenses generally considered "copyleft" — risky for proprietary/closed
/// commercial use because they can require derivative works to be open-sourced.
const Set<String> copyleftLicenseIds = {
  'gpl-2.0', 'gpl-3.0', 'agpl-3.0', 'lgpl-2.1', 'lgpl-3.0', 'mpl-2.0', 'epl-2.0',
};

class ManifestParser {
  ManifestParser._();

  /// Returns null if the content doesn't look parseable as that format.
  static ManifestParseResult? parsePubspecYaml(String content) {
    final deps = <ManifestDependency>[];
    final lines = content.split('\n');
    bool inDeps = false;
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim() == 'dependencies:') {
        inDeps = true;
        continue;
      }
      if (inDeps) {
        if (line.isEmpty) continue;
        // A new top-level key (no leading whitespace) ends the deps block.
        if (!line.startsWith(' ') && !line.startsWith('\t')) {
          inDeps = false;
          continue;
        }
        // Only care about direct child keys (2-space indent), skip nested sdk: maps etc.
        final match = RegExp(r'^\s{2}([a-zA-Z0-9_]+):\s*(.*)$').firstMatch(line);
        if (match != null) {
          final name = match.group(1)!;
          if (name == 'flutter' || name == 'sdk') continue;
          final versionRaw = match.group(2)?.trim();
          deps.add(ManifestDependency(name, versionRaw?.isEmpty == true ? null : versionRaw));
        }
      }
    }
    return ManifestParseResult('pubspec.yaml', deps);
  }

  static ManifestParseResult? parsePackageJson(String content) {
    try {
      // Minimal hand-rolled JSON dependency extraction (avoids requiring
      // dart:convert's strict parser to choke on trailing commas in some repos).
      final depsBlockMatch =
          RegExp(r'"dependencies"\s*:\s*\{([^}]*)\}', dotAll: true).firstMatch(content);
      final deps = <ManifestDependency>[];
      if (depsBlockMatch != null) {
        final block = depsBlockMatch.group(1)!;
        final entryRegex = RegExp(r'"([^"]+)"\s*:\s*"([^"]+)"');
        for (final m in entryRegex.allMatches(block)) {
          deps.add(ManifestDependency(m.group(1)!, m.group(2)));
        }
      }
      return ManifestParseResult('package.json', deps);
    } catch (_) {
      return null;
    }
  }

  static ManifestParseResult? parseRequirementsTxt(String content) {
    final deps = <ManifestDependency>[];
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final match = RegExp(r'^([A-Za-z0-9_.\-]+)\s*([=<>!~]+=?\s*[^\s#]+)?').firstMatch(line);
      if (match != null) {
        deps.add(ManifestDependency(match.group(1)!, match.group(2)?.trim()));
      }
    }
    return ManifestParseResult('requirements.txt', deps);
  }
}
