import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_spacing.dart';

class PremiumCodeViewer extends StatelessWidget {
  const PremiumCodeViewer({
    super.key,
    required this.code,
    this.language,
    this.showLineNumbers = true,
    this.highlightLineNumber,
  });

  final String code;
  final String? language;
  final bool showLineNumbers;
  final int? highlightLineNumber;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lines = code.split(RegExp(r'\r\n|\n|\r'));

    final bgCol = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
    final lineNumberColor = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);

    final lineWidgets = <Widget>[];
    final codeLineWidgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final lineNum = i + 1;
      final isHighlighted = highlightLineNumber != null && lineNum == highlightLineNumber;
      final lineBg = isHighlighted 
          ? (isDark ? Colors.yellow.withValues(alpha: 0.15) : Colors.yellow.withValues(alpha: 0.25))
          : Colors.transparent;
      
      if (showLineNumbers) {
        lineWidgets.add(
          Container(
            height: 20, // Fixed height per line for perfect vertical alignment
            padding: const EdgeInsets.only(left: 14, right: 12),
            alignment: Alignment.centerRight,
            color: lineBg,
            child: Text(
              '$lineNum',
              style: GoogleFonts.spaceMono(
                fontSize: 12,
                color: isHighlighted 
                    ? (isDark ? Colors.yellowAccent : Colors.amber.shade900) 
                    : lineNumberColor,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                height: 1.0,
              ),
            ),
          ),
        );
      }

      codeLineWidgets.add(
        Container(
          height: 20, // Match the fixed height of line numbers
          alignment: Alignment.centerLeft,
          color: lineBg,
          child: RichText(
            text: _highlightLine(lines[i], isDark),
            textScaler: TextScaler.noScaling,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: borderCol, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      language != null && language!.isNotEmpty
                          ? language!.toUpperCase()
                          : 'SOURCE CODE',
                      style: GoogleFonts.spaceMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white60 : Colors.black54,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Copy Code',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Code View Area
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pinned Line Numbers Column (Does not scroll horizontally)
                if (showLineNumbers) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: lineWidgets,
                  ),
                  Container(
                    width: 1.5,
                    height: lines.length * 20.0, // Match exact container heights
                    color: borderCol,
                  ),
                  const SizedBox(width: 12),
                ],

                // Scrollable Code Text Column (Scrolls horizontally)
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    child: SelectionArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: codeLineWidgets,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _highlightLine(String line, bool isDark) {
    final spans = <TextSpan>[];

    // Colors matching theme
    final keywordColor = isDark ? const Color(0xFFF43F5E) : const Color(0xFFBE123C); // Vibrant red/pink
    final typeColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1); // Sky blue
    final stringColor = isDark ? const Color(0xFF34D399) : const Color(0xFF047857); // Mint green
    final commentColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8); // Slate grey
    final numberColor = isDark ? const Color(0xFFF59E0B) : const Color(0xFFB45309); // Orange/Amber
    final defaultColor = isDark ? Colors.white70 : Colors.black87;

    // Pattern matching RegExp for a single line
    final exp = RegExp(
      r'(//.*|#.*)|' // Group 1: Comments (single line only)
      r'("([^"\\]|\\.)*"|' + r"'([^'\\]|\\.)*')|" // Group 2: Strings
      r'\b(class|struct|import|export|void|int|double|var|final|const|return|if|else|for|while|switch|case|default|break|continue|try|catch|finally|throw|new|this|super|extends|implements|with|mixin|factory|get|set|async|await|yield|function|def|fn|let|static|public|private|protected)\b|' // Group 3: Keywords
      r'\b(String|Widget|BuildContext|List|Map|Set|DateTime|Future|Stream|dynamic|bool|num|Object|int|double|var|dynamic)\b|' // Group 4: Classes/Types
      r'\b(\d+)\b', // Group 5: Numbers
    );

    int lastMatchEnd = 0;
    final matches = exp.allMatches(line);

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: line.substring(lastMatchEnd, match.start),
          style: GoogleFonts.spaceMono(color: defaultColor, fontSize: 12, height: 1.0),
        ));
      }

      if (match.group(1) != null) {
        // Comment
        spans.add(TextSpan(
          text: match.group(0),
          style: GoogleFonts.spaceMono(color: commentColor, fontStyle: FontStyle.italic, fontSize: 12, height: 1.0),
        ));
      } else if (match.group(2) != null) {
        // String
        spans.add(TextSpan(
          text: match.group(0),
          style: GoogleFonts.spaceMono(color: stringColor, fontSize: 12, height: 1.0),
        ));
      } else if (match.group(3) != null) {
        // Keyword
        spans.add(TextSpan(
          text: match.group(0),
          style: GoogleFonts.spaceMono(color: keywordColor, fontWeight: FontWeight.bold, fontSize: 12, height: 1.0),
        ));
      } else if (match.group(4) != null) {
        // Type / Class name
        spans.add(TextSpan(
          text: match.group(0),
          style: GoogleFonts.spaceMono(color: typeColor, fontWeight: FontWeight.w600, fontSize: 12, height: 1.0),
        ));
      } else if (match.group(5) != null) {
        // Number
        spans.add(TextSpan(
          text: match.group(0),
          style: GoogleFonts.spaceMono(color: numberColor, fontSize: 12, height: 1.0),
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < line.length) {
      spans.add(TextSpan(
        text: line.substring(lastMatchEnd),
        style: GoogleFonts.spaceMono(color: defaultColor, fontSize: 12, height: 1.0),
      ));
    }

    return TextSpan(children: spans);
  }
}
