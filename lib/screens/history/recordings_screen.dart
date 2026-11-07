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
import 'package:autopulse_ai/services/account_data_service.dart';

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
  final Future<void> Function()? synchronizeAccount;
  const RecordingsScreen({
    super.key,
    required this.store,
    this.sync,
    this.synchronizeAccount,
  });
  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final List<ObdRecording> _recordings = [];
  bool _loading = false;
  bool _more = true;
  bool _refreshingCloud = false;
  bool _reloadRequested = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    widget.sync?.addListener(_syncChanged);
    AccountDataService.instance.addListener(_accountChanged);
    unawaited(_refreshCloud());
  }

  @override
  void dispose() {
    widget.sync?.removeListener(_syncChanged);
    AccountDataService.instance.removeListener(_accountChanged);
    super.dispose();
  }

  void _syncChanged() {
    if (!mounted) return;
    setState(() {});
    if (widget.sync?.busy == false) unawaited(_load());
  }

  void _accountChanged() {
    if (!mounted) return;
    setState(() {});
    if (!AccountDataService.instance.busy) unawaited(_load());
  }

  Future<void> _refreshCloud() async {
    if (_refreshingCloud) return;
    setState(() => _refreshingCloud = true);
    try {
      await _load();
      if (widget.synchronizeAccount != null) {
        await widget.synchronizeAccount!();
      } else if (AccountService.instance.userId != null) {
        await AccountDataService.instance.synchronize();
      }
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Cloud restore failed. Saved phone data is safe; tap Refresh to retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _refreshingCloud = false);
    }
  }

  Future<void> _load({bool more = false}) async {
    if (_loading) {
      if (!more) _reloadRequested = true;
      return;
    }
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
      if (mounted) {
        setState(() => _loading = false);
        if (_reloadRequested) {
          _reloadRequested = false;
          unawaited(_load());
        }
      }
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
            onPressed: _loading || _refreshingCloud ? null : _refreshCloud,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshCloud,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Signed-in runs back up automatically when online. Offline runs stay on this phone until you choose to upload them. Synced runs are restored when you sign in.',
            ),
            const SizedBox(height: 12),
            if (_refreshingCloud || AccountDataService.instance.busy)
              const LinearProgressIndicator(),
            if (AccountService.instance.userId == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Sign in with your verified account to restore its uploaded runs. Phone-only recordings appear here without signing in.',
                ),
              ),
            if (AccountService.instance.userId != null &&
                AccountDataService.instance.message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(AccountDataService.instance.message!),
              ),
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
            if (!_loading &&
                !_refreshingCloud &&
                !AccountDataService.instance.busy &&
                _recordings.isEmpty &&
                _error == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No recordings yet. Tap Refresh to restore uploaded runs, or record a session from Live.',
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
  String? _error;
  bool _exporting = false;
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
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Recording could not be read. Please retry.');
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
          Card(
            child: ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('Explore telemetry graphs'),
              subtitle: const Text(
                'Choose a recorded parameter to view its full-session graph.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecordingGraphScreen(
                    store: widget.store,
                    recording: _recording,
                  ),
                ),
              ),
            ),
          ),
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

class RecordingGraphScreen extends StatefulWidget {
  final RecordingStore store;
  final ObdRecording recording;
  final ObdParameter initialParameter;
  const RecordingGraphScreen({
    super.key,
    required this.store,
    required this.recording,
    this.initialParameter = ObdParameter.rpm,
  });

  @override
  State<RecordingGraphScreen> createState() => _RecordingGraphScreenState();
}

