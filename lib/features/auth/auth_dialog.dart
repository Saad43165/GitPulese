import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_providers.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../../widgets/glowing_indicator.dart';

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

  // Manual PAT input fallback state
  bool _showManual = true;
  bool _validatingManual = false;
  final _manualController = TextEditingController();
  bool _obscureManual = true;
  String? _manualError;

  @override
  void initState() {
    super.initState();
    // Device flow will only start if they click "Use Device Code instead"
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _manualController.dispose();
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
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (status) => true,
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

      if (data['error'] != null) {
        setState(() {
          _error = 'Device flow not supported: ${data['error_description'] ?? data['error']}';
          _loading = false;
        });
        return;
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
        _error = 'Failed to start login: ${e is DioException ? GitHubApiException.fromDioError(e).message : e.toString()}';
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
            contentType: Headers.formUrlEncodedContentType,
            validateStatus: (status) => true,
          ),
        );

        var data = response.data;
        debugPrint('OAuth Poll Response: status=${response.statusCode}, body=$data');
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
      } on DioException catch (e) {
        debugPrint('OAuth Poll Dio Error: ${e.message}, response: ${e.response?.data}');
        timer.cancel();
        setState(() {
          _error = 'Connection lost during verification: ${e.message}. Please check your network and click Retry.';
        });
      } catch (e) {
        debugPrint('OAuth Poll General Error: $e');
        timer.cancel();
        setState(() {
          _error = 'An error occurred: $e. Please try again.';
        });
      }
    });
  }

  Future<void> _validateAndSaveManualToken() async {
    final token = _manualController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _manualError = 'Please enter a token';
      });
      return;
    }

    setState(() {
      _validatingManual = true;
      _manualError = null;
    });

    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'GitExplorer-App',
        },
      ));
      
      final response = await dio.get('/user');
      if (response.statusCode == 200) {
        await ref.read(githubPatProvider.notifier).save(token);
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _manualError = 'Invalid token (Status: ${response.statusCode})';
        });
      }
    } on DioException catch (e) {
      final apiException = GitHubApiException.fromDioError(e);
      setState(() {
        _manualError = 'Validation failed: ${apiException.message}';
      });
    } catch (e) {
      setState(() {
        _manualError = 'An error occurred: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _validatingManual = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
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
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.code_rounded,
                    color: isDark ? Colors.white : Colors.black,
                    size: 24,
                  ),
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

            if (_showManual) ...[
              Text(
                'Personal Access Token',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _manualController,
                obscureText: _obscureManual,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'ghp_...',
                  errorText: _manualError,
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureManual ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _obscureManual = !_obscureManual);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Token Guide:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    _buildStepRow(1, 'Click the button below to open GitHub.'),
                    const SizedBox(height: 4),
                    _buildStepRow(2, 'Scroll down and click "Generate token" at the bottom.'),
                    const SizedBox(height: 4),
                    _buildStepRow(3, 'Copy the token (starts with ghp_) and paste it above.'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  launchUrl(
                    Uri.parse('https://github.com/settings/tokens/new?scopes=repo,read:user,workflow&description=GitPulse%20Suite'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Generate Token on GitHub ↗'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
              const SizedBox(height: 20),
              if (_validatingManual)
                const Center(child: GlowingIndicator())
              else ...[
                FilledButton.icon(
                  onPressed: _validateAndSaveManualToken,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Validate & Connect'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showManual = false;
                      _manualError = null;
                      if (_userCode == null) _startDeviceFlow();
                    });
                  },
                  child: const Text('Use Device Code instead'),
                ),
              ],
            ] else if (_loading)
              const Center(child: GlowingIndicator())
            else if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _loading = true;
                  });
                  _startDeviceFlow();
                },
                child: const Text('Retry'),
              ),
            ] else ...[
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
                    child: GlowingIndicator(size: 14),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Waiting for authorization...',
                    style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 16),
            if (!_showManual) ...[
              TextButton(
                onPressed: () {
                  setState(() {
                    _showManual = true;
                  });
                },
                child: const Text('Or, enter Personal Access Token manually'),
              ),
              const SizedBox(height: 8),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStepRow(int number, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: 0.15),
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
