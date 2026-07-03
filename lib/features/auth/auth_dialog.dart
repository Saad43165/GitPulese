import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_providers.dart';

class AuthDialog extends ConsumerStatefulWidget {
  const AuthDialog({super.key});

  @override
  ConsumerState<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends ConsumerState<AuthDialog> {
  final Dio _dio = Dio();
  
  // NOTE: This must be replaced with the user's real GitHub OAuth App Client ID
  final String _clientId = 'Ov23liSRrNr1PE6Kbd1F';
  
  bool _loading = true;
  String? _userCode;
  String? _verificationUri;
  String? _deviceCode;
  String? _error;
  Timer? _pollTimer;
  int _interval = 5;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _startDeviceFlow();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startDeviceFlow() async {
    try {
      final response = await _dio.post(
        'https://github.com/login/device/code',
        data: {
          'client_id': _clientId,
          'scope': 'repo user',
        },
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      var data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          data = Uri.splitQueryString(data);
        }
      }

      setState(() {
        _userCode = data['user_code'];
        _verificationUri = data['verification_uri'];
        _deviceCode = data['device_code'];
        _interval = int.tryParse(data['interval']?.toString() ?? '') ?? 5;
        _loading = false;
      });

      _pollForToken();
    } catch (e) {
      setState(() {
        _error = 'Failed to start login. Make sure Client ID is configured.';
        _loading = false;
      });
    }
  }

  void _pollForToken() {
    _pollTimer = Timer.periodic(Duration(seconds: _interval), (timer) async {
      if (_deviceCode == null) return;
      
      try {
        final response = await _dio.post(
          'https://github.com/login/oauth/access_token',
          data: {
            'client_id': _clientId,
            'device_code': _deviceCode,
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          },
          options: Options(
            headers: {'Accept': 'application/json'},
          ),
        );

        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (_) {
            data = Uri.splitQueryString(data);
          }
        }

        if (data['access_token'] != null) {
          timer.cancel();
          final token = data['access_token'];
          
          // Save and apply token
          await ref.read(githubPatProvider.notifier).save(token);
          
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        } else if (data['error'] == 'authorization_pending') {
          // Keep waiting
        } else if (data['error'] == 'slow_down') {
          _interval += 5;
          timer.cancel();
          _pollForToken(); // restart with longer interval
        } else {
          timer.cancel();
          setState(() {
            _error = 'Login failed: ${data['error_description'] ?? data['error']}';
          });
        }
      } catch (e) {
        // Ignore network errors while polling
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/github.png',
                  width: 24,
                  height: 24,
                  color: isDark ? Colors.white : Colors.black,
                ),
                const SizedBox(width: 12),
                Text(
                  'Connect with GitHub',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.danger))
            else ...[
              Text(
                '1. Copy this verification code',
                style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _userCode ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: (_copied ? AppColors.success : AppColors.accent).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded, 
                          size: 22, 
                          color: _copied ? AppColors.success : AppColors.accent
                        ),
                        tooltip: 'Copy Code',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _userCode ?? ''));
                          setState(() => _copied = true);
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) setState(() => _copied = false);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied to clipboard!')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '2. Paste it on GitHub to authorize',
                style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => launchUrl(Uri.parse(_verificationUri ?? 'https://github.com/login/device'), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_browser_rounded),
                label: const Text('Open GitHub Settings'),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Waiting for authorization...',
                    style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
