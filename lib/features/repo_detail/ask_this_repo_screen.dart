import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/ai_providers.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_markdown.dart';
import '../../widgets/glowing_indicator.dart';
import '../../widgets/safe_page.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

class AskThisRepoScreen extends ConsumerStatefulWidget {
  const AskThisRepoScreen({
    super.key,
    required this.owner,
    required this.repoName,
    this.description,
    this.primaryLanguage,
    this.readmeSnippet,
  });

  final String owner;
  final String repoName;
  final String? description;
  final String? primaryLanguage;
  final String? readmeSnippet;

  @override
  ConsumerState<AskThisRepoScreen> createState() => _AskThisRepoScreenState();
}

class _AskThisRepoScreenState extends ConsumerState<AskThisRepoScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        text: 'Hello! I am your AI assistant for **${widget.owner}/${widget.repoName}**.\n\nAsk me anything about this repository\'s structure, architecture, dependencies, or getting started instructions!',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messageController.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final groqApi = ref.read(groqApiServiceProvider);
      
      final contextPrompt = '''
Repository Context:
Repository: ${widget.owner}/${widget.repoName}
Description: ${widget.description ?? 'None'}
Primary Language: ${widget.primaryLanguage ?? 'Unknown'}
README Snippet:
${(widget.readmeSnippet ?? '').take(3000)}

User Question: $text
''';

      final reply = await groqApi.explainCode(
        filename: '${widget.repoName}_qa.md',
        code: contextPrompt,
      );

      setState(() {
        _messages.add(ChatMessage(text: reply, isUser: false));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Failed to generate response: ${e.toString()}',
          isUser: false,
        ));
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafePage(
      useAurora: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ask ${widget.repoName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '${widget.owner}/${widget.repoName}',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment:
                          msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!msg.isUser) ...[
                          const CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.accent,
                            child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: msg.isUser
                                  ? AppColors.accent
                                  : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface),
                              borderRadius: BorderRadius.circular(16),
                              border: msg.isUser
                                  ? null
                                  : Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ),
                            child: msg.isUser
                                ? SelectableText(
                                    msg.text,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  )
                                : AppMarkdown(data: msg.text, selectable: true),
                          ),
                        ),
                        if (msg.isUser) ...[
                          const SizedBox(width: 8),
                          const CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person, color: Colors.white, size: 14),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GlowingIndicator(size: 16),
                    SizedBox(width: 8),
                    Text('AI is analyzing repository context...', style: TextStyle(fontSize: 12, color: AppColors.accent)),
                  ],
                ),
              ),

            // Message Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Ask anything about this repo...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.accent),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String take(int n) => length <= n ? this : substring(0, n);
}