class _RecordingGraphScreenState extends State<RecordingGraphScreen> {
  static const _pageSize = 600;
  static const _maxPlotPoints = 1800;
  late ObdParameter _parameter = widget.initialParameter;
  List<RecordedObdSample> _samples = [];
  bool _loading = false;
  int _generation = 0;
  int _fullPointCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadGraph());
  }

  Future<void> _loadGraph() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = <RecordedObdSample>[];
      var beforeId = 0;
      while (true) {
        final page = await widget.store.chartSamples(
          widget.recording.id,
          _parameter,
          limit: _pageSize,
          beforeId: beforeId,
        );
        if (!mounted || generation != _generation) return;
        if (page.isEmpty) break;
        if (beforeId != 0 && page.first.id >= beforeId) {
          throw StateError('Graph history page did not move backwards.');
        }
        all.addAll(page);
        beforeId = page.first.id;
        if (page.length < _pageSize) break;
      }
      all.sort((a, b) => a.id.compareTo(b.id));
      final plotted = _envelope(all, _maxPlotPoints);
      if (!mounted || generation != _generation) return;
      setState(() {
        _samples = plotted;
        _fullPointCount = all.length;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () =>
              _error = 'This graph could not be loaded. Tap refresh to retry.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  List<RecordedObdSample> _envelope(
    List<RecordedObdSample> samples,
    int maximum,
  ) {
    if (samples.length <= maximum) return samples;
    final bucketSize = (samples.length / (maximum / 4)).ceil();
    final selected = <int>{};
    for (var start = 0; start < samples.length; start += bucketSize) {
      final end = (start + bucketSize).clamp(0, samples.length);
      selected.add(start);
      selected.add(end - 1);
      var minIndex = -1;
      var maxIndex = -1;
      for (var i = start; i < end; i++) {
        final sample = samples[i].sample;
        final value = sample.value;
        if (sample.status != ObdSampleStatus.valid ||
            value == null ||
            !value.isFinite) {
          continue;
        }
        if (minIndex == -1 || value < samples[minIndex].sample.value!) {
          minIndex = i;
        }
        if (maxIndex == -1 || value > samples[maxIndex].sample.value!) {
          maxIndex = i;
        }
      }
      if (minIndex >= 0) selected.add(minIndex);
      if (maxIndex >= 0) selected.add(maxIndex);
    }
    for (var i = 1; i < samples.length; i++) {
      final previous = samples[i - 1].sample;
      final current = samples[i].sample;
      final gap = current.receivedAt.difference(previous.receivedAt);
      final previousValid =
          previous.status == ObdSampleStatus.valid && previous.value != null;
      final currentValid =
          current.status == ObdSampleStatus.valid && current.value != null;
      if (previousValid != currentValid ||
          gap > const Duration(seconds: 6) ||
          gap.isNegative) {
        selected
          ..add(i - 1)
          ..add(i);
      }
    }
    final indices = selected.toList()..sort();
    return indices.map((index) => samples[index]).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Telemetry graph'),
      actions: [
        IconButton(
          tooltip: 'Refresh graph',
          onPressed: _loading ? null : _loadGraph,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, constraints) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            widget.recording.vehicleName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            '${_displayTime(context, widget.recording.startedAt)} · full session',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ObdParameter>(
            initialValue: _parameter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Recorded parameter'),
            items: ObdParameter.values
                .map(
                  (parameter) => DropdownMenuItem(
                    value: parameter,
                    child: Text('${parameter.label} (${parameter.unit})'),
                  ),
                )
                .toList(),
            onChanged: _loading
                ? null
                : (parameter) {
                    if (parameter == null) return;
                    setState(() {
                      _parameter = parameter;
                      _samples = [];
                      _fullPointCount = 0;
                    });
                    unawaited(_loadGraph());
                  },
          ),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _loadGraph, child: const Text('Retry')),
          ],
          if (!_loading && _error == null && _fullPointCount == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('No readings for this parameter in this session.'),
            ),
          if (_samples.isNotEmpty) ...[
            Text(
              '$_fullPointCount readings across the full session${_samples.length < _fullPointCount ? ' · showing ${_samples.length} peak-preserving plot points' : ''}',
            ),
            const SizedBox(height: 12),
            ObdTelemetryChart(
              key: ValueKey((_parameter, _samples.first.id, _samples.last.id)),
              parameter: _parameter,
              samples: _samples.map((row) => row.sample).toList(),
              timeOrigin: widget.recording.startedAt,
              height: (constraints.maxHeight * .58).clamp(300, 480).toDouble(),
            ),
            const SizedBox(height: 8),
            const Text(
              'The graph covers the whole recording. Missing readings and gaps over 6 seconds break the line. Tap a point for its value; pinch to zoom and drag to move through time.',
            ),
          ],
        ],
      ),
    ),
  );
}
