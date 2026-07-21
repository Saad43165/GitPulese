import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/core_providers.dart';
import '../../providers/settings_providers.dart';
import '../../data/models/user_and_search_models.dart';
import '../../data/models/repo_model.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/safe_page.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/app_back_button.dart';

class PortfolioGeneratorScreen extends ConsumerStatefulWidget {
  const PortfolioGeneratorScreen({super.key});

  @override
  ConsumerState<PortfolioGeneratorScreen> createState() => _PortfolioGeneratorScreenState();
}

class _PortfolioGeneratorScreenState extends ConsumerState<PortfolioGeneratorScreen> {
  int _selectedTheme = 0; // 0: Sleek Dark, 1: CLI Terminal, 2: Glassmorphic
  int _customizeSectionIndex = 0; // 0: Identity, 1: Tech Stack, 2: Links
  bool _isDeploying = false;
  String _deployStep = '';
  String? _deployedUrl;
  bool _hasCopiedCode = false;
  final ScrollController _repoListScrollController = ScrollController();

  // Customization Controllers
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _locationController = TextEditingController();
  final _skillsController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _twitterController = TextEditingController();
  final _websiteController = TextEditingController();
  final _emailController = TextEditingController();

  final List<String> _selectedRepoNames = [];
  GhRepo? _targetDeployRepo;
  bool _initializedDefaults = false;

