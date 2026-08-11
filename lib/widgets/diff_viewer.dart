import 'package:flutter/material.dart';

class DiffViewer extends StatelessWidget {
  final String diff;

  const DiffViewer({super.key, required this.diff});

  @override
  Widget build(BuildContext context) {
    if (diff.isEmpty) {
      return const Center(
        child: Text('No diff available.', style: TextStyle(color: Colors.white38)),
      );
    }

    final lines = diff.split('\n');

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines.map((line) => _DiffLine(line: line)).toList(),
        ),
      ),
    );
  }
}

class _DiffLine extends StatelessWidget {
  final String line;

  const _DiffLine({required this.line});

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    Color textColor;
    Color borderColor;
    String displayLine = line;

    if (line.startsWith('diff --git') ||
        line.startsWith('index ') ||
        line.startsWith('new file') ||
        line.startsWith('deleted file')) {
      // File header
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B4B),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          line,
          style: const TextStyle(
            color: Color(0xFFA5B4FC),
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (line.startsWith('--- ') || line.startsWith('+++ ')) {
      // File path lines
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        child: Text(
          line,
          style: const TextStyle(
            color: Color(0xFF818CF8),
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),
      );
    } else if (line.startsWith('@@')) {
      // Hunk header
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        color: const Color(0xFF0C2D4A),
        child: Text(
          line,
          style: const TextStyle(
            color: Color(0xFF38BDF8),
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),
      );
    } else if (line.startsWith('+')) {
      bgColor = Colors.green.withValues(alpha: 0.1);
      textColor = Colors.greenAccent.shade100;
      borderColor = Colors.green;
    } else if (line.startsWith('-')) {
      bgColor = Colors.red.withValues(alpha: 0.08);
      textColor = Colors.red.shade200;
      borderColor = Colors.red;
    } else {
      bgColor = Colors.transparent;
      textColor = Colors.white60;
      borderColor = Colors.transparent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(left: BorderSide(color: borderColor, width: 3)),
      ),
      child: Text(
        displayLine,
        style: TextStyle(
          color: textColor,
          fontFamily: 'monospace',
          fontSize: 11,
          height: 1.5,
        ),
      ),
    );
  }
}
