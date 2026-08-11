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

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

class AuthDialog extends ConsumerStatefulWidget {
  const AuthDialog({super.key});

  @override
  ConsumerState<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends ConsumerState<AuthDialog> {
  final Dio _dio = Dio();
  final String _clientId = 'Ov23liSRrNr1PE6Kbd1F';
  // IMPORTANT: For the seamless web flow, GitHub requires a client secret to exchange the code.
  // Add your client secret from GitHub OAuth App settings here.
  final String _clientSecret = '8dcf585b015c076b854c9875599c6aea01eb8737'; 
  
  bool _loading = false;
  String? _userCode;
  String? _verificationUri;
  String? _deviceCode;
  String? _error;
  Timer? _pollTimer;
  int _interval = 5;
  bool _copied = false;

  bool _showManual = false;
  bool _showDeviceFlow = false;
  bool _validatingManual = false;
  final _manualController = TextEditingController();
  bool _obscureManual = true;
  String? _manualError;
  Map<String, dynamic>? _validatedUser;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _startWebFlow() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      const callbackUrlScheme = 'gitpulse';
      
      final url = Uri.https('github.com', '/login/oauth/authorize', {
        'client_id': _clientId,
        'scope': 'repo read:user workflow',
        // Optional: you can include redirect_uri if configured in GitHub
        // 'redirect_uri': '$callbackUrlScheme://callback', 
      });

      final result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: callbackUrlScheme,
      );

      final code = Uri.parse(result).queryParameters['code'];

