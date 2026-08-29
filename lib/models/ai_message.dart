class AIMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? evidence;
  final bool isRAGSupported;

  const AIMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.evidence,
    this.isRAGSupported = false,
  });
}
