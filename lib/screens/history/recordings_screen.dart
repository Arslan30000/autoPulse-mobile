import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:autopulse_ai/services/recording_analysis.dart';
import 'package:autopulse_ai/services/recording_sync_service.dart';
import 'package:autopulse_ai/screens/auth/login_screen.dart';

String _syncLabel(RecordingSyncState state) => switch (state) {
  RecordingSyncState.local => 'Saved on phone',
  RecordingSyncState.pending => 'Queued for backup',
  RecordingSyncState.uploading => 'Backing up',
  RecordingSyncState.synced => 'Backed up',
  RecordingSyncState.failed => 'Backup failed',
};

class RecordingsScreen extends StatefulWidget {
  final RecordingStore store;
  final RecordingSyncService? sync;
  const RecordingsScreen({super.key, required this.store, this.sync});
  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final List<ObdRecording> _recordings = [];
  bool _loading = false;
  bool _more = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    widget.sync?.addListener(_syncChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    widget.sync?.removeListener(_syncChanged);
    super.dispose();
  }

  void _syncChanged() {
    if (!mounted) return;
    setState(() {});
    if (widget.sync?.busy == false) unawaited(_load());
  }

  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    final owner = AccountService.instance.userId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.store.listRecordings(
        owner,
        beforeId: more && _recordings.isNotEmpty ? _recordings.last.id : 0,
      );
      if (!mounted || AccountService.instance.userId != owner) return;
      setState(() {
        if (!more) _recordings.clear();
        _recordings.addAll(rows);
        _more = rows.length == 50;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Recordings could not be loaded. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _account() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(returnToCaller: true),
      ),
    );
    if (!mounted) return;
    setState(() => _recordings.clear());
    await _load();
  }

  Future<void> _upload(ObdRecording recording) async {
    if (AccountService.instance.userId == null) {
      await _account();
      if (!mounted || AccountService.instance.userId == null) return;
    }
    if (!mounted) return;
    if (recording.ownerId == null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Assign and back up recording?'),
          content: Text(
            'This offline recording will be assigned to ${AccountService.instance.email ?? 'your account'}. Its vehicle and samples will be uploaded to your private cloud history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Back up'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await widget.sync!.upload(recording.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.sync?.message ?? 'Upload unavailable. Local data is safe.',
            ),
          ),
        );
      }
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final sync = widget.sync;
    return Scaffold(
      appBar: AppBar(
        title: const Text('OBD recordings'),
        actions: [
          IconButton(
            tooltip: 'Cloud account',
            onPressed: sync?.busy == true ? null : _account,
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            tooltip: 'Refresh recordings',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Recordings stay on this phone. Finished sessions can be backed up to your account.',
            ),
            const SizedBox(height: 12),
            if (sync == null)
              const Text(
                'Cloud backup is unavailable in this build. Local inspection and export remain available.',
              ),
            if (sync?.message != null)
              ListTile(
                leading: sync!.busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(),
                      )
                    : const Icon(Icons.cloud_outlined),
                title: Text(sync.message!),
              ),
            if (sync != null && AccountService.instance.userId != null)
              TextButton.icon(
                onPressed: sync.busy ? null : () => sync.retryPending(),
                icon: const Icon(Icons.sync),
                label: const Text('Retry queued backups'),
              ),
            if (_error != null) Text(_error!),
            if (!_loading && _recordings.isEmpty && _error == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No recordings yet. Connect an adapter and record a session from Live.',
                ),
              ),
            for (final recording in _recordings)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(recording.vehicleName),
                        subtitle: Text(
                          '${recording.startedAt.toLocal()}\n${recording.sampleCount} PID samples Â· ${recording.endedAt == null ? 'Open / interrupted' : _syncLabel(recording.syncState)}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecordingDetailsScreen(
                                store: widget.store,
                                recording: recording,
                              ),
                            ),
                          );
                          if (mounted) await _load();
                        },
                      ),
                      if (recording.syncError != null)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(recording.syncError!),
                        ),
                      if (recording.endedAt != null &&
                          recording.syncState != RecordingSyncState.synced &&
                          sync != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: sync.busy
                                ? null
                                : () => _upload(recording),
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: Text(
                              recording.syncState == RecordingSyncState.local
                                  ? 'Back up'
                                  : 'Retry backup',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_more && !_loading && _recordings.isNotEmpty)
              TextButton(
                onPressed: () => _load(more: true),
                child: const Text('Load older recordings'),
              ),
          ],
        ),
      ),
    );
  }
}

class RecordingDetailsScreen extends StatefulWidget {
  final RecordingStore store;
  final ObdRecording recording;
  const RecordingDetailsScreen({
    super.key,
    required this.store,
    required this.recording,
  });
  @override
  State<RecordingDetailsScreen> createState() => _RecordingDetailsScreenState();
}

