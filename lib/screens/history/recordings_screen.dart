import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/widgets/obd_telemetry_chart.dart';
import 'package:autopulse_ai/core/widgets/trip_upload_button.dart';
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
  RecordingSyncState.pending => 'Queued for upload',
  RecordingSyncState.uploading => 'Uploading',
  RecordingSyncState.synced => 'Uploaded to Supabase',
  RecordingSyncState.failed => 'Upload failed',
};

String _displayTime(BuildContext context, DateTime timestamp) {
  final time = timestamp.toLocal();
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatMediumDate(time)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(time), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}

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
              'Recordings stay on this phone. Finished trips can be uploaded to your Supabase account.',
            ),
            const SizedBox(height: 12),
            if (sync == null)
              const Text(
                'Cloud upload needs a configured app build. Your trips are saved on this phone.',
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
                label: const Text('Retry queued uploads'),
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
                          '${_displayTime(context, recording.startedAt)}\n${recording.sampleCount} PID samples \u00b7 ${recording.endedAt == null ? 'Open / interrupted' : _syncLabel(recording.syncState)}',
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
                                sync: widget.sync,
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
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: TripUploadButton(
                          recording: recording,
                          sync: sync,
                          onChanged: () => _load(),
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
  final RecordingSyncService? sync;
  final ObdRecording recording;
  const RecordingDetailsScreen({
    super.key,
    required this.store,
    required this.recording,
    this.sync,
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
  bool _chartLoading = false;
  bool _olderAvailable = false;
  bool _latestWindow = true;
  late ObdRecording _recording;
  @override
  void initState() {
    super.initState();
    _recording = widget.recording;
    widget.sync?.addListener(_syncChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    widget.sync?.removeListener(_syncChanged);
    super.dispose();
  }

  void _syncChanged() {
    if (mounted && widget.sync?.busy == false) {
      unawaited(_load(reloadChart: false));
    }
  }

  Future<void> _load({bool reloadChart = true}) async {
    try {
      final recording = await widget.store.recording(_recording.id);
      final quality = reloadChart || _quality == null
          ? await analyzeRecording(widget.store, recording.id)
          : _quality!;
      if (!mounted) return;
      setState(() {
        _recording = recording;
        _quality = quality;
        _error = null;
      });
      if (reloadChart) await _loadChart();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Recording could not be read. Please retry.');
      }
    }
  }

  Future<void> _loadChart({bool older = false}) async {
    if (older && (_chartLoading || _chart.isEmpty)) return;
    final generation = ++_chartGeneration;
    final beforeId = older ? _chart.first.id : 0;
    setState(() => _chartLoading = true);
    try {
      final samples = await widget.store.chartSamples(
        _recording.id,
        _parameter,
        beforeId: beforeId,
      );
      if (mounted && generation == _chartGeneration) {
        setState(() {
          // A bounded window keeps long trips responsive; session statistics and
          // export still include every page. Time remains relative to trip start.
          if (samples.isNotEmpty || !older) {
            _chart = samples;
          }
          _olderAvailable = samples.length == 600;
          if (samples.isNotEmpty || !older) {
            _latestWindow = !older;
          }
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && generation == _chartGeneration) {
        setState(() => _error = 'Graph could not be loaded. Please retry.');
      }
    } finally {
      if (mounted && generation == _chartGeneration) {
        setState(() => _chartLoading = false);
      }
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

  @override
  Widget build(BuildContext context) {
    final quality = _quality;
    final metric = quality?[_parameter];
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
            'Adapter: ${_recording.adapterName}\nStarted: ${_displayTime(context, _recording.startedAt)}\n${_recording.sampleCount} recorded PID samples',
          ),
          if (_recording.endedAt != null)
            Text(
              'Duration: ${_recording.endedAt!.difference(_recording.startedAt).inSeconds} seconds',
            ),
          if (_recording.endedAt == null)
            const Text(
              'This session is open or was interrupted. Refresh after stopping a live recording. Cloud upload and export require a finished session.',
            ),
          const SizedBox(height: 12),
          Text(_syncLabel(_recording.syncState)),
          if (_recording.syncError != null) Text(_recording.syncError!),
          TripUploadButton(
            recording: _recording,
            sync: widget.sync,
            onChanged: () => _load(reloadChart: false),
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
              '${metric.valid}/${metric.total} valid samples \u00b7 mean latency ${metric.meanLatencyMs.toStringAsFixed(0)} ms',
            ),
            Text(
              'Observed rate: ${metric.observedHz?.toStringAsFixed(2) ?? 'unavailable'} Hz \u00b7 longest gap ${(metric.longestGap.inMilliseconds / 1000).toStringAsFixed(2)} s',
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
          if (_chartLoading) const LinearProgressIndicator(),
          if (_chart.isNotEmpty) ...[
            const SizedBox(height: 16),
            ObdTelemetryChart(
              key: ValueKey((_parameter, _chart.first.id)),
              parameter: _parameter,
              samples: _chart.map((row) => row.sample).toList(),
              timeOrigin: _recording.startedAt,
            ),
            Text(
              '${_latestWindow ? 'Latest' : 'Earlier'} ${_chart.length} readings. Missing readings and gaps over 6 seconds break the line.',
            ),
            Wrap(
              spacing: 12,
              children: [
                if (_olderAvailable)
                  TextButton(
                    onPressed: _chartLoading
                        ? null
                        : () => _loadChart(older: true),
                    child: const Text('View earlier readings'),
                  ),
                if (!_latestWindow)
                  TextButton(
                    onPressed: _chartLoading ? null : () => _loadChart(),
                    child: const Text('Return to latest readings'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Quality summary - entire saved session',
            style: TextStyle(fontSize: 18),
          ),
          if (quality != null)
            for (final entry in quality.entries)
              ListTile(
                title: Text(entry.key.label),
                subtitle: Text(
                  '${entry.value.valid}/${entry.value.total} valid \u00b7 ${entry.value.observedHz?.toStringAsFixed(2) ?? '-'} Hz \u00b7 max latency ${entry.value.maxLatencyMs} ms',
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
