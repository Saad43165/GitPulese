import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

enum CodeTheme {
  slate,
  monokai,
  githubDark,
  githubLight,
}

class PremiumCodeViewer extends StatefulWidget {
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
  State<PremiumCodeViewer> createState() => _PremiumCodeViewerState();
}

class _PremiumCodeViewerState extends State<PremiumCodeViewer> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _verticalScrollController = ScrollController();

  bool _isSearchOpen = false;
  String _searchQuery = '';
  int _currentMatchIndex = 0;
  List<int> _matchingLineIndices = [];

  double _fontSize = 12.0;
  late bool _showLineNumbers;
  CodeTheme _selectedTheme = CodeTheme.slate;

  @override
  void initState() {
    super.initState();
    _showLineNumbers = widget.showLineNumbers;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant PremiumCodeViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _updateMatches();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _updateMatches();
    });
  }

  void _updateMatches() {
    _matchingLineIndices.clear();
    if (_searchQuery.trim().isEmpty) {
      _currentMatchIndex = 0;
      return;
    }

    final queryLower = _searchQuery.toLowerCase();
    final lines = widget.code.split(RegExp(r'\r\n|\n|\r'));

    for (int i = 0; i < lines.length; i++) {
      if (lines[i].toLowerCase().contains(queryLower)) {
        _matchingLineIndices.add(i);
      }
    }

    if (_matchingLineIndices.isNotEmpty) {
      if (_currentMatchIndex >= _matchingLineIndices.length) {
        _currentMatchIndex = 0;
      }
      _scrollToLine(_matchingLineIndices[_currentMatchIndex]);
    } else {
      _currentMatchIndex = 0;
    }
  }

  void _nextMatch() {
    if (_matchingLineIndices.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matchingLineIndices.length;
      _scrollToLine(_matchingLineIndices[_currentMatchIndex]);
    });
  }

  void _previousMatch() {
    if (_matchingLineIndices.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _matchingLineIndices.length) % _matchingLineIndices.length;
      _scrollToLine(_matchingLineIndices[_currentMatchIndex]);
    });
  }

  void _scrollToLine(int lineIndex) {
    if (!_verticalScrollController.hasClients) return;
    final targetOffset = (lineIndex * (_fontSize * 1.6)).clamp(
      0.0,
      _verticalScrollController.position.maxScrollExtent,
    );
    _verticalScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  ThemeColors _getThemeColors(bool isDark) {
    switch (_selectedTheme) {
      case CodeTheme.monokai:
        return const ThemeColors(
          bg: Color(0xFF272822),
          headerBg: Color(0xFF1E1E1C),
          border: Color(0xFF3E3D32),
          lineNumber: Color(0xFF75715E),
          keyword: Color(0xFFF92672),
          type: Color(0xFF66D9EF),
          string: Color(0xFFE6DB74),
          comment: Color(0xFF75715E),
          number: Color(0xFFAE81FF),
          text: Color(0xFFF8F8F2),
        );
      case CodeTheme.githubDark:
        return const ThemeColors(
          bg: Color(0xFF0D1117),
          headerBg: Color(0xFF161B22),
          border: Color(0xFF30363D),
          lineNumber: Color(0xFF8B949E),
          keyword: Color(0xFFFF7B72),
          type: Color(0xFF79C0FF),
          string: Color(0xFFA5D6FF),
          comment: Color(0xFF8B949E),
          number: Color(0xFFD2A8FF),
          text: Color(0xFFC9D1D9),
        );
      case CodeTheme.githubLight:
        return const ThemeColors(
          bg: Color(0xFFFFFFFF),
          headerBg: Color(0xFFF6F8FA),
          border: Color(0xFFD0D7DE),
          lineNumber: Color(0xFF57606A),
          keyword: Color(0xFFCF222E),
          type: Color(0xFF0550AE),
          string: Color(0xFF0A3069),
          comment: Color(0xFF6E7781),
          number: Color(0xFF0550AE),
          text: Color(0xFF24292F),
        );
      case CodeTheme.slate:
        return isDark
            ? const ThemeColors(
                bg: Color(0xFF0F172A),
                headerBg: Color(0xFF1E293B),
                border: Color(0x1AFFFFFF),
                lineNumber: Color(0xFF475569),
                keyword: Color(0xFFF43F5E),
                type: Color(0xFF38BDF8),
                string: Color(0xFF34D399),
                comment: Color(0xFF64748B),
                number: Color(0xFFF59E0B),
                text: Color(0xB3FFFFFF),
              )
            : const ThemeColors(
                bg: Color(0xFFF8FAFC),
                headerBg: Color(0xFFF1F5F9),
                border: Color(0x1A000000),
                lineNumber: Color(0xFF94A3B8),
                keyword: Color(0xFFBE123C),
                type: Color(0xFF0369A1),
                string: Color(0xFF047857),
                comment: Color(0xFF94A3B8),
                number: Color(0xFFB45309),
                text: Color(0xDE000000),
              );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColors = _getThemeColors(isDark);
    final lines = widget.code.split(RegExp(r'\r\n|\n|\r'));

    final activeMatchLineIndex = (_matchingLineIndices.isNotEmpty && _currentMatchIndex < _matchingLineIndices.length)
        ? _matchingLineIndices[_currentMatchIndex]
        : -1;

    final lineWidgets = <Widget>[];
    final codeLineWidgets = <Widget>[];
    final lineMinHeight = _fontSize * 1.6;

    for (int i = 0; i < lines.length; i++) {
      final lineNum = i + 1;
      final isHighlighted = widget.highlightLineNumber != null && lineNum == widget.highlightLineNumber;
      final isSearchMatchLine = _matchingLineIndices.contains(i);
      final isActiveMatchLine = i == activeMatchLineIndex;

      Color lineBg = Colors.transparent;
      if (isActiveMatchLine) {
        lineBg = Colors.orange.withValues(alpha: 0.35);
      } else if (isSearchMatchLine) {
        lineBg = Colors.yellow.withValues(alpha: 0.2);
      } else if (isHighlighted) {
        lineBg = isDark ? Colors.yellow.withValues(alpha: 0.15) : Colors.yellow.withValues(alpha: 0.25);
      }

      if (_showLineNumbers) {
        lineWidgets.add(
          Container(
            height: lineMinHeight,
            padding: const EdgeInsets.only(left: 14, right: 12),
            alignment: Alignment.centerRight,
            color: lineBg,
            child: Text(
              '$lineNum',
              style: GoogleFonts.spaceMono(
                fontSize: _fontSize,
                color: isHighlighted || isActiveMatchLine
                    ? (isDark ? Colors.yellowAccent : Colors.amber.shade900)
                    : themeColors.lineNumber,
                fontWeight: isHighlighted || isActiveMatchLine ? FontWeight.bold : FontWeight.normal,
                height: 1.0,
              ),
            ),
          ),
        );
      }

      codeLineWidgets.add(
        Container(
          height: lineMinHeight,
          alignment: Alignment.centerLeft,
          color: lineBg,
          child: RichText(
            text: _highlightLine(lines[i], themeColors),
            textScaler: TextScaler.noScaling,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: themeColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: themeColors.headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: themeColors.border, width: 1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Text(
                          widget.language != null && widget.language!.isNotEmpty
                              ? widget.language!.toUpperCase()
                              : 'SOURCE CODE',
                          style: GoogleFonts.spaceMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: themeColors.text.withValues(alpha: 0.7),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Search Button
                        IconButton(
                          icon: Icon(
                            _isSearchOpen ? Icons.search_off_rounded : Icons.search_rounded,
                            size: 18,
                            color: _isSearchOpen ? Colors.amber : themeColors.text,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          tooltip: 'Find in Code',
                          onPressed: () {
                            setState(() {
                              _isSearchOpen = !_isSearchOpen;
                              if (!_isSearchOpen) {
                                _searchController.clear();
                                _searchQuery = '';
                                _matchingLineIndices.clear();
                              } else {
                                _searchFocusNode.requestFocus();
                              }
                            });
                          },
                        ),
                        // Theme Selector Popup Menu
                        PopupMenuButton<CodeTheme>(
                          icon: Icon(Icons.palette_outlined, size: 18, color: themeColors.text),
                          tooltip: 'Syntax Theme',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onSelected: (theme) => setState(() => _selectedTheme = theme),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: CodeTheme.slate, child: Text('Slate Dark (Default)')),
                            const PopupMenuItem(value: CodeTheme.monokai, child: Text('Monokai')),
                            const PopupMenuItem(value: CodeTheme.githubDark, child: Text('GitHub Dark')),
                            const PopupMenuItem(value: CodeTheme.githubLight, child: Text('GitHub Light')),
                          ],
                        ),
                        // Font size adjuster
                        PopupMenuButton<double>(
                          icon: Icon(Icons.format_size_rounded, size: 18, color: themeColors.text),
                          tooltip: 'Font Size',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onSelected: (size) => setState(() => _fontSize = size),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 10.0, child: Text('Small (10px)')),
                            const PopupMenuItem(value: 12.0, child: Text('Medium (12px)')),
                            const PopupMenuItem(value: 14.0, child: Text('Large (14px)')),
                            const PopupMenuItem(value: 16.0, child: Text('Extra Large (16px)')),
                          ],
                        ),
                        // Copy Button
                        IconButton(
                          icon: Icon(Icons.copy_rounded, size: 18, color: themeColors.text),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          tooltip: 'Copy Code',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: widget.code));
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
                  ],
                ),

                // In-File Search Bar Overlay
                if (_isSearchOpen) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: themeColors.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: themeColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            style: GoogleFonts.spaceMono(fontSize: 12, color: themeColors.text),
                            decoration: const InputDecoration(
                              hintText: 'Search in file...',
                              hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_matchingLineIndices.isNotEmpty) ...[
                          Text(
                            '${_currentMatchIndex + 1}/${_matchingLineIndices.length}',
                            style: GoogleFonts.spaceMono(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28),
                            onPressed: _previousMatch,
                          ),
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28),
                            onPressed: _nextMatch,
                          ),
                        ] else if (_searchQuery.isNotEmpty) ...[
                          const Text('No matches', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Code View Area
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pinned Line Numbers Column
                if (_showLineNumbers) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: lineWidgets,
                  ),
                  Container(
                    width: 1.5,
                    height: lines.length * lineMinHeight,
                    color: themeColors.border,
                  ),
                  const SizedBox(width: 12),
                ],

                // Scrollable Code Text Column
                Expanded(
                  child: SingleChildScrollView(
                    controller: _verticalScrollController,
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _highlightLine(String line, ThemeColors colors) {
    if (_searchQuery.trim().isNotEmpty && line.toLowerCase().contains(_searchQuery.toLowerCase())) {
      final spans = <TextSpan>[];
      final queryLower = _searchQuery.toLowerCase();
      final lineLower = line.toLowerCase();

      int start = 0;
      int matchIndex = lineLower.indexOf(queryLower, start);

      while (matchIndex != -1) {
        if (matchIndex > start) {
          spans.add(_buildSyntaxSpan(line.substring(start, matchIndex), colors));
        }

        final matchText = line.substring(matchIndex, matchIndex + _searchQuery.length);
        spans.add(TextSpan(
          text: matchText,
          style: GoogleFonts.spaceMono(
            color: Colors.black,
            backgroundColor: Colors.amberAccent,
            fontWeight: FontWeight.bold,
            fontSize: _fontSize,
            height: 1.0,
          ),
        ));

        start = matchIndex + _searchQuery.length;
        matchIndex = lineLower.indexOf(queryLower, start);
      }

      if (start < line.length) {
        spans.add(_buildSyntaxSpan(line.substring(start), colors));
      }

      return TextSpan(children: spans);
    }

    return _buildSyntaxSpan(line, colors);
  }

  TextSpan _buildSyntaxSpan(String text, ThemeColors colors) {
    final spans = <TextSpan>[];

    final exp = RegExp(
      r'(//.*|#.*)|'
      r'("([^"\\]|\\.)*"|' + r"'([^'\\]|\\.)*')|"
      r'\b(class|struct|import|export|void|int|double|var|final|const|return|if|else|for|while|switch|case|default|break|continue|try|catch|finally|throw|new|this|super|extends|implements|with|mixin|factory|get|set|async|await|yield|function|def|fn|let|static|public|private|protected)\b|'
      r'\b(String|Widget|BuildContext|List|Map|Set|DateTime|Future|Stream|dynamic|bool|num|Object)\b|'
      r'\b(\d+)\b',
    );

    int lastMatchEnd = 0;
    final matches = exp.allMatches(text);

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: GoogleFonts.spaceMono(color: colors.text, fontSize: _fontSize, height: 1.0),
        ));
      }

      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(0),
          style: GoogleFonts.spaceMono(color: colors.comment, fontStyle: FontStyle.italic, fontSize: _fontSize, height: 1.0),
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(0),
          style: GoogleFonts.spaceMono(color: colors.string, fontSize: _fontSize, height: 1.0),
        ));
      } else if (match.group(3) != null) {
        spans.add(TextSpan(
          text: match.group(0),
          style: GoogleFonts.spaceMono(color: colors.keyword, fontWeight: FontWeight.bold, fontSize: _fontSize, height: 1.0),
        ));
      } else if (match.group(4) != null) {
        spans.add(TextSpan(
          text: match.group(0),
          style: GoogleFonts.spaceMono(color: colors.type, fontWeight: FontWeight.w600, fontSize: _fontSize, height: 1.0),
        ));
      } else if (match.group(5) != null) {
        spans.add(TextSpan(
          text: match.group(0),
          style: GoogleFonts.spaceMono(color: colors.number, fontSize: _fontSize, height: 1.0),
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: GoogleFonts.spaceMono(color: colors.text, fontSize: _fontSize, height: 1.0),
      ));
    }

    return TextSpan(children: spans);
  }
}

class ThemeColors {
  const ThemeColors({
    required this.bg,
    required this.headerBg,
    required this.border,
    required this.lineNumber,
    required this.keyword,
    required this.type,
    required this.string,
    required this.comment,
    required this.number,
    required this.text,
  });

  final Color bg;
  final Color headerBg;
  final Color border;
  final Color lineNumber;
  final Color keyword;
  final Color type;
  final Color string;
  final Color comment;
  final Color number;
  final Color text;
}
