import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthDialog extends StatefulWidget {
  const AuthDialog({super.key});

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
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

      final data = response.data;
      setState(() {
        _userCode = data['user_code'];
        _verificationUri = data['verification_uri'];
        _deviceCode = data['device_code'];
        _interval = data['interval'] ?? 5;
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

        final data = response.data;
        if (data['access_token'] != null) {
          timer.cancel();
          final token = data['access_token'];
          
          // Save and apply token
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(ApiConstants.patStorageKey, token);
          DioClient.instance.applyPat(token);
          
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
                Icon(Icons.vpn_key_rounded, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  'Sign In with GitHub',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
              const Text(
                '1. Copy this code:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _userCode ?? '',
                      style: const TextStyle(
                        fontSize: 28,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _userCode ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '2. Click below to paste it and authorize GitPulse.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => launchUrl(Uri.parse(_verificationUri ?? 'https://github.com/login/device'), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_browser_rounded),
                label: const Text('Open GitHub.com'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Waiting for authorization...',
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
                ),
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
