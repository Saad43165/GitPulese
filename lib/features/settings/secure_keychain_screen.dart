import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/keychain_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/page_header.dart';
import '../../widgets/safe_page.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/aurora_background.dart';
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../widgets/glowing_indicator.dart';

class SecureKeychainScreen extends ConsumerStatefulWidget {
  const SecureKeychainScreen({super.key});

  @override
  ConsumerState<SecureKeychainScreen> createState() => _SecureKeychainScreenState();
}

class _SecureKeychainScreenState extends ConsumerState<SecureKeychainScreen> {
  String _pinBuffer = '';
  String _confirmBuffer = '';
  bool _confirming = false;
  final Map<String, bool> _revealedKeys = {};

  @override
  void dispose() {
    // Re-lock the keychain for security when leaving the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(keychainProvider.notifier).lock();
      }
    });
    super.dispose();
  }

  void _handleKeyPress(String value, KeychainState state, KeychainNotifier notifier) async {
    HapticFeedback.lightImpact();
    if (value == 'BACK') {
      if (_pinBuffer.isNotEmpty) {
        setState(() {
          _pinBuffer = _pinBuffer.substring(0, _pinBuffer.length - 1);
        });
      }
      return;
    }

    if (_pinBuffer.length >= 4) return;

    setState(() {
      _pinBuffer += value;
    });

    if (_pinBuffer.length == 4) {
      // Small delay for visual response
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;

      if (!state.isPinSet) {
        // Pin Setup flow
        if (!_confirming) {
          setState(() {
            _confirmBuffer = _pinBuffer;
            _pinBuffer = '';
            _confirming = true;
          });
        } else {
          if (_pinBuffer == _confirmBuffer) {
            await notifier.setPin(_pinBuffer);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Security PIN set successfully!')),
              );
            }
          } else {
            setState(() {
              _pinBuffer = '';
              _confirmBuffer = '';
              _confirming = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PINs did not match. Please try again.')),
              );
            }
          }
        }
      } else {
        // Unlock flow
        final success = await notifier.verifyAndUnlock(_pinBuffer);
        if (!success) {
          setState(() {
            _pinBuffer = '';
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Incorrect PIN! Please try again.')),
            );
          }
        }
      }
    }
  }

  void _showAddKeyDialog(KeychainNotifier notifier) {
    final labelController = TextEditingController();
    final tokenController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF161B22) 
              : Colors.white,
          title: const Text('Add Secure Token', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Token Label',
                    hintText: 'e.g. Work Read-Only Token',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tokenController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Token / Key Value',
                    hintText: 'ghp_...',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Notes or scope details',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final label = labelController.text.trim();
                final token = tokenController.text.trim();
                final desc = descController.text.trim();

                if (label.isEmpty || token.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Label and Token Value are required')),
                  );
                  return;
                }

                notifier.addItem(label, token, desc.isEmpty ? null : desc);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Token saved securely.')),
                );
              },
              child: const Text('Save Securely'),
            ),
          ],
        );
      },
    );
  }

  void _confirmWipe(KeychainNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF161B22) 
              : Colors.white,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              const SizedBox(width: 8),
              const Text('Wipe Keychain?', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Resetting your security PIN will wipe all currently stored developer keys to protect your credentials. This action is irreversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () async {
                await notifier.resetKeychainAndWipe();
                if (context.mounted) Navigator.pop(context);
                setState(() {
                  _pinBuffer = '';
                  _confirmBuffer = '';
                  _confirming = false;
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Keychain and PIN wiped successfully.')),
                  );
                }
              },
              child: const Text('Wipe & Reset'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(keychainProvider);
    final notifier = ref.read(keychainProvider.notifier);
    final activePat = ref.watch(githubPatProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('Token Keychain'),
          actions: [
            if (state.isUnlocked)
              IconButton(
                icon: const Icon(Icons.lock_outline_rounded),
                tooltip: 'Lock Keychain',
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  notifier.lock();
                  setState(() {
                    _pinBuffer = '';
                  });
                },
              ),
          ],
        ),
        body: SafePage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageHeader(
                showBackButton: false,
                title: 'Secure Keychain',
                subtitle: 'Store and apply your GitHub PATs & developer keys locally.',
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: (!state.isPinSet || !state.isUnlocked)
                      ? _buildPinPadView(state, notifier, isDark)
                      : _buildVaultView(state, notifier, isDark, activePat),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinPadView(KeychainState state, KeychainNotifier notifier, bool isDark) {
    String titleText = '';
    String subtitleText = '';
    IconData headerIcon = Icons.lock_outline_rounded;
    Color iconColor = AppColors.accent;

    if (!state.isPinSet) {
      if (!_confirming) {
        titleText = 'Create Security PIN';
        subtitleText = 'Set a 4-digit PIN to protect your developer keys';
        headerIcon = Icons.security_rounded;
        iconColor = const Color(0xFF10B981);
      } else {
        titleText = 'Confirm Security PIN';
        subtitleText = 'Re-enter your 4-digit PIN to confirm';
        headerIcon = Icons.fact_check_outlined;
        iconColor = const Color(0xFF38BDF8);
      }
    } else {
      titleText = 'Enter Security PIN';
      subtitleText = 'Enter your 4-digit PIN to access stored keys';
      headerIcon = Icons.lock_person_outlined;
      iconColor = AppColors.accent;
    }

    return Column(
      key: ValueKey('pin-pad-${_confirming ? "confirm" : "normal"}'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.2),
                blurRadius: 24,
                spreadRadius: 2,
              )
            ],
          ),
          child: Icon(headerIcon, size: 42, color: iconColor),
        ),
        const SizedBox(height: 24),
        Text(
          titleText,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Text(
          subtitleText,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // PIN circles indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final filled = index < _pinBuffer.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              width: filled ? 20 : 16,
              height: filled ? 20 : 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled 
                    ? iconColor 
                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                border: Border.all(
                  color: filled 
                      ? iconColor 
                      : (isDark ? Colors.white24 : Colors.black12),
                  width: filled ? 0 : 2,
                ),
                boxShadow: filled ? [
                  BoxShadow(color: iconColor.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)
                ] : [],
              ),
            );
          }),
        ),
        const SizedBox(height: 48),
        // Numeric keypad
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            children: [
              for (var row in [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ]) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: row.map((val) => _buildKeypadButton(val, state, notifier, isDark)).toList(),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 78), // Spacer
                  _buildKeypadButton('0', state, notifier, isDark),
                  _buildKeypadButton('BACK', state, notifier, isDark),
                ],
              ),
            ],
          ),
        ),
        if (state.isPinSet) ...[
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: () => _confirmWipe(notifier),
            icon: const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.danger),
            label: const Text(
              'Forgot PIN? Reset Vault',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildKeypadButton(String label, KeychainState state, KeychainNotifier notifier, bool isDark) {
    final isBack = label == 'BACK';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleKeyPress(label, state, notifier),
        borderRadius: BorderRadius.circular(40),
        splashColor: AppColors.accent.withValues(alpha: 0.2),
        highlightColor: AppColors.accent.withValues(alpha: 0.1),
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
          ),
          alignment: Alignment.center,
          child: isBack
              ? Icon(Icons.backspace_rounded, size: 24, color: isDark ? Colors.white60 : Colors.black54)
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildVaultView(KeychainState state, KeychainNotifier notifier, bool isDark, String? activePat) {
    return Column(
      key: const ValueKey('vault-view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stored Credentials (${state.items.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Key'),
                onPressed: () => _showAddKeyDialog(notifier),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.vpn_key_outlined,
                        size: 48,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Keys Stored Yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add tokens/keys here to use them in the app.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageHorizontal,
                    vertical: AppSpacing.md,
                  ),
                  itemCount: state.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    final revealed = _revealedKeys[item.id] ?? false;
                    final isActive = activePat == item.token;

                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF1E293B).withValues(alpha: 0.8),
                                  const Color(0xFF0F172A).withValues(alpha: 0.9),
                                ]
                              : [
                                  Colors.white.withValues(alpha: 0.9),
                                  Colors.grey.shade50.withValues(alpha: 0.95),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isActive 
                              ? AppColors.success.withValues(alpha: 0.4) 
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          width: isActive ? 1.5 : 1,
                        ),
                        boxShadow: [
                          if (isActive)
                            BoxShadow(
                              color: AppColors.success.withValues(alpha: 0.1),
                              blurRadius: 12,
                              spreadRadius: 1,
                            )
                          else
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: (isActive ? AppColors.success : AppColors.accent).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isActive ? Icons.verified_user_rounded : Icons.key_rounded,
                                        size: 16,
                                        color: isActive ? AppColors.success : AppColors.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      item.label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        revealed 
                                            ? Icons.visibility_off_outlined 
                                            : Icons.visibility_outlined,
                                        size: 20,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _revealedKeys[item.id] = !revealed;
                                        });
                                      },
                                      tooltip: 'Reveal token',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 20),
                                      color: isDark ? Colors.white60 : Colors.black54,
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: item.token));
                                        HapticFeedback.mediumImpact();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Token copied to clipboard.')),
                                        );
                                      },
                                      tooltip: 'Copy token',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                                      onPressed: () {
                                        HapticFeedback.mediumImpact();
                                        notifier.removeItem(item.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Token deleted.')),
                                        );
                                      },
                                      tooltip: 'Delete key',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (item.description != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                item.description!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Text(
                                revealed ? item.token : _maskToken(item.token),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  letterSpacing: 1.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: isActive
                                      ? OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.success,
                                            side: const BorderSide(color: AppColors.success, width: 1.5),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                                          label: const Text('Currently Active Session', style: TextStyle(fontWeight: FontWeight.bold)),
                                          onPressed: () {
                                            HapticFeedback.lightImpact();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('This Personal Access Token is already active!'),
                                              ),
                                            );
                                          },
                                        )
                                      : FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppColors.accent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                          icon: const Icon(Icons.login_rounded, size: 18),
                                          label: const Text('Apply & Login as Active PAT', style: TextStyle(fontWeight: FontWeight.bold)),
                                          onPressed: () async {
                                            HapticFeedback.mediumImpact();
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (context) => const Center(
                                                child: GlowingIndicator(),
                                              ),
                                            );
                                            try {
                                              final tempDio = Dio(BaseOptions(
                                                baseUrl: ApiConstants.baseUrl,
                                                connectTimeout: ApiConstants.requestTimeout,
                                                receiveTimeout: ApiConstants.requestTimeout,
                                                headers: {
                                                  'Authorization': 'Bearer ${item.token}',
                                                  'Accept': 'application/vnd.github+json',
                                                  'User-Agent': 'GitExplorer-App',
                                                },
                                              ));
                                              
                                              final response = await tempDio.get('/user');
                                              if (context.mounted) Navigator.pop(context);
                                              if (response.statusCode == 200) {
                                                await ref.read(githubPatProvider.notifier).save(item.token);
                                                ref.read(demoUsernameProvider.notifier).state = null;
                                                
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Successfully authenticated with "${item.label}"!'),
                                                      backgroundColor: AppColors.success,
                                                    ),
                                                  );
                                                }
                                              }
                                            } catch (e) {
                                              if (context.mounted) Navigator.pop(context);
                                              String errMsg = 'Failed to authenticate';
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(errMsg),
                                                    backgroundColor: AppColors.danger,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _maskToken(String token) {
    if (token.length <= 8) return '••••••••';
    return '${token.substring(0, 4)}••••••••${token.substring(token.length - 4)}';
  }
}
