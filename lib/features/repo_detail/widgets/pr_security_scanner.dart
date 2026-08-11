import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_surface.dart';

class SecurityFinding {
  final String title;
  final String description;
  final String severity; // High, Medium, Low
  final String snippet;

  const SecurityFinding({
    required this.title,
    required this.description,
    required this.severity,
    required this.snippet,
  });
}

class PrSecurityScanner extends StatelessWidget {
  const PrSecurityScanner({super.key, required this.codeOrDiff});

  final String codeOrDiff;

  List<SecurityFinding> _scanForSecurityIssues() {
    final findings = <SecurityFinding>[];
    if (codeOrDiff.trim().isEmpty) return findings;

    // Pattern 1: Private Key Detection
    if (RegExp(r'-----BEGIN (RSA|OPENSSH|EC|PGP)? PRIVATE KEY-----').hasMatch(codeOrDiff)) {
      findings.add(const SecurityFinding(
        title: 'Hardcoded Private Key Found',
        description: 'Plaintext private RSA/SSH key detected in code diff. Keys must be stored in secure secrets managers.',
        severity: 'High',
        snippet: '-----BEGIN PRIVATE KEY-----',
      ));
    }

    // Pattern 2: AWS / Cloud Secret Keys
    if (RegExp(r'AKIA[0-9A-Z]{16}').hasMatch(codeOrDiff)) {
      findings.add(const SecurityFinding(
        title: 'AWS Access Key ID Detected',
        description: 'Hardcoded AWS Key ID found. Exposed cloud credentials lead to unauthorized resource billing.',
        severity: 'High',
        snippet: 'AKIA...',
      ));
    }

    // Pattern 3: GitHub Personal Access Tokens
    if (RegExp(r'ghp_[a-zA-Z0-9]{36}').hasMatch(codeOrDiff)) {
      findings.add(const SecurityFinding(
        title: 'GitHub Personal Access Token (PAT)',
        description: 'Hardcoded GitHub Personal Access Token detected in patch.',
        severity: 'High',
        snippet: 'ghp_...',
      ));
    }

    // Pattern 4: Generic High Entropy API Secret Token
    if (RegExp(r'(api_key|secret_key|auth_token|bearer)\s*=\s*[a-zA-Z0-9_-]{20,}', caseSensitive: false).hasMatch(codeOrDiff)) {
      findings.add(const SecurityFinding(
        title: 'Hardcoded API Secret Key Variable',
        description: 'Variable assignment contains what appears to be a secret key token.',
        severity: 'Medium',
        snippet: 'secret_key = "..."',
      ));
    }

    // Pattern 5: Insecure HTTP URLs
    if (RegExp(r'http://(?!localhost|127\.0\.0\.1)').hasMatch(codeOrDiff)) {
      findings.add(const SecurityFinding(
        title: 'Insecure Unencrypted HTTP Connection',
        description: 'Code references plain HTTP endpoints without TLS encryption.',
        severity: 'Low',
        snippet: 'http://...',
      ));
    }

    return findings;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final findings = _scanForSecurityIssues();

    if (findings.isEmpty) {
      return AppSurface(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.green,
              radius: 16,
              child: Icon(Icons.shield_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PR Security Check Passed',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No hardcoded keys, secrets, or high-risk vulnerability anti-patterns detected in diff.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      accentColor: AppColors.danger,
      showAccentStripe: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
              const SizedBox(width: 8),
              Text(
                'Security Leak Scan Alert (${findings.length} Flagged)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...findings.map((f) {
            Color severityColor = AppColors.danger;
            if (f.severity == 'Medium') severityColor = Colors.orange;
            if (f.severity == 'Low') severityColor = Colors.amber;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: severityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: severityColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(f.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: severityColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          f.severity.toUpperCase(),
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(f.description, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
