import 'package:autosense_ai/models/ai_message.dart';
import 'package:autosense_ai/data/mock/mock_data.dart';

abstract class AIService {
  Future<AIMessage> sendMessage(String message);
  List<String> getSuggestedQuestions();
}

class MockAIService implements AIService {
  @override
  Future<AIMessage> sendMessage(String message) async {
    await Future.delayed(const Duration(milliseconds: 1500));

    final lowerMessage = message.toLowerCase();
    String response = MockData.mockAIResponses['default']!;

    for (final entry in MockData.mockAIResponses.entries) {
      if (entry.key != 'default' && lowerMessage.contains(entry.key)) {
        response = entry.value;
        break;
      }
    }

    return AIMessage(
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
    );
  }

  @override
  List<String> getSuggestedQuestions() {
    return MockData.suggestedQuestions;
  }
}
