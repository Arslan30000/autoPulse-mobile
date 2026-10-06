import 'package:flutter/material.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/screens/auth/login_screen.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:autopulse_ai/services/recording_sync_service.dart';

/// Shared by history and details so uploading never depends on discovering a
/// second screen. An unconfigured build explains setup instead of hiding action.
class TripUploadButton extends StatefulWidget {
  final ObdRecording recording;
  final RecordingSyncService? sync;
  final Future<void> Function() onChanged;
  const TripUploadButton({
    super.key,
    required this.recording,
    this.sync,
    required this.onChanged,
  });

  @override
  State<TripUploadButton> createState() => _TripUploadButtonState();
}

class _TripUploadButtonState extends State<TripUploadButton> {
  bool _requesting = false;

  Future<void> _upload() async {
    final sync = widget.sync;
    if (sync == null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cloud upload unavailable'),
          content: const Text(
            'Supabase is not enabled in this app build. Use a build configured for cloud storage, then sign in to upload this trip. Your recording is saved on this phone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _requesting = true);
    try {
      if (AccountService.instance.userId == null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(returnToCaller: true),
          ),
        );
        if (!mounted) return;
        await widget.onChanged();
        if (!mounted || AccountService.instance.userId == null) return;
      }
      if (widget.recording.ownerId == null) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Assign and upload this trip?'),
            content: Text(
              'This offline trip will be permanently assigned to ${AccountService.instance.email ?? 'your account'}. Its vehicle and samples will be uploaded to your private Supabase history.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Upload trip'),
              ),
            ],
          ),
        );
        if (!mounted || confirmed != true) return;
      }
      await sync.upload(widget.recording.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(sync.message ?? 'Trip uploaded to Supabase.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sync.message ?? 'Upload unavailable. Local data is safe.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _requesting = false);
        await widget.onChanged();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recording = widget.recording;
    final sync = widget.sync;
    if (recording.endedAt == null) {
      return const Text('Stop recording to upload this trip.');
    }
    if (recording.syncState == RecordingSyncState.synced) {
      return const Text('Uploaded to Supabase');
    }
    return ListenableBuilder(
      listenable: sync ?? const AlwaysStoppedAnimation(0.0),
      builder: (context, _) {
        final uploading =
            sync?.busy == true && sync?.activeRecordingId == recording.id;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (uploading) ...[
              LinearProgressIndicator(value: sync!.progress),
              const SizedBox(height: 8),
              Text(sync.message ?? 'Uploading trip...'),
            ],
            FilledButton.icon(
              onPressed: _requesting || sync?.busy == true ? null : _upload,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(
                recording.syncState == RecordingSyncState.failed
                    ? 'Retry trip upload to Supabase'
                    : 'Upload trip to Supabase',
              ),
            ),
          ],
        );
      },
    );
  }
}