      if (code != null) {
        if (_clientSecret == 'YOUR_CLIENT_SECRET_HERE') {
          setState(() {
            _error = 'Please add your Client Secret in auth_dialog.dart to complete the web flow.';
            _loading = false;
          });
          return;
        }

        final response = await _dio.post(
          'https://github.com/login/oauth/access_token',
          data: {
            'client_id': _clientId,
            'client_secret': _clientSecret,
            'code': code,
          },
          options: Options(
            headers: {'Accept': 'application/json'},
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

        if (data['access_token'] != null) {
          final token = data['access_token'];
          await ref.read(githubPatProvider.notifier).save(token);
          if (mounted) Navigator.of(context).pop(true);
        } else {
          setState(() {
            _error = 'Failed to get token: ${data['error_description'] ?? data['error']}';
            _loading = false;
          });
        }
      } else {
        setState(() {
          _error = 'No code returned from GitHub.';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Web Login failed: $e\n\nDid you add the callback URL scheme to your AndroidManifest.xml?';
        _loading = false;
      });
    }
  }

  Future<void> _startDeviceFlow() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _dio.post(
        'https://github.com/login/device/code',
        data: {
          'client_id': _clientId,
          'scope': 'repo user workflow',
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
          _error = 'Device flow error: ${data['error_description'] ?? data['error']}';
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
        _error = 'Failed to start device login: ${e is DioException ? GitHubApiException.fromDioError(e).message : e.toString()}';
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
          await ref.read(githubPatProvider.notifier).save(token);
          if (mounted) Navigator.of(context).pop(true);
        } else if (data['error'] == 'authorization_pending') {
          // Waiting for user to complete browser auth
        } else if (data['error'] == 'slow_down') {
          _interval += 5;
          timer.cancel();
          _pollForToken();
        } else {
          timer.cancel();
          setState(() {
            _error = 'Login failed: ${data['error_description'] ?? data['error']}';
          });
        }
      } catch (e) {
        timer.cancel();
        setState(() {
          _error = 'Connection error: $e';
        });
      }
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.isNotEmpty) {
      _manualController.text = data.text!.trim();
      HapticFeedback.lightImpact();
      _validateAndSaveManualToken();
    }
  }

  Future<void> _validateAndSaveManualToken() async {
    final token = _manualController.text.trim();
    if (token.isEmpty) {
      setState(() => _manualError = 'Please enter a Personal Access Token');
      return;
    }

    setState(() {
      _validatingManual = true;
      _manualError = null;
      _validatedUser = null;
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
        setState(() {
          _validatedUser = response.data as Map<String, dynamic>?;
        });
        await Future.delayed(const Duration(milliseconds: 600));
        await ref.read(githubPatProvider.notifier).save(token);
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() => _manualError = 'Invalid token (Status: ${response.statusCode})');
      }
    } on DioException catch (e) {
      final apiException = GitHubApiException.fromDioError(e);
      setState(() => _manualError = apiException.message);
    } catch (e) {
      setState(() => _manualError = 'Verification failed: $e');
    } finally {
      if (mounted) setState(() => _validatingManual = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Image.asset(
                      'assets/images/github.png',
                      width: 22,
                      height: 22,
                      color: AppColors.accent,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.key_rounded,
                        color: AppColors.accent,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connect GitHub Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Unlock private repos & account actions',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_showManual) ...[
                // Token Input Field
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Personal Access Token',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pasteFromClipboard,
                      icon: const Icon(Icons.content_paste_rounded, size: 14),
                      label: const Text('Paste Token', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _manualController,
                  obscureText: _obscureManual,
                  style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'ghp_...',
                    errorText: _manualError,
                    prefixIcon: const Icon(Icons.key_rounded, size: 18, color: AppColors.accent),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureManual ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscureManual = !_obscureManual),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),

                // Quick Steps Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Token Setup Guide (30 Seconds):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      _buildStepRow(1, 'Tap "Generate Token" below to open GitHub settings.'),
                      const SizedBox(height: 4),
                      _buildStepRow(2, 'Scroll down and tap "Generate token".'),
                      const SizedBox(height: 4),
                      _buildStepRow(3, 'Copy your new token and tap "Paste Token" above.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    launchUrl(
                      Uri.parse('https://github.com/settings/tokens/new?scopes=repo,read:user,workflow&description=GitExplorer%20Mobile'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Generate Token on GitHub ↗'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                if (_validatingManual)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        GlowingIndicator(size: 28),
                        SizedBox(height: 8),
                        Text('Validating token with GitHub...', style: TextStyle(fontSize: 12, color: AppColors.accent)),
                      ],
                    ),
                  )
                else if (_validatedUser != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: NetworkImage(_validatedUser!['avatar_url'] ?? ''),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Connected as @${_validatedUser!['login']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 13),
                          ),
                        ),
                        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                      ],
                    ),
                  )
                else ...[
                  FilledButton.icon(
                    onPressed: _validateAndSaveManualToken,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Verify & Connect Token'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showManual = false;
                        _showDeviceFlow = false;
                        _manualError = null;
                      });
                    },
                    child: const Text('Use GitHub OAuth instead'),
                  ),
                ],
              ] else if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: GlowingIndicator(size: 32)),
                )
              else if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      if (_showDeviceFlow) _startDeviceFlow();
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                ),
              ] else if (!_showDeviceFlow) ...[
                FilledButton.icon(
                  onPressed: _startWebFlow,
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text('Continue with GitHub'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showDeviceFlow = true;
                      _startDeviceFlow();
                    });
                  },
                  child: const Text('Use Device Verification Code instead', style: TextStyle(fontSize: 12)),
                ),
              ] else ...[
                Text(
                  '1. Copy this verification code:',
                  style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _userCode ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded, 
                          size: 20, 
                          color: _copied ? AppColors.success : AppColors.accent,
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _userCode ?? ''));
                          setState(() => _copied = true);
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) setState(() => _copied = false);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '2. Authorize in GitHub Browser:',
                  style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => launchUrl(Uri.parse(_verificationUri ?? 'https://github.com/login/device'), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text('Open GitHub Verification Page'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GlowingIndicator(size: 16),
                    SizedBox(width: 10),
                    Text('Waiting for browser authorization...', style: TextStyle(fontSize: 12, color: AppColors.accent)),
                  ],
                ),
              ],
              
              if (!_showManual) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _showManual = true),
                  child: const Text('Manually enter Personal Access Token'),
                ),
              ],
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
