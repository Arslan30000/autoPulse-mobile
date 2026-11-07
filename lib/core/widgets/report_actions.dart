import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ReportActions extends StatelessWidget {
  final String title;
  final String content;
  final String previewLabel;
  const ReportActions({
    super.key,
    required this.title,
    required this.content,
    this.previewLabel = 'Detailed Report',
  });

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject();
    try {
      await SharePlus.instance.share(
        ShareParams(
          subject: title,
          text: content,
          sharePositionOrigin: box is RenderBox
              ? box.localToGlobal(Offset.zero) & box.size
              : null,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sharing is unavailable. Open the detailed report to copy its text.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(child: SelectableText(content)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
          child: Text(previewLabel),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Builder(
          builder: (shareContext) => ElevatedButton.icon(
            onPressed: () => _share(shareContext),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Share Report'),
          ),
        ),
      ),
    ],
  );
}