  final GlobalKey _themeKey = GlobalKey();
  final GlobalKey _customizeKey = GlobalKey();
  final GlobalKey _deployKey = GlobalKey();
  final GlobalKey _badgeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkAndShowTutorial();
  }

  void _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_portfolio_tutorial') ?? false;
    if (!seen && mounted) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        ShowcaseView.get().startShowCase([
          _themeKey,
          _customizeKey,
          _deployKey,
          _badgeKey,
        ]);
        await prefs.setBool('seen_portfolio_tutorial', true);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _locationController.dispose();
    _skillsController.dispose();
    _linkedinController.dispose();
    _twitterController.dispose();
    _websiteController.dispose();
    _emailController.dispose();
    _repoListScrollController.dispose();
    super.dispose();
  }

  void _initializeUserData(GhUser user, List<GhRepo>? repos) {
    if (_initializedDefaults) return;
    _initializedDefaults = true;

    _nameController.text = (user.name != null && user.name!.isNotEmpty) ? user.name! : user.login;
    _roleController.text = (user.bio != null && user.bio!.isNotEmpty) ? user.bio! : 'Full Stack Developer & Open Source Contributor';
    _locationController.text = (user.location != null && user.location!.isNotEmpty) ? user.location! : 'Remote';
    _skillsController.text = 'Flutter, Dart, React, TypeScript, Node.js, Git';
    _emailController.text = ''; // GhUser has no email field
    _websiteController.text = (user.blog != null && user.blog!.isNotEmpty) ? user.blog! : '';
    _twitterController.text = (user.twitterUsername != null && user.twitterUsername!.isNotEmpty) ? 'https://twitter.com/${user.twitterUsername}' : '';
    
    // Auto-select top 3 repos initially
    if (repos != null && repos.isNotEmpty) {
      for (final r in repos.take(3)) {
        _selectedRepoNames.add(r.fullName);
      }
      _targetDeployRepo = repos.first;
    }
  }

  Future<void> _deployReal(String username) async {
    if (_targetDeployRepo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a target repository for deployment.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isDeploying = true;
      _deployedUrl = null;
      _deployStep = 'Initializing GitHub Pages deployment...';
    });

    try {
      final api = ref.read(githubApiServiceProvider);
      final owner = _targetDeployRepo!.owner.login;
      final repo = _targetDeployRepo!.name;
      final branch = _targetDeployRepo!.defaultBranch;

      setState(() => _deployStep = 'Checking for existing index.html in $repo...');
      await Future.delayed(const Duration(milliseconds: 600));

      String sha = '';
      try {
        final fileDetails = await api.getFileDetails(owner, repo, 'index.html', ref: branch);
        sha = fileDetails['sha'] as String? ?? '';
      } catch (_) {
        // File doesn't exist, which is fine (sha remains empty)
      }

      setState(() => _deployStep = 'Compiling customized portfolio HTML...');
      final authUser = ref.read(authenticatedUserProvider).valueOrNull;
      final allRepos = authUser != null ? ref.read(userReposProvider(authUser.login)).valueOrNull : null;
      
      // Filter repos chosen by the user
      final featuredRepos = allRepos?.where((r) => _selectedRepoNames.contains(r.fullName)).toList() ?? [];
      final htmlContent = _generateHtmlCode(authUser, featuredRepos);

      setState(() => _deployStep = 'Pushing index.html commit to branch $branch...');
      await api.updateFile(
        owner: owner,
        repo: repo,
        path: 'index.html',
        content: htmlContent,
        sha: sha,
        message: 'Publish portfolio website via GitPulse Suite',
        branch: branch,
      );

      setState(() => _deployStep = 'Finalizing static file routing...');
      try {
        await api.enablePages(owner: owner, repo: repo, branch: branch);
      } catch (_) {
        // Safe to ignore if pages already configured or temporarily failing, 
        // since the static files are already committed.
      }
      await Future.delayed(const Duration(milliseconds: 800));

      final lowerOwner = owner.toLowerCase();
      final lowerRepo = repo.toLowerCase();

      setState(() {
        _isDeploying = false;
        if (lowerRepo == '$lowerOwner.github.io') {
          _deployedUrl = 'https://$lowerOwner.github.io/';
        } else {
          _deployedUrl = 'https://$lowerOwner.github.io/$repo/';
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully deployed to GitHub Pages!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDeploying = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deployment failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _generateHtmlCode(GhUser? user, List<GhRepo>? repos) {
    final username = user?.login ?? 'Guest';
    final name = _nameController.text.trim();
    final bio = _roleController.text.trim();
    final avatar = user?.avatarUrl ?? 'https://github.com/identicons/$username.png';
    final location = _locationController.text.trim();
    final followers = user?.followers ?? 0;
    final reposCount = user?.publicRepos ?? 0;

    final skillsList = _skillsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    String css = '';
    String bodyHtml = '';

    if (_selectedTheme == 0) {
      // Sleek Dark Theme
      css = '''
        :root {
          --bg-color: #0F172A;
          --card-bg: #1E293B;
          --accent: #8B5CF6;
          --accent-soft: rgba(139, 92, 246, 0.15);
          --text-primary: #F8FAFC;
          --text-secondary: #94A3B8;
          --border: #334155;
        }
        body {
          background-color: var(--bg-color);
          color: var(--text-primary);
          font-family: 'Inter', system-ui, -apple-system, sans-serif;
          margin: 0;
          padding: 40px 20px;
          display: flex;
          justify-content: center;
        }
        .container {
          max-width: 900px;
          width: 100%;
        }
        header {
          display: flex;
          align-items: center;
          gap: 24px;
          padding-bottom: 32px;
          border-bottom: 1px solid var(--border);
          margin-bottom: 40px;
        }
        .avatar {
          width: 96px;
          height: 96px;
          border-radius: 50%;
          border: 3px solid var(--accent);
          object-fit: cover;
        }
        .info h1 {
          margin: 0 0 8px 0;
          font-size: 32px;
          font-weight: 800;
        }
        .info p {
          margin: 0 0 12px 0;
          color: var(--text-secondary);
          line-height: 1.5;
        }
        .meta-badges {
          display: flex;
          gap: 12px;
          flex-wrap: wrap;
          margin-bottom: 16px;
        }
        .badge {
          background: var(--card-bg);
          border: 1px solid var(--border);
          padding: 6px 12px;
          border-radius: 20px;
          font-size: 13px;
          color: var(--text-secondary);
        }
        .skills-section {
          margin-bottom: 32px;
        }
        .skills-grid {
          display: flex;
          gap: 10px;
          flex-wrap: wrap;
        }
        .skill-pill {
          background: var(--accent-soft);
          color: #DDD6FE;
          border: 1px solid rgba(139, 92, 246, 0.3);
          padding: 6px 14px;
          border-radius: 12px;
          font-size: 12px;
          font-weight: 600;
        }
        .socials-row {
          display: flex;
          gap: 16px;
          margin-top: 12px;
        }
        .social-link {
          color: var(--accent);
          text-decoration: none;
          font-weight: 600;
          font-size: 14px;
        }
        .social-link:hover {
          text-decoration: underline;
        }
        .grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
          gap: 20px;
        }
        .card {
          background: var(--card-bg);
          border: 1px solid var(--border);
          border-radius: 12px;
          padding: 24px;
          transition: transform 0.2s, border-color 0.2s;
          text-decoration: none;
          color: inherit;
          display: flex;
          flex-direction: column;
          justify-content: space-between;
        }
        .card:hover {
          transform: translateY(-4px);
          border-color: var(--accent);
        }
        .card h3 {
          margin: 0 0 8px 0;
          font-size: 18px;
          color: var(--text-primary);
        }
        .card p {
          margin: 0 0 20px 0;
          font-size: 14px;
          color: var(--text-secondary);
          line-height: 1.5;
          flex-grow: 1;
        }
        .card-footer {
          display: flex;
          justify-content: space-between;
          align-items: center;
          font-size: 12px;
          color: var(--text-secondary);
        }
        .lang {
          display: flex;
          align-items: center;
          gap: 6px;
        }
        .lang-dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;
          background: var(--accent);
        }
      ''';
    } else if (_selectedTheme == 1) {
      // CLI Terminal Theme
      css = '''
        body {
          background-color: #050505;
          color: #10B981;
          font-family: 'Fira Code', monospace;
          margin: 0;
          padding: 40px 20px;
          display: flex;
          justify-content: center;
        }
        .container {
          max-width: 900px;
          width: 100%;
          border: 1px solid #10B981;
          border-radius: 8px;
          overflow: hidden;
        }
        .terminal-bar {
          background: #1A1A1A;
          padding: 10px 16px;
          display: flex;
          gap: 8px;
          border-bottom: 1px solid #10B981;
        }
        .dot {
          width: 12px;
          height: 12px;
          border-radius: 50%;
        }
        .terminal-content {
          padding: 32px;
        }
        .avatar {
          width: 80px;
          height: 80px;
          border: 2px solid #10B981;
          border-radius: 4px;
          margin-bottom: 24px;
        }
        h1 {
          font-size: 28px;
          margin: 0 0 12px 0;
        }
        p {
          color: #A7F3D0;
          margin: 0 0 16px 0;
        }
        .command {
          color: #FBBF24;
          margin-bottom: 24px;
        }
        .command::before {
          content: "\$ ";
        }
        .skills-grid {
          display: flex;
          gap: 8px;
          flex-wrap: wrap;
          margin-bottom: 20px;
        }
        .skill-tag {
          border: 1px dashed #10B981;
          padding: 4px 10px;
          font-size: 11px;
        }
        .socials-row {
          margin-bottom: 24px;
        }
        .social-link {
          color: #34D399;
          text-decoration: none;
          margin-right: 16px;
        }
        .social-link:hover {
          text-decoration: underline;
        }
        .grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
          gap: 20px;
        }
        .card {
          border: 1px solid #10B981;
          border-radius: 4px;
          padding: 20px;
          text-decoration: none;
          color: inherit;
        }
        .card:hover {
          background: rgba(16, 185, 129, 0.05);
        }
        .card h3 {
          margin: 0 0 8px 0;
          color: #10B981;
        }
        .card p {
          color: #A7F3D0;
          font-size: 14px;
        }
        .card-footer {
          display: flex;
          justify-content: space-between;
          font-size: 12px;
          color: #34D399;
        }
      ''';
    } else {
      // Glassmorphism Theme
      css = '''
        body {
          background: radial-gradient(circle at 50% 50%, #1e1b4b 0%, #090514 100%);
          color: #F8FAFC;
          font-family: system-ui, -apple-system, sans-serif;
          margin: 0;
          padding: 40px 20px;
          display: flex;
          justify-content: center;
          min-height: 100vh;
        }
        .container {
          max-width: 900px;
          width: 100%;
        }
        header {
          background: rgba(255, 255, 255, 0.03);
          backdrop-filter: blur(12px);
          -webkit-backdrop-filter: blur(12px);
          border: 1px solid rgba(255, 255, 255, 0.08);
          border-radius: 24px;
          padding: 32px;
          display: flex;
          align-items: center;
          gap: 30px;
          margin-bottom: 40px;
        }
        .avatar {
          width: 110px;
          height: 110px;
          border-radius: 50%;
          border: 2px solid rgba(255, 255, 255, 0.2);
          box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
        }
        .info h1 {
          margin: 0 0 8px 0;
          font-size: 36px;
          background: linear-gradient(to right, #C084FC, #6366F1);
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
        }
        .info p {
          margin: 0 0 16px 0;
          color: #CBD5E1;
        }
        .badge {
          background: rgba(255, 255, 255, 0.05);
          backdrop-filter: blur(4px);
          border: 1px solid rgba(255, 255, 255, 0.1);
          padding: 6px 16px;
          border-radius: 12px;
          font-size: 13px;
        }
        .skills-grid {
          display: flex;
          gap: 10px;
          flex-wrap: wrap;
          margin: 16px 0;
        }
        .skill-pill {
          background: rgba(255, 255, 255, 0.04);
          border: 1px solid rgba(255, 255, 255, 0.1);
          padding: 6px 14px;
          border-radius: 10px;
          font-size: 12px;
          backdrop-filter: blur(4px);
        }
        .socials-row {
          display: flex;
          gap: 16px;
          margin-top: 12px;
        }
        .social-link {
          color: #A78BFA;
          text-decoration: none;
          font-weight: bold;
          font-size: 13px;
        }
        .social-link:hover {
          color: #C084FC;
        }
        .grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
          gap: 20px;
        }
        .card {
          background: rgba(255, 255, 255, 0.02);
          backdrop-filter: blur(8px);
          -webkit-backdrop-filter: blur(8px);
          border: 1px solid rgba(255, 255, 255, 0.05);
          border-radius: 16px;
          padding: 24px;
          text-decoration: none;
          color: inherit;
          transition: background 0.3s, border-color 0.3s;
        }
        .card:hover {
          background: rgba(255, 255, 255, 0.06);
          border-color: rgba(255, 255, 255, 0.15);
        }
        .card h3 {
          margin: 0 0 8px 0;
          color: #E9D5FF;
        }
      ''';
    }

    // Generate Skills HTML
    String skillsHtml = '';
    if (skillsList.isNotEmpty) {
      if (_selectedTheme == 1) {
        skillsHtml = '<div class="skills-grid">' + 
            skillsList.map((s) => '<span class="skill-tag">[skill] $s</span>').join('') + 
            '</div>';
      } else {
        skillsHtml = '<div class="skills-grid">' + 
            skillsList.map((s) => '<span class="skill-pill">$s</span>').join('') + 
            '</div>';
      }
    }

    // Generate Social Links HTML
    String socialsHtml = '';
    final socLinks = <String>[];
    if (_emailController.text.trim().isNotEmpty) {
      socLinks.add('<a href="mailto:${_emailController.text.trim()}" class="social-link">✉ Email</a>');
    }
    if (_websiteController.text.trim().isNotEmpty) {
      socLinks.add('<a href="${_websiteController.text.trim()}" target="_blank" class="social-link">🌐 Website</a>');
    }
    if (_linkedinController.text.trim().isNotEmpty) {
      socLinks.add('<a href="${_linkedinController.text.trim()}" target="_blank" class="social-link">🔗 LinkedIn</a>');
    }
    if (_twitterController.text.trim().isNotEmpty) {
      socLinks.add('<a href="${_twitterController.text.trim()}" target="_blank" class="social-link">🐦 Twitter</a>');
    }
    if (socLinks.isNotEmpty) {
      socialsHtml = '<div class="socials-row">${socLinks.join('')}</div>';
    }

    String reposHtml = '';
    if (repos != null && repos.isNotEmpty) {
      for (final r in repos) {
        final rName = r.name;
        final rDesc = r.description ?? 'No description provided.';
        final rLang = r.language ?? 'Unknown';
        final rStars = r.stargazersCount;
        final rUrl = r.htmlUrl;

        reposHtml += '''
        <a href="$rUrl" target="_blank" class="card">
          <div>
            <h3>$rName</h3>
            <p>$rDesc</p>
          </div>
          <div class="card-footer">
            <span class="lang"><span class="lang-dot"></span>$rLang</span>
            <span>★ $rStars</span>
          </div>
        </a>
        ''';
      }
    } else {
      reposHtml = '''
      <div class="card">
        <h3>Sample Repository</h3>
        <p>A demonstration repository for GitPulse Premium Suite.</p>
        <div class="card-footer">
          <span class="lang"><span class="lang-dot"></span>Flutter</span>
          <span>★ 42</span>
        </div>
      </div>
      ''';
    }

    if (_selectedTheme == 1) {
      bodyHtml = '''
      <div class="container">
        <div class="terminal-bar">
          <div class="dot" style="background:#EF4444"></div>
          <div class="dot" style="background:#F59E0B"></div>
          <div class="dot" style="background:#10B981"></div>
        </div>
        <div class="terminal-content">
          <img class="avatar" src="$avatar" alt="Avatar">
          <div class="command">whoami</div>
          <h1>$name</h1>
          <p>$bio</p>
          <p>Location: $location | Repositories: $reposCount | Followers: $followers</p>
          
          <div class="command">cat skills.txt</div>
          $skillsHtml
          
          <div class="command">cat contact.txt</div>
          $socialsHtml
          
          <div class="command">ls --projects</div>
          <div class="grid">
            $reposHtml
          </div>
        </div>
      </div>
      ''';
    } else if (_selectedTheme == 0) {
      bodyHtml = '''
      <div class="container">
        <header>
          <img class="avatar" src="$avatar" alt="Avatar">
          <div class="info">
            <h1>$name</h1>
            <p>$bio</p>
            <div class="meta-badges">
              <span class="badge">📍 $location</span>
              <span class="badge">📦 $reposCount Repositories</span>
              <span class="badge">👥 $followers Followers</span>
            </div>
            $socialsHtml
          </div>
        </header>
        <main>
          <div class="skills-section">
            <h2 style="margin-bottom: 16px; font-weight: 800; font-size: 20px;">Skills & Technologies</h2>
            $skillsHtml
          </div>
          <h2 style="margin-bottom: 24px; font-weight: 800; font-size: 20px;">Featured Projects</h2>
          <div class="grid">
            $reposHtml
          </div>
        </main>
      </div>
      ''';
    } else {
      bodyHtml = '''
      <div class="container">
        <header>
          <img class="avatar" src="$avatar" alt="Avatar">
          <div class="info">
            <h1>$name</h1>
            <p>$bio</p>
            <div style="display:flex; gap:12px; flex-wrap:wrap; margin-bottom: 12px;">
              <span class="badge">📍 $location</span>
              <span class="badge">📦 $reposCount Repos</span>
              <span class="badge">👥 $followers Followers</span>
            </div>
            $socialsHtml
          </div>
        </header>
        <main>
          <div class="skills-section" style="background: rgba(255,255,255,0.01); border: 1px solid rgba(255,255,255,0.04); padding:24px; border-radius:16px; margin-bottom:32px;">
            <h2 style="margin-top:0; margin-bottom: 16px; font-weight: 800; font-size: 20px; text-align: center;">Tech Stack</h2>
            $skillsHtml
          </div>
          <h2 style="margin-bottom: 24px; font-weight: 800; font-size: 20px; text-align: center;">Featured Projects</h2>
          <div class="grid">
            $reposHtml
          </div>
        </main>
      </div>
      ''';
    }

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$name | Portfolio</title>
  <style>
    $css
  </style>
</head>
<body>
  $bodyHtml
</body>
</html>''';
  }

  String _generateBadgeMarkdown(String username) {
    return '[![GitPulse Stats](https://github-readme-stats.vercel.app/api?username=$username&show_icons=true&theme=radial)](https://github.com/$username)';
  }

  void _showHtmlPreview(BuildContext context, GhUser? user, List<GhRepo>? repos) {
    final featuredRepos = repos?.where((r) => _selectedRepoNames.contains(r.fullName)).toList() ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final username = user?.login ?? 'guest';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close Preview',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final scale = 0.92 + (anim1.value * 0.08);
        final opacity = anim1.value;
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.25),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- MOCK BROWSER HEADER ---
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(22),
                          topRight: Radius.circular(22),
                        ),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          // macOS Dots
                          Row(
                            children: [
                              Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF5F56))),
                              const SizedBox(width: 6),
                              Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFBD2E))),
                              const SizedBox(width: 6),
                              Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF27C93F))),
                            ],
                          ),
                          const SizedBox(width: 24),
                          // Address Bar
                          Expanded(
                            child: Container(
                              height: 30,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                children: [
                                  Icon(Icons.lock_rounded, size: 12, color: Colors.green[400]),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'https://$username.github.io/portfolio',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                        fontFamily: 'monospace',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.refresh_rounded, size: 12, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Close Action
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                              ),
                              child: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- LIVE PREVIEW CONTAINER ---
                    Flexible(
                      child: Container(
                        height: 520,
                        color: isDark ? const Color(0xFF020617) : Colors.grey[50],
                        child: ClipRRect(
                          child: _PortfolioVisualPreview(
                            themeIndex: _selectedTheme,
                            username: user?.login ?? 'Guest',
                            name: _nameController.text.trim(),
                            bio: _roleController.text.trim(),
                            avatarUrl: user?.avatarUrl,
                            location: _locationController.text.trim(),
                            repos: featuredRepos,
                            skills: _skillsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                            website: _websiteController.text.trim(),
                            linkedin: _linkedinController.text.trim(),
                            twitter: _twitterController.text.trim(),
                            email: _emailController.text.trim(),
                          ),
                        ),
                      ),
                    ),

                    // --- BOTTOM STATUS & EXPORT OPTIONS ---
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(22),
                          bottomRight: Radius.circular(22),
                        ),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Live Simulated Rendering',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('Exit Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.art_track_rounded, color: AppColors.accent),
            SizedBox(width: 8),
            Text('Portfolio Builder'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What is this feature?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                'This screen lets you build and publish your personal portfolio website using your GitHub profile metrics and pinned repositories.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'Under the Hood:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                '• Assembles profile statistics, technologies, and contribution parameters.\n'
                '• Commits index.html to your selected repository using the GitHub API.\n'
                '• Enables free web hosting via GitHub Pages.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'How to use:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                '1. Select a Design Theme (CLI retro, Dark, or Glassmorphism).\n'
                '2. Verify display settings, description text, and skills.\n'
                '3. Choose the repositories you want to feature.\n'
                '4. Select a deployment repository (e.g. your username.github.io) and click Deploy.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authenticatedUserProvider);
    
    return SafePage(
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('Portfolio Builder'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: () => _showHelpDialog(context),
              tooltip: 'How to use this feature',
            ),
          ],
        ),
        body: authState.when(
          loading: () => const Center(child: GlowingIndicator(size: 32)),
          error: (err, _) => Center(child: Text('Please authenticate first: $err')),
          data: (authUser) {
            if (authUser == null) {
              return const Center(child: Text('Please authenticate first.'));
            }
            final repos = ref.watch(userReposProvider(authUser.login)).value;
            _initializeUserData(authUser, repos);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1. Select Curated Design Theme',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Showcase(
                    key: _themeKey,
                    title: 'Portfolio Themes',
                    description: 'Select a template style: retro command-line CLI, sleek modern dark, or glowing frosted glassmorphism.',
                    titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                    tooltipBackgroundColor: const Color(0xFF1E293B),
                    tooltipBorderRadius: BorderRadius.circular(12),
                    blurValue: 2,
                    child: Row(
                      children: [
                        _buildThemeCard(0, 'Sleek Dark', Icons.dark_mode_rounded),
                        const SizedBox(width: AppSpacing.sm),
                        _buildThemeCard(1, 'CLI Terminal', Icons.terminal_rounded),
                        const SizedBox(width: AppSpacing.sm),
                        _buildThemeCard(2, 'Glassmorphism', Icons.blur_on_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  const Text(
                    '2. Customize Portfolio Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Showcase(
                    key: _customizeKey,
                    title: 'Customize Info',
                    description: 'Enter your custom social handles, headline, profile bio, and skills list to dynamically construct your website content.',
                    titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                    tooltipBackgroundColor: const Color(0xFF1E293B),
                    tooltipBorderRadius: BorderRadius.circular(12),
                    blurValue: 2,
                    child: AppSurface(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                _buildSectionTab(0, 'Identity', Icons.person_outline_rounded),
                                _buildSectionTab(1, 'Tech Stack', Icons.bolt_rounded),
                                _buildSectionTab(2, 'Social Links', Icons.link_rounded),
                              ],
                            ),
                          ),
                          if (_customizeSectionIndex == 0) ...[
                            TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'Display Name', prefixIcon: Icon(Icons.person_rounded)),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _roleController,
                              decoration: const InputDecoration(labelText: 'Role / Bio Headline', prefixIcon: Icon(Icons.work_rounded)),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _locationController,
                              decoration: const InputDecoration(labelText: 'Location', prefixIcon: Icon(Icons.location_on_rounded)),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _emailController,
                              decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_rounded)),
                            ),
                          ] else if (_customizeSectionIndex == 1) ...[
                            TextField(
                              controller: _skillsController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Skills & Tech Stack (Comma separated)',
                                hintText: 'e.g. Flutter, Dart, Go, SQLite, Firebase, Python',
                                prefixIcon: Icon(Icons.bolt_rounded),
                                alignLabelWithHint: true,
                              ),
                            ),
                          ] else ...[
                            TextField(
                              controller: _websiteController,
                              decoration: const InputDecoration(labelText: 'Personal Website URL', prefixIcon: Icon(Icons.language_rounded)),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _linkedinController,
                              decoration: const InputDecoration(labelText: 'LinkedIn URL', prefixIcon: Icon(Icons.link_rounded)),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _twitterController,
                              decoration: const InputDecoration(labelText: 'Twitter/X URL', prefixIcon: Icon(Icons.alternate_email_rounded)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  const Text(
                    '3. Select Featured Projects',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppSurface(
                    padding: EdgeInsets.zero,
                    child: repos == null
                        ? const Padding(padding: EdgeInsets.all(20), child: Center(child: GlowingIndicator(size: 24)))
                        : Container(
                            constraints: const BoxConstraints(maxHeight: 250),
                            child: RawScrollbar(
                              controller: _repoListScrollController,
                              thumbVisibility: true,
                              thumbColor: AppColors.accent.withValues(alpha: 0.6),
                              radius: const Radius.circular(4),
                              thickness: 4,
                              child: ListView.separated(
                                controller: _repoListScrollController,
                                shrinkWrap: true,
                                itemCount: repos.length,
                                separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
                                itemBuilder: (context, index) {
                                  final repo = repos[index];
                                  final isSelected = _selectedRepoNames.contains(repo.fullName);
                                  return CheckboxListTile(
                                    dense: true,
                                    title: Text(repo.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Row(
                                      children: [
                                        if (repo.language != null) ...[
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: _getLanguageColor(repo.language),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(repo.language!, style: const TextStyle(fontSize: 11)),
                                          const SizedBox(width: 12),
                                        ],
                                        const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                                        const SizedBox(width: 2),
                                        Text('${repo.stargazersCount}', style: const TextStyle(fontSize: 11)),
                                      ],
                                    ),
                                    value: isSelected,
                                    activeColor: AppColors.accent,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          if (_selectedRepoNames.length < 6) {
                                            _selectedRepoNames.add(repo.fullName);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('You can showcase up to 6 repositories.')),
                                            );
                                          }
                                        } else {
                                          _selectedRepoNames.remove(repo.fullName);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  const Text(
                    '4. Publish / Deploy Options',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Showcase(
                    key: _deployKey,
                    title: 'One-Click Deployment',
                    description: 'Directly deploy your customized developer portfolio to GitHub Pages! Choose the target repository, and GitPulse will commit index.html to build your live site.',
                    titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                    tooltipBackgroundColor: const Color(0xFF1E293B),
                    tooltipBorderRadius: BorderRadius.circular(12),
                    blurValue: 2,
                    child: AppSurface(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showHtmlPreview(context, authUser, repos),
                                  icon: const Icon(Icons.visibility_rounded),
                                  label: const Text('Preview Design'),
                                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    final featured = repos?.where((r) => _selectedRepoNames.contains(r.fullName)).toList() ?? [];
                                    Clipboard.setData(ClipboardData(text: _generateHtmlCode(authUser, featured)));
                                    setState(() => _hasCopiedCode = true);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Portfolio template HTML copied to clipboard!')),
                                    );
                                  },
                                  icon: Icon(_hasCopiedCode ? Icons.check_circle_rounded : Icons.code_rounded,
                                      color: _hasCopiedCode ? Colors.green : null),
                                  label: Text(_hasCopiedCode ? 'HTML Copied!' : 'Copy Site HTML'),
                                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          DropdownButtonFormField<GhRepo>(
                            decoration: const InputDecoration(
                              labelText: 'Target Deployment Repository',
                              hintText: 'Select repository for index.html',
                            ),
                            value: _targetDeployRepo,
                            items: repos?.map((r) {
                              return DropdownMenuItem<GhRepo>(
                                value: r,
                                child: Text(r.name, style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _targetDeployRepo = val;
                              });
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton.icon(
                            onPressed: _isDeploying ? null : () => _deployReal(authUser.login),
                            icon: const Icon(Icons.cloud_upload_rounded),
                            label: const Text('Deploy to GitHub Pages'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              backgroundColor: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isDeploying) ...[
                    const SizedBox(height: AppSpacing.lg),
                    AppSurface(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          const GlowingIndicator(size: 24),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              _deployStep,
                              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_deployedUrl != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    AppSurface(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 36),
                          const SizedBox(height: 8),
                          const Text('Code Committed Successfully!', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          SelectableText(
                            _deployedUrl!,
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 13, decoration: TextDecoration.underline),
                          ),
                          const SizedBox(height: 12),
                          // Alert/Info Box
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'GitHub Pages takes 1-2 minutes to compile. If you open it immediately, you may see a temporary 404 or search redirect.',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    launchUrl(Uri.parse(_deployedUrl!.trim()), mode: LaunchMode.externalApplication);
                                  },
                                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                  label: const Text('View Live Site', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    if (_targetDeployRepo != null) {
                                      final owner = _targetDeployRepo!.owner.login;
                                      final repo = _targetDeployRepo!.name;
                                      launchUrl(
                                        Uri.parse('https://github.com/$owner/$repo/actions'),
                                        mode: LaunchMode.externalApplication,
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.analytics_outlined, size: 16),
                                  label: const Text('Track Build Progress', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),

                  const Text(
                    'README Profile Badge Generator',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Showcase(
                    key: _badgeKey,
                    title: 'README Developer Badges',
                    description: 'Generate dynamic markdown tags containing your stats for your profile README.md file.',
                    titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                    tooltipBackgroundColor: const Color(0xFF1E293B),
                    tooltipBorderRadius: BorderRadius.circular(12),
                    blurValue: 2,
                    child: AppSurface(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Embed Code (Markdown):', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _generateBadgeMarkdown(authUser.login),
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _generateBadgeMarkdown(authUser.login)));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Markdown badge link copied to clipboard!')),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('Copy Badge Markdown'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildThemeCard(int idx, String name, IconData icon) {
    final selected = _selectedTheme == idx;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    BoxDecoration themeDecor;
    Color iconColor;
    Color textColor;

    if (idx == 0) {
      // Sleek Dark
      themeDecor = BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: selected
            ? const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                    : [Colors.grey[100]!, Colors.grey[200]!],
              ),
      );
      iconColor = selected ? const Color(0xFF8B5CF6) : Colors.grey;
      textColor = selected 
          ? const Color(0xFF8B5CF6) 
          : (isDark ? Colors.white70 : Colors.black87);
    } else if (idx == 1) {
      // CLI Terminal
      themeDecor = BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: selected ? Colors.black : (isDark ? const Color(0xFF0F172A) : Colors.grey[200]),
      );
      iconColor = selected ? const Color(0xFF10B981) : Colors.grey;
      textColor = selected 
          ? const Color(0xFF10B981) 
          : (isDark ? Colors.white70 : Colors.black87);
    } else {
      // Glassmorphism
      themeDecor = BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: selected
            ? LinearGradient(
                colors: [
                  const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                  const Color(0xFF0EA5E9).withValues(alpha: 0.25)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: isDark
                    ? [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)]
                    : [Colors.black.withValues(alpha: 0.05), Colors.black.withValues(alpha: 0.02)],
              ),
      );
      iconColor = selected ? const Color(0xFF0EA5E9) : Colors.grey;
      textColor = selected 
          ? const Color(0xFF0EA5E9) 
          : (isDark ? Colors.white70 : Colors.black87);
    }

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTheme = idx;
          });
        },
        child: Container(
          height: 85,
          decoration: themeDecor.copyWith(
            border: Border.all(
              color: selected
                  ? iconColor
                  : (isDark ? Colors.white10 : Colors.black12),
              width: selected ? 2.0 : 1.0,
            ),
            boxShadow: selected ? [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.35),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ] : null,
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: textColor,
                  fontFamily: idx == 1 ? 'monospace' : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTab(int index, String label, IconData icon) {
    final selected = _customizeSectionIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _customizeSectionIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected 
                ? (isDark ? const Color(0xFF1E293B) : Colors.white) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected && !isDark ? [
              const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
            ] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? AppColors.accent : Colors.grey),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getLanguageColor(String? lang) {
    if (lang == null) return Colors.grey;
    switch (lang.toLowerCase()) {
      case 'dart': return Colors.blueAccent;
      case 'java': case 'kotlin': return Colors.orangeAccent;
      case 'javascript': case 'typescript': return Colors.yellowAccent;
      case 'python': return Colors.blue;
      case 'html': case 'css': return Colors.cyanAccent;
      case 'go': return Colors.tealAccent;
      case 'rust': return Colors.redAccent;
      case 'swift': return Colors.deepOrangeAccent;
      default: return Colors.blueGrey;
    }
  }
}

class _PortfolioVisualPreview extends StatelessWidget {
  const _PortfolioVisualPreview({
    required this.themeIndex,
    required this.username,
    required this.name,
    required this.bio,
    this.avatarUrl,
    required this.location,
    required this.repos,
    required this.skills,
    required this.website,
    required this.linkedin,
    required this.twitter,
    required this.email,
  });

  final int themeIndex;
  final String username;
  final String name;
  final String bio;
  final String? avatarUrl;
  final String location;
  final List<GhRepo> repos;
  final List<String> skills;
  final String website;
  final String linkedin;
  final String twitter;
  final String email;

  @override
  Widget build(BuildContext context) {
    final avatar = avatarUrl ?? 'https://github.com/identicons/$username.png';

    if (themeIndex == 1) {
      // -------------------------------------------------------------
      // 1. PREMIUM RETRO CLI TERMINAL DESIGN
      // -------------------------------------------------------------
      return Container(
        color: const Color(0xFF030303),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mock Terminal Top Status Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SYS_ADMIN@GITPULSE-VIRTUAL-OS:~',
                    style: TextStyle(color: Colors.white24, fontFamily: 'monospace', fontSize: 10),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'ONLINE',
                        style: TextStyle(color: Colors.white24, fontFamily: 'monospace', fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 16),
              
              // Terminal Welcome Message
              const Text(
                'Initializing secure SSL connection to GitPulse API... [OK]',
                style: TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 10),
              ),
              const Text(
                'Fetching live credentials and repository nodes... [OK]',
                style: TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 10),
              ),
              const SizedBox(height: 16),
              
              // Command 1: whoami
              const Text('\$ whoami', style: TextStyle(color: Color(0xFFFBBF24), fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              
              // Profile Layout
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Image.network(
                      avatar, 
                      width: 48, 
                      height: 48, 
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Color(0xFF10B981)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name, 
                          style: const TextStyle(
                            color: Color(0xFF10B981), 
                            fontWeight: FontWeight.bold, 
                            fontSize: 15, 
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bio, 
                          style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 11, fontFamily: 'monospace', height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              Text(
                'Location : $location\nIdentity : github.com/$username',
                style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace', height: 1.4),
              ),
              
              // Command 2: cat skills.txt
              if (skills.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('\$ cat skills.txt', style: TextStyle(color: Color(0xFFFBBF24), fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: skills.map((s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1),
                      borderRadius: BorderRadius.circular(4),
                      color: const Color(0xFF10B981).withValues(alpha: 0.05),
                    ),
                    child: Text(
                      s, 
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontFamily: 'monospace'),
                    ),
                  )).toList(),
                ),
              ],

              // Command 3: cat contact.txt
              if (email.isNotEmpty || website.isNotEmpty || linkedin.isNotEmpty || twitter.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('\$ cat contact.txt', style: TextStyle(color: Color(0xFFFBBF24), fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (email.isNotEmpty)
                        Text('📧 email : $email', style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 10, fontFamily: 'monospace', height: 1.5)),
                      if (website.isNotEmpty)
                        Text('🌐 site  : $website', style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 10, fontFamily: 'monospace', height: 1.5)),
                      if (linkedin.isNotEmpty)
                        Text('💼 linkedin : $linkedin', style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 10, fontFamily: 'monospace', height: 1.5)),
                      if (twitter.isNotEmpty)
                        Text('🐦 twitter : $twitter', style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 10, fontFamily: 'monospace', height: 1.5)),
                    ],
                  ),
                ),
              ],

              // Command 4: ls --show-projects
              const SizedBox(height: 24),
              const Text('\$ ls --projects', style: TextStyle(color: Color(0xFFFBBF24), fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),
              
              if (repos.isEmpty)
                const Text('total 0 items', style: TextStyle(color: Colors.white30, fontFamily: 'monospace', fontSize: 10))
              else
                ...repos.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(4),
                    color: const Color(0xFF10B981).withValues(alpha: 0.02),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('📁 ${r.name}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 12, color: Colors.amberAccent),
                              const SizedBox(width: 2),
                              Text('${r.stargazersCount}', style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontFamily: 'monospace')),
                            ],
                          ),
                        ],
                      ),
                      if (r.description != null && r.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          r.description!, 
                          style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 10, fontFamily: 'monospace', height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Language: ${r.language ?? "None"}', style: const TextStyle(color: Colors.white38, fontSize: 8, fontFamily: 'monospace')),
                          if (r.forksCount > 0)
                            Text('Forks: ${r.forksCount}', style: const TextStyle(color: Colors.white38, fontSize: 8, fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                )),
              
              // Blinking Command Input Mockup
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('\$ ', style: TextStyle(color: Color(0xFFFBBF24), fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 4),
                  const _BlinkingCursor(),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    } else if (themeIndex == 0) {
      // -------------------------------------------------------------
      // 2. ULTRA-PREMIUM MODERN SLEEK DARK DESIGN
      // -------------------------------------------------------------
      return Container(
        color: const Color(0xFF0F172A),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Verification Ribbon
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_rounded, color: Color(0xFF8B5CF6), size: 14),
                    SizedBox(width: 6),
                    Text(
                      'VERIFIED DEVELOPER PROFILE PORTFOLIO',
                      style: TextStyle(
                        color: Color(0xFFA78BFA),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Hero Panel
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF8B5CF6), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.network(
                        avatar,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name, 
                          style: const TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.w900, 
                            fontSize: 18,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bio, 
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Location / Metadata Pills
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMockBadge('📍 $location', const Color(0xFF1E293B)),
                  _buildMockBadge('🌐 github.com/$username', const Color(0xFF1E293B)),
                  if (email.isNotEmpty) _buildMockBadge('✉️ $email', const Color(0xFF1E293B)),
                ],
              ),
              
              // Technologies Tag List
              if (skills.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Expertise & Technologies', 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.2),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: skills.map((s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      s,
                      style: const TextStyle(color: Color(0xFFDDD6FE), fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  )).toList(),
                ),
              ],

              // Featured Repositories Section
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Featured Repositories', 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.2),
                  ),
                  Text(
                    '${repos.length} Pinned', 
                    style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              if (repos.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Center(
                    child: Text('No repositories selected as featured.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  ),
                )
              else
                ...repos.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              r.name, 
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                                const SizedBox(width: 2),
                                Text('${r.stargazersCount}', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (r.description != null && r.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          r.description!, 
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (r.language != null)
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getLanguageColor(r.language),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(r.language!, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            )
                          else
                            const SizedBox.shrink(),
                          if (r.forksCount > 0)
                            Text('🍴 ${r.forksCount} forks', style: const TextStyle(color: Colors.white30, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                )),
              
              // Social & Footer row
              if (linkedin.isNotEmpty || twitter.isNotEmpty || website.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (website.isNotEmpty)
                      _buildSocialLinkIcon(Icons.language_rounded, 'Site'),
                    if (linkedin.isNotEmpty)
                      _buildSocialLinkIcon(Icons.business_center_rounded, 'LinkedIn'),
                    if (twitter.isNotEmpty)
                      _buildSocialLinkIcon(Icons.alternate_email_rounded, 'Twitter'),
                  ],
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    } else {
      // -------------------------------------------------------------
      // 3. PREMIUM NEON-BLURRED GLASSMORPHISM DESIGN
      // -------------------------------------------------------------
      return Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF090514)],
            center: Alignment.center,
            radius: 1.2,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Glass Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30, width: 1.5),
                      ),
                      child: ClipOval(
                        child: Image.network(
                          avatar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFC084FC), Color(0xFF6366F1)],
                            ).createShader(bounds),
                            child: Text(
                              name, 
                              style: const TextStyle(
                                color: Colors.white, 
                                fontWeight: FontWeight.bold, 
                                fontSize: 16,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bio, 
                            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Location / Metadata Pills
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildGlassBadge('📍 $location'),
                  _buildGlassBadge('👥 github.com/$username'),
                ],
              ),

              // Glass Tech Stack
              if (skills.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Tech Stack', 
                  style: TextStyle(color: Color(0xFFE9D5FF), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: skills.map((s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      s, 
                      style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600),
                    ),
                  )).toList(),
                ),
              ],

              // Glass Pinned Projects
              const SizedBox(height: 24),
              const Text(
                'Featured Works', 
                style: TextStyle(color: Color(0xFFE9D5FF), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
              ),
              const SizedBox(height: 10),
              
              if (repos.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: const Center(
                    child: Text('No featured repositories selected.', style: TextStyle(color: Colors.white30, fontSize: 11)),
                  ),
                )
              else
                ...repos.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.02),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              r.name, 
                              style: const TextStyle(color: Color(0xFFE9D5FF), fontWeight: FontWeight.bold, fontSize: 12, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 12, color: Colors.amberAccent),
                              const SizedBox(width: 2),
                              Text('${r.stargazersCount}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                      if (r.description != null && r.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          r.description!, 
                          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            r.language ?? 'Text', 
                            style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w600),
                          ),
                          if (r.forksCount > 0)
                            Text('🍴 ${r.forksCount}', style: const TextStyle(color: Colors.white24, fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                )),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildMockBadge(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildGlassBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Text(label, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10)),
    );
  }

  Widget _buildSocialLinkIcon(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF8B5CF6)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _getLanguageColor(String? lang) {
    if (lang == null) return Colors.grey;
    switch (lang.toLowerCase()) {
      case 'dart': return Colors.blueAccent;
      case 'java': case 'kotlin': return Colors.orangeAccent;
      case 'javascript': case 'typescript': return Colors.yellowAccent;
      case 'python': return Colors.blue;
      case 'html': case 'css': return Colors.cyanAccent;
      case 'go': return Colors.tealAccent;
      case 'rust': return Colors.redAccent;
      case 'swift': return Colors.deepOrangeAccent;
      default: return Colors.blueGrey;
    }
  }
}

// -------------------------------------------------------------
// Interactive Blinking Cursor for Terminal Mock
// -------------------------------------------------------------
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 15,
        color: const Color(0xFF10B981),
      ),
    );
  }
}
