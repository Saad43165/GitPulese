import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../features/repo_detail/ai_pr_review_screen.dart';
import '../features/devops/devops_workflows_screen.dart';
import '../features/editor/ai_code_editor_screen.dart';
import '../features/vault/offline_codebase_vault_screen.dart';
import '../features/compare/compare_screen.dart';
import '../core/theme/app_theme.dart';

class PremiumConsoleSheet extends StatelessWidget {
  const PremiumConsoleSheet({super.key});

  static void show(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const PremiumConsoleSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final tools = [
      _ConsoleTool(
        title: 'AI PR Reviewer',
        icon: Icons.rate_review_rounded,
        color: const Color(0xFF6366F1), // Indigo
        description: 'Audit PR links for code quality and bugs',
        screen: const AiPrReviewScreen(),
      ),
      _ConsoleTool(
        title: 'DevOps Center',
        icon: Icons.rocket_launch_rounded,
        color: const Color(0xFF0EA5E9), // Light Blue
        description: 'Monitor workflows, jobs, and action logs',
        screen: const DevOpsWorkflowsScreen(),
      ),
      _ConsoleTool(
        title: 'AI Code Editor',
        icon: Icons.code_rounded,
        color: const Color(0xFF10B981), // Emerald
        description: 'AI code audits, refactoring, and git patches',
        screen: const AiCodeEditorScreen(),
      ),
      _ConsoleTool(
        title: 'Offline Vault',
        icon: Icons.folder_zip_rounded,
        color: const Color(0xFFF59E0B), // Amber
        description: 'Explore offline zipped codebases & local files',
        screen: const OfflineCodebaseVaultScreen(),
      ),
      _ConsoleTool(
        title: 'Repo Arena',
        icon: Icons.compare_rounded,
        color: const Color(0xFFEF4444), // Red
        description: 'Side-by-side repository comparison & analytics',
        screen: const CompareScreen(),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F141C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Developer Suite Console',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // List layout
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tools.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tool = tools[index];
              return _buildToolTile(context, tool, isDark);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolTile(BuildContext context, _ConsoleTool tool, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context); // Close sheet first
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => tool.screen),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark 
              ? Colors.white.withValues(alpha: 0.02) 
              : Colors.black.withValues(alpha: 0.01),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tool.icon, color: tool.color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tool.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tool.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsoleTool {
  final String title;
  final IconData icon;
  final Color color;
  final String description;
  final Widget screen;

  const _ConsoleTool({
    required this.title,
    required this.icon,
    required this.color,
    required this.description,
    required this.screen,
  });
}
