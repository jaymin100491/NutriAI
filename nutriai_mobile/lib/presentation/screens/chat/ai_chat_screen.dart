import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/chat_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/diet_plan_provider.dart';
import '../../widgets/craft/craft.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(chatNotifierProvider.notifier).loadHistory());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _sendMessage([String? text]) async {
    final message = text ?? _controller.text.trim();
    if (message.isEmpty) return;
    _controller.clear();
    await ref.read(chatNotifierProvider.notifier).sendMessage(message);
    _scrollToBottom();

    final chatState = ref.read(chatNotifierProvider);
    if (chatState.planModified) {
      ref.read(dietPlanNotifierProvider.notifier).loadCurrentDietPlan();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your 7-day meal plan has been updated!'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Dietitian', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Personalized nutrition coach', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear chat',
            onPressed: () => ref.read(chatNotifierProvider.notifier).clearChat(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildWelcomeBanner(),
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildEmptyState(chatState.suggestions)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatState.messages.length + (chatState.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == chatState.messages.length) return _buildTypingIndicator();
                      return _buildMessageBubble(chatState.messages[index]);
                    },
                  ),
          ),
          if (chatState.suggestions.isNotEmpty && !chatState.isLoading)
            _buildSuggestions(chatState.suggestions),
          _buildInputBar(chatState.isLoading),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: TrustBanner(
        verified: true,
        title: 'Nutrition coaching only',
        subtitle:
            'Ask about your plan, cooking steps, labs, or goals. Unrelated asks (weather, sports, trivia) get a short redirect — not an answer.',
        sources: const ['scope: labs + plan + goals', 'OpenAI when needed'],
      ),
    );
  }

  Widget _buildEmptyState(List<String> suggestions) {
    final defaults = [
      'How do I make tomorrow’s breakfast?',
      'What’s on my plan for today?',
      'Change tofu to paneer in my plan',
    ];
    final chips = suggestions.isNotEmpty ? suggestions : defaults;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.chipBg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.auto_awesome, size: 34, color: AppTheme.primaryColor),
          ).craftIn(),
          const SizedBox(height: 18),
          Text(
            'Your personal AI dietitian',
            style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800),
          ).craftIn(delayMs: 40),
          const SizedBox(height: 8),
          Text(
            'I know your lab results, health goals, and meal plan. Tell me what to change.',
            style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondaryColor, height: 1.4),
            textAlign: TextAlign.center,
          ).craftIn(delayMs: 80),
          const SizedBox(height: 28),
          ...chips.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SuggestionChip(label: e.value, onTap: () => _sendMessage(e.value))
                      .craftIn(delayMs: 110 + e.key * 40),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isUser ? null : Border.all(color: AppTheme.borderSubtle),
        ),
        child: Text(
          message.content,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: isUser ? Colors.white : AppTheme.ink,
            height: 1.45,
          ),
        ),
      ),
    ).craftIn(durationMs: 280);
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Thinking with your labs…',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSecondaryColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ).craftIn(),
    );
  }

  Widget _buildSuggestions(List<String> suggestions) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ActionChip(
          label: Text(suggestions[index], style: const TextStyle(fontSize: 12)),
          onPressed: () => _sendMessage(suggestions[index]),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isLoading) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !isLoading,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'e.g. "Change tofu to paneer"',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: isLoading ? null : () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.borderSubtle),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
