import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/core/widgets/ai_message_bubble.dart';
import 'package:autopulse_ai/models/ai_message.dart';
import 'package:autopulse_ai/data/mock/mock_data.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final List<AIMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messages.addAll(MockData.aiConversation);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(AIMessage(
        content: text.trim(),
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    // Simulate AI response
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;

      final lowerMessage = text.toLowerCase();
      String response = MockData.mockAIResponses['default']!;

      for (final entry in MockData.mockAIResponses.entries) {
        if (entry.key != 'default' && lowerMessage.contains(entry.key)) {
          response = entry.value;
          break;
        }
      }

      setState(() {
        _isTyping = false;
        _messages.add(AIMessage(
          content: response,
          isUser: false,
          timestamp: DateTime.now(),
          evidence: [
            'MAF readings',
            'Engine Load',
            'Throttle Position',
            'Historical vehicle data',
            'Diagnostic code',
            'Automotive knowledge base',
          ],
          isRAGSupported: true,
        ));
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surfaceSecondary,
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: AppColors.primary, size: 28)
                            .animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2.seconds),
                        const SizedBox(width: 12),
                        Text('autopulse AI', style: AppTextStyles.headlineMedium),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your vehicle-aware diagnostic assistant',
                      style: AppTextStyles.bodySmall?.copyWith(color: AppColors.primary.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: 16),
                    // Context banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.directions_car_rounded, color: AppColors.primary, size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(MockData.vehicle.fullDisplayName, style: AppTextStyles.titleSmall),
                                        Text(
                                          'Vehicle Context Active',
                                          style: AppTextStyles.labelSmall?.copyWith(color: AppColors.success),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.success,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(color: AppColors.success, blurRadius: 6, spreadRadius: 2)
                                      ],
                                    ),
                                  ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 1.seconds),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Responses use available vehicle telemetry, detected anomalies, vehicle history and automotive knowledge.',
                                style: AppTextStyles.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isTyping) {
                      return _buildTypingIndicator();
                    }
                    return AIMessageBubble(message: _messages[index])
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.1, end: 0, duration: 300.ms);
                  },
                ),
              ),

              // Suggested questions
              if (_messages.length <= 2)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: MockData.suggestedQuestions.map((q) {
                      return GestureDetector(
                        onTap: () => _sendMessage(q),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceTertiary.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withValues(alpha: 0.1), blurRadius: 10)
                            ]
                          ),
                          child: Text(q, style: AppTextStyles.bodySmall?.copyWith(color: AppColors.primary)),
                        ),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2);
                    }).toList(),
                  ),
                ),

              // Input area
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.8),
                      border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            style: AppTextStyles.bodyMedium,
                            decoration: InputDecoration(
                              hintText: 'Ask about your vehicle...',
                              hintStyle: AppTextStyles.bodyMedium?.copyWith(color: AppColors.textTertiary),
                              filled: true,
                              fillColor: AppColors.surfaceSecondary.withValues(alpha: 0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.5)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.5)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(color: AppColors.primary),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            ),
                            onSubmitted: _sendMessage,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _sendMessage(_controller.text),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryDim],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: AppColors.background,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .fadeIn(duration: 600.ms, delay: Duration(milliseconds: index * 200))
        .then()
        .fadeOut(duration: 600.ms);
  }
}
