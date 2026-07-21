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
import '../../core/network/dio_client.dart';
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
  bool _revealingAll = false;
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

    if (!state.isPinSet) {
      if (!_confirming) {
        titleText = 'Create Security PIN';
        subtitleText = 'Set a 4-digit PIN to protect your developer keys';
      } else {
        titleText = 'Confirm Security PIN';
        subtitleText = 'Re-enter your 4-digit PIN to confirm';
      }
    } else {
      titleText = 'Enter Security PIN';
      subtitleText = 'Enter your 4-digit PIN to access stored keys';
    }

    return Column(
      key: ValueKey('pin-pad-${_confirming ? "confirm" : "normal"}'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          titleText,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
        const SizedBox(height: 32),
        // PIN circles indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final filled = index < _pinBuffer.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled 
                    ? AppColors.accent 
                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                border: Border.all(
                  color: filled 
                      ? AppColors.accent 
                      : (isDark ? Colors.white24 : Colors.black12),
                  width: 2,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 48),
        // Numeric keypad
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Column(
            children: [
              for (var row in [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ]) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: row.map((val) => _buildKeypadButton(val, state, notifier)).toList(),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 70), // Spacer
                  _buildKeypadButton('0', state, notifier),
                  _buildKeypadButton('BACK', state, notifier),
                ],
              ),
            ],
          ),
        ),
        if (state.isPinSet) ...[
          const SizedBox(height: 32),
          TextButton(
            onPressed: () => _confirmWipe(notifier),
            child: const Text(
              'Forgot PIN?',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildKeypadButton(String label, KeychainState state, KeychainNotifier notifier) {
    final isBack = label == 'BACK';
    return InkWell(
      onTap: () => _handleKeyPress(label, state, notifier),
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        alignment: Alignment.center,
        child: isBack
            ? const Icon(Icons.backspace_outlined, size: 20)
            : Text(
                label,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    final revealed = _revealedKeys[item.id] ?? false;

                    return AppSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      revealed 
                                          ? Icons.visibility_off_outlined 
                                          : Icons.visibility_outlined,
                                      size: 18,
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
                                    icon: const Icon(Icons.copy_rounded, size: 18),
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
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
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
                            const SizedBox(height: 4),
                            Text(
                              item.description!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Text(
                              revealed ? item.token : _maskToken(item.token),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: (activePat == item.token)
                                    ? OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.success,
                                          side: const BorderSide(color: AppColors.success, width: 1.5),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                                        label: const Text('Currently Active Session'),
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
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        icon: const Icon(Icons.login_rounded, size: 16),
                                        label: const Text('Apply & Login as Active PAT'),
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
                                            } else {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Failed to authenticate: Invalid status code ${response.statusCode}'),
                                                    backgroundColor: AppColors.danger,
                                                  ),
                                                );
                                              }
                                            }
                                          } catch (e) {
                                            if (context.mounted) Navigator.pop(context);
                                            
                                            String errMsg = 'Failed to authenticate: ';
                                            if (e is DioException) {
                                              errMsg += e.response?.data is Map 
                                                  ? (e.response?.data['message'] ?? e.message)
                                                  : e.message ?? 'Unknown error';
                                            } else {
                                              errMsg += e.toString();
                                            }
                                            
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
