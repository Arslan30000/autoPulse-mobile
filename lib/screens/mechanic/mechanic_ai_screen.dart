import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autosense_ai/core/theme/app_colors.dart';
import 'package:autosense_ai/core/theme/app_text_styles.dart';
import 'package:autosense_ai/core/widgets/ai_message_bubble.dart';
import 'package:autosense_ai/models/ai_message.dart';
import 'package:autosense_ai/data/mock/mock_data.dart';

class MechanicAIScreen extends StatefulWidget {
  const MechanicAIScreen({super.key});

  @override
  State<MechanicAIScreen> createState() => _MechanicAIScreenState();
}

class _MechanicAIScreenState extends State<MechanicAIScreen> {
  final List<AIMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  static const _mechanicResponses = {
    'airflow': 'Technical Analysis:\n\nThe current airflow-related telemetry deviates significantly from the vehicle\'s learned historical baseline under comparable operating conditions.\n\nRelevant evidence:\n• MAF reading: 0.21 g/s (baseline: 2.5-4.0 g/s)\n• Engine Load: 12% (within range)\n• Throttle Position: 18.04% (normal)\n• DTC P0101 active\n• Historical trend shows progressive MAF decline\n\nPossible contributing areas:\n1. MAF sensor contamination or failure\n2. Intake path restriction (post-MAF)\n3. Air leak between MAF and throttle body\n4. MAF sensor wiring/connector issue\n\nRecommended diagnostic sequence:\n1. Inspect intake path for obstructions\n2. Clean MAF sensor with appropriate cleaner\n3. Compare MAF readings at idle vs. 2500 RPM\n4. Smoke test for post-MAF air leaks\n5. Check MAF connector and wiring\n6. Compare with known-good MAF if available',
    'p0101': 'DTC P0101 Analysis:\n\nThis code indicates the PCM has detected the MAF sensor signal is outside the expected range.\n\nThe ECU cross-references MAF readings against expected values calculated from RPM, throttle position, intake temperature, and barometric pressure.\n\nIn this case:\n• MAF reads 0.21 g/s at idle\n• Expected range at idle: 2.5-4.0 g/s\n• This represents a ~94% deviation from expected\n\nFreeze frame data context:\n• RPM at code set: 780\n• Coolant temp: 69°C (engine warmed up)\n• Intake temp: 63°C\n\nThis is a consistent deviation, not intermittent, suggesting a persistent issue rather than a transient fault.',
    'check': 'Recommended Diagnostic Procedure:\n\n1. Visual Inspection\n   - Check air filter condition\n   - Inspect intake ducting for cracks/disconnections\n   - Look for obvious contamination on MAF sensor\n\n2. MAF Testing\n   - Record MAF readings at idle: expect 2.5-4.0 g/s\n   - Record at 2500 RPM: expect 8-15 g/s\n   - If readings are consistently low: sensor issue\n   - Try MAF sensor cleaner before replacement\n\n3. Leak Testing\n   - Perform smoke test on intake system\n   - Focus on connections post-MAF\n   - Check vacuum lines\n\n4. Data Comparison\n   - Compare current readings with historical baseline\n   - Check if deviation is progressive or sudden',
    'default': 'Based on the current diagnostic data for this Toyota Yaris 2020:\n\nActive Issues:\n• DTC P0101 - MAF Circuit Range/Performance\n• Airflow anomaly detected (82% confidence)\n\nTelemetry Summary:\n• MAF: 0.21 g/s (significant deviation from baseline)\n• Engine Load: 12% (within normal range)\n• Coolant: 69°C (normal operating temperature)\n• All other systems operating within parameters\n\nThe primary concern is the MAF reading. Would you like me to provide a detailed analysis of the airflow anomaly, the DTC code, or recommended diagnostic procedures?',
  };

  static const _mechanicSuggestedQuestions = [
    'What could explain this airflow anomaly?',
    'Analyze DTC P0101 in detail',
    'What diagnostic steps should I follow?',
    'Show historical telemetry comparison',
  ];

  @override
  void initState() {
    super.initState();
    // Start with a context message
    _messages.add(AIMessage(
      content: 'AutoSense Diagnostic AI ready.\n\nVehicle: Toyota Yaris 2020\nActive DTCs: 1 (P0101)\nActive Anomalies: 1 (Airflow Deviation, 82%)\n\nTelemetry, diagnostic codes, anomaly data, and vehicle history are available for analysis.',
      isUser: false,
      timestamp: DateTime.now(),
      evidence: ['Live Telemetry', 'DTC Database', 'Anomaly Detection', 'Vehicle History', 'Automotive Knowledge Base'],
      isRAGSupported: true,
    ));
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
      _messages.add(AIMessage(content: text.trim(), isUser: true, timestamp: DateTime.now()));
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final lower = text.toLowerCase();
      String response = _mechanicResponses['default']!;
      for (final entry in _mechanicResponses.entries) {
        if (entry.key != 'default' && lower.contains(entry.key)) {
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
          evidence: ['Live Telemetry', 'DTC Database', 'Anomaly Detection', 'Vehicle History', 'Automotive Knowledge Base'],
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
      body: SafeArea(
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
                      Text('AutoSense Diagnostic AI', style: AppTextStyles.headlineMedium.copyWith(fontSize: 20)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.build_circle_rounded, size: 14, color: AppColors.warning),
                            const SizedBox(width: 4),
                            Text('Mechanic', style: AppTextStyles.labelSmall.copyWith(color: AppColors.warning)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Context bar
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_car_rounded, color: AppColors.primary, size: 16),
                        const SizedBox(width: 8),
                        Text(MockData.vehicle.fullDisplayName, style: AppTextStyles.bodySmall),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Knowledge-grounded', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary, fontSize: 9)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  return AIMessageBubble(message: _messages[index]);
                },
              ),
            ),

            // Suggested questions
            if (_messages.length <= 2)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _mechanicSuggestedQuestions.map((q) {
                    return GestureDetector(
                      onTap: () => _sendMessage(q),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceTertiary,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(q, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Input
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ask about diagnostics...',
                        filled: true,
                        fillColor: AppColors.surfaceSecondary,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _sendMessage(_controller.text),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                      child: const Icon(Icons.send_rounded, color: AppColors.background, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        decoration: BoxDecoration(color: AppColors.surfaceSecondary, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => Container(
            width: 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.textTertiary),
          ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 600.ms, delay: Duration(milliseconds: i * 200)).then().fadeOut(duration: 600.ms)),
        ),
      ),
    );
  }
}
