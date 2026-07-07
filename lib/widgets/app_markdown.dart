import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_spacing.dart';

class AppMarkdown extends StatelessWidget {
  const AppMarkdown({
    super.key,
    required this.data,
    this.selectable = true,
    this.shrinkWrap = true,
    this.physics,
  });

  final String data;
  final bool selectable;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textColor = isDark ? Colors.white70 : Colors.black87;
    final headerColor = isDark ? Colors.white : Colors.black87;
    final codeBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final codeTextColor = isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777); // Soft pink for inline code
    final blockBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderLight = isDark ? Colors.white10 : Colors.black12;

    final styleSheet = MarkdownStyleSheet(
      h1: GoogleFonts.outfit(
        color: headerColor,
        fontWeight: FontWeight.w800,
        fontSize: 22,
        height: 1.3,
      ),
      h2: GoogleFonts.outfit(
        color: headerColor,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        height: 1.3,
      ),
      h3: GoogleFonts.outfit(
        color: headerColor,
        fontWeight: FontWeight.w700,
        fontSize: 16,
        height: 1.3,
      ),
      h4: GoogleFonts.outfit(
        color: headerColor,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        height: 1.3,
      ),
      p: GoogleFonts.outfit(
        color: textColor,
        fontSize: 14,
        height: 1.6,
      ),
      a: GoogleFonts.outfit(
        color: isDark ? AppColors.accentSoft : AppColors.accent,
        decoration: TextDecoration.underline,
        fontWeight: FontWeight.w600,
      ),
      listBullet: GoogleFonts.outfit(
        color: AppColors.accent,
        fontWeight: FontWeight.bold,
      ),
      code: GoogleFonts.spaceMono(
        backgroundColor: Colors.transparent, // Overriden by inlineCode decoration pattern if custom builder exists, else standard background
        color: codeTextColor,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      codeblockDecoration: BoxDecoration(
        color: blockBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderLight, width: 1),
      ),
      blockquote: GoogleFonts.outfit(
        color: isDark ? Colors.white60 : Colors.black54,
        fontSize: 13.5,
        fontStyle: FontStyle.italic,
        height: 1.5,
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      blockquoteDecoration: BoxDecoration(
        color: isDark ? const Color(0xFF181524) : const Color(0xFFF1F5F9), // Subtle tint of background color
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
        border: Border(
          left: BorderSide(
            color: AppColors.accent,
            width: 4,
          ),
        ),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: borderLight,
            width: 1.5,
          ),
        ),
      ),
      tableBorder: TableBorder.all(
        color: borderLight,
        width: 1,
        borderRadius: BorderRadius.circular(8),
      ),
      tableBody: GoogleFonts.outfit(
        color: textColor,
        fontSize: 13,
      ),
      tableHead: GoogleFonts.outfit(
        color: headerColor,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    );

    // Render markdown body wrapper
    final markdown = MarkdownBody(
      data: data,
      selectable: false, // Disable built-in selectable to prevent gesture hijacking
      shrinkWrap: shrinkWrap,
      fitContent: true,
      styleSheet: styleSheet,
      onTapLink: (text, href, title) {
        if (href != null) {
          launchUrl(
            Uri.parse(href),
            mode: LaunchMode.externalApplication,
          );
        }
      },
    );

    if (selectable) {
      return SelectionArea(child: markdown);
    }
    return markdown;
  }
}
