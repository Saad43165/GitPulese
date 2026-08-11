import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/core_providers.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/glowing_indicator.dart';

final _branchesProvider = FutureProvider.autoDispose
    .family<List<String>, ({String owner, String repo})>(
  (ref, args) async {
    final api = ref.watch(githubApiServiceProvider);
    return api.getRepoBranches(args.owner, args.repo);
  },
);

class CreatePrScreen extends ConsumerStatefulWidget {
  final String owner;
  final String repoName;
  final String? defaultBase;

  const CreatePrScreen({
    super.key,
    required this.owner,
    required this.repoName,
    this.defaultBase,
  });

  @override
  ConsumerState<CreatePrScreen> createState() => _CreatePrScreenState();
}

class _CreatePrScreenState extends ConsumerState<CreatePrScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String? _headBranch;
  String? _baseBranch;
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_headBranch == null || _baseBranch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select head and base branches.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final pr = await ref.read(githubApiServiceProvider).createPullRequest(
            widget.owner,
            widget.repoName,
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            head: _headBranch!,
            base: _baseBranch!,
          );
      if (!mounted) return;
      final number = pr['number'] as int? ?? 0;
      final title = pr['title'] as String? ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PR #$number created!')),
      );
      context.pushReplacement(AppRoutes.prPath(widget.owner, widget.repoName, number, title));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = (owner: widget.owner, repo: widget.repoName);
    final branchesAsync = ref.watch(_branchesProvider(args));

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('New Pull Request'),
        backgroundColor: const Color(0xFF0D1117),
      ),
      body: branchesAsync.when(
        data: (branches) {
          // Set defaults
          if (_baseBranch == null) {
            _baseBranch = widget.defaultBase ??
                (branches.contains('main')
                    ? 'main'
                    : branches.contains('master')
                        ? 'master'
                        : branches.isNotEmpty
                            ? branches.first
                            : null);
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _label('Title'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Pull request title'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                _label('Head branch (your changes)'),
                const SizedBox(height: 6),
                _BranchDropdown(
                  branches: branches,
                  value: _headBranch,
                  hint: 'Select head branch',
                  onChanged: (v) => setState(() => _headBranch = v),
                ),
                const SizedBox(height: 16),
                _label('Base branch (merge target)'),
                const SizedBox(height: 6),
                _BranchDropdown(
                  branches: branches,
                  value: _baseBranch,
                  hint: 'Select base branch',
                  onChanged: (v) => setState(() => _baseBranch = v),
                ),
                const SizedBox(height: 16),
                _label('Description (optional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _bodyController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 8,
                  minLines: 4,
                  decoration: _inputDecoration('Describe the changes in this PR'),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Create Pull Request',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: GlowingIndicator(size: 32)),
        error: (e, _) => Center(
          child: Text('Failed to load branches: $e',
              style: const TextStyle(color: Colors.white54)),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF0D1117),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

class _BranchDropdown extends StatelessWidget {
  final List<String> branches;
  final String? value;
  final String hint;
  final ValueChanged<String?> onChanged;

  const _BranchDropdown({
    required this.branches,
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: branches.contains(value) ? value : null,
          hint: Text(hint, style: const TextStyle(color: Colors.white38, fontSize: 13)),
          dropdownColor: const Color(0xFF0D1117),
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: branches
              .map((b) => DropdownMenuItem(value: b, child: Text(b)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