class _RecordingDetailsScreenState extends State<RecordingDetailsScreen> {
  Map<ObdParameter, PidQuality>? _quality;
  List<RecordedObdSample> _chart = [];
  ObdParameter _parameter = ObdParameter.rpm;
  String? _error;
  bool _exporting = false;
  int _chartGeneration = 0;
  late ObdRecording _recording;
  @override
  void initState() {
    super.initState();
    _recording = widget.recording;
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final recording = await widget.store.recording(_recording.id);
      final quality = await analyzeRecording(widget.store, recording.id);
      if (!mounted) return;
      setState(() {
        _recording = recording;
        _quality = quality;
        _error = null;
      });
      await _loadChart();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Recording could not be read. Please retry.');
      }
    }
  }

  Future<void> _loadChart() async {
    final generation = ++_chartGeneration;
    try {
      final samples = await widget.store.chartSamples(
        _recording.id,
        _parameter,
      );
      if (mounted && generation == _chartGeneration) {
        setState(() => _chart = samples);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Graph could not be loaded.');
    }
  }

  Future<void> _export(Rect origin) async {
    setState(() => _exporting = true);
    try {
      final directory = await getTemporaryDirectory();
      final file = File(
        path.join(directory.path, 'obd-${_recording.cloudId}.csv'),
      );
      final sink = file.openWrite();
      try {
        await exportRecordingCsv(widget.store, _recording, (chunk) async {
          sink.write(chunk);
          await sink.flush();
        });
      } finally {
        await sink.close();
      }
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'OBD recording: ${_recording.vehicleName}',
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not export this recording. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<FlSpot> _spots() {
    if (_chart.isEmpty) return [];
    final start = _chart.first.sample.receivedAt;
    final spots = <FlSpot>[];
    DateTime? previous;
    for (final row in _chart) {
      final sample = row.sample;
      if (previous != null &&
          sample.receivedAt.difference(previous) > const Duration(seconds: 6)) {
        spots.add(FlSpot.nullSpot);
      }
      spots.add(
        sample.status == ObdSampleStatus.valid && sample.value != null
            ? FlSpot(
                sample.receivedAt.difference(start).inMilliseconds / 1000,
                sample.value!,
              )
            : FlSpot.nullSpot,
      );
      previous = sample.receivedAt;
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final quality = _quality;
    final metric = quality?[_parameter];
    final spots = _spots();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recording details'),
        actions: [
          IconButton(
            tooltip: 'Refresh recording',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Export CSV',
              onPressed: _exporting || _recording.endedAt == null
                  ? null
                  : () {
                      final box = context.findRenderObject() as RenderBox;
                      unawaited(
                        _export(box.localToGlobal(Offset.zero) & box.size),
                      );
                    },
              icon: const Icon(Icons.ios_share),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _recording.vehicleName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            'Adapter: ${_recording.adapterName}\nStarted: ${_recording.startedAt.toLocal()}\n${_recording.sampleCount} recorded PID samples',
          ),
          if (_recording.endedAt != null)
            Text(
              'Duration: ${_recording.endedAt!.difference(_recording.startedAt).inSeconds} seconds',
            ),
          if (_recording.endedAt == null)
            const Text(
              'This session is open or was interrupted. Refresh after stopping a live recording. Cloud backup and export require a finished session.',
            ),
          const SizedBox(height: 20),
          DropdownButtonFormField<ObdParameter>(
            initialValue: _parameter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Recorded parameter'),
            items: ObdParameter.values
                .map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text('${p.label} (${p.unit})'),
                  ),
                )
                .toList(),
            onChanged: (parameter) {
              if (parameter == null) return;
              setState(() {
                _parameter = parameter;
                _chart = [];
              });
              unawaited(_loadChart());
            },
          ),
          const SizedBox(height: 20),
          if (_error != null) Text(_error!),
          if (quality == null && _error == null)
            const Center(child: CircularProgressIndicator()),
          if (metric == null && quality != null)
            const Text(
              'No samples recorded for this PID. This does not establish whether the vehicle supports it.',
            ),
          if (metric != null) ...[
            Text(
              '${metric.valid}/${metric.total} valid samples Â· mean latency ${metric.meanLatencyMs.toStringAsFixed(0)} ms',
            ),
            Text(
              'Observed rate: ${metric.observedHz?.toStringAsFixed(2) ?? 'unavailable'} Hz Â· longest gap ${(metric.longestGap.inMilliseconds / 1000).toStringAsFixed(2)} s',
            ),
            if (metric.clockDiscontinuities > 0)
              const Text(
                'Phone clock moved backwards; the update rate cannot be calculated reliably.',
              ),
            Wrap(
              spacing: 12,
              children: ObdSampleStatus.values
                  .map(
                    (s) => Chip(
                      label: Text('${s.name}: ${metric.counts[s] ?? 0}'),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (spots.any((spot) => !spot.isNull())) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      barWidth: 2,
                      dotData: FlDotData(show: spots.length == 1),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              'Latest ${_chart.length} attempts Â· ${_parameter.unit} versus elapsed seconds. Missing readings and gaps over 6 seconds break the line.',
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Quality summary â€” entire saved session',
            style: TextStyle(fontSize: 18),
          ),
          if (quality != null)
            for (final entry in quality.entries)
              ListTile(
                title: Text(entry.key.label),
                subtitle: Text(
                  '${entry.value.valid}/${entry.value.total} valid Â· ${entry.value.observedHz?.toStringAsFixed(2) ?? 'â€”'} Hz Â· max latency ${entry.value.maxLatencyMs} ms',
                ),
              ),
          const Text(
            'Rates describe observed app responses, not the ECU sampling frequency. Recording is foreground-only.',
          ),
          if (_exporting) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
