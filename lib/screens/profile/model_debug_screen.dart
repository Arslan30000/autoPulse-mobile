import 'package:flutter/material.dart';
import 'package:autopulse_ai/services/account_service.dart';

/// Development-only view of server-side analysis. It never trains on the phone.
class ModelDebugScreen extends StatefulWidget {
  const ModelDebugScreen({super.key});

  @override
  State<ModelDebugScreen> createState() => _ModelDebugScreenState();
}

class _ModelDebugScreenState extends State<ModelDebugScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _models = [];
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _runs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final account = AccountService.instance;
    final owner = account.userId;
    final client = account.client;
    if (owner == null || client == null) {
      setState(() {
        _loading = false;
        _error = 'Sign in with a verified account to view cloud analysis.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final models = await client
          .from('ml_models')
          .select()
          .eq('owner_id', owner)
          .order('created_at', ascending: false)
          .limit(20);
      final jobs = await client
          .from('ml_jobs')
          .select()
          .eq('owner_id', owner)
          .order('queued_at', ascending: false)
          .limit(50);
      final results = await client
          .from('ml_run_results')
          .select()
          .eq('owner_id', owner)
          .order('processed_at', ascending: false)
          .limit(50);
      final runs = await client
          .from('obd_recording_sessions')
          .select('id, vehicle_name, started_at, uploaded_at')
          .eq('owner_id', owner)
          .not('uploaded_at', 'is', null)
          .order('started_at', ascending: false)
          .limit(50);
      if (!mounted || account.userId != owner) return;
      setState(() {
        _models = models;
        _jobs = jobs;
        _results = results;
        _runs = runs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Could not load model status. Check the ML migration and connection. $error';
      });
    }
  }

  String _runName(String id) {
    for (final run in _runs) {
      if (run['id'] == id) {
        return '${run['vehicle_name']} · ${run['started_at']}';
      }
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final active = _models
        .where((model) => model['status'] == 'active')
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Model diagnostics'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh model status',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) Text(_error!),
                  const Text(
                    'Development view · Results are generated in the cloud after a completed upload. A queued run is processed by the scheduled worker.',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Active baseline',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (active.isEmpty)
                    const ListTile(
                      title: Text('No baseline yet'),
                      subtitle: Text(
                        'Upload completed runs, apply the ML migration, and run the worker.',
                      ),
                    ),
                  for (final model in active)
                    Card(
                      child: ExpansionTile(
                        title: Text(
                          'Model v${model['version']} · ${model['training_windows']} training windows',
                        ),
                        subtitle: Text(
                          'Selected: ${(model['artifact'] as Map?)?['algorithm'] ?? 'unknown'}\nReference runs: ${(model['training_sessions'] as List?)?.length ?? 0} · Created: ${model['created_at']}',
                        ),
                        children: [
                          for (final candidate
                              in ((model['validation'] as Map?)?['candidates']
                                      as List? ??
                                  const []))
                            ListTile(
                              title: Text(
                                '${candidate['algorithm']}${candidate['public_prior'] == true ? ' + Kaggle prior' : ''}',
                              ),
                              subtitle: Text(
                                'Held-out MAF error: ${candidate['maf_mae_g_s']} g/s · ${candidate['alerts_per_scored_hour']} alerts/scored hour',
                              ),
                            ),
                          for (final id
                              in (model['training_sessions'] as List? ??
                                  const []))
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.analytics_outlined),
                              title: Text(_runName(id as String)),
                              subtitle: const Text('Reference training run'),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Upload processing',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_jobs.isEmpty)
                    const ListTile(title: Text('No analysis jobs yet')),
                  for (final job in _jobs)
                    ListTile(
                      leading: Icon(
                        job['status'] == 'completed'
                            ? Icons.check_circle_outline
                            : job['status'] == 'failed'
                            ? Icons.error_outline
                            : Icons.pending_outlined,
                      ),
                      title: Text(_runName(job['session_id'] as String)),
                      subtitle: Text(
                        '${job['status']} · attempt ${job['attempts']}${job['error'] == null ? '' : '\n${job['error']}'}',
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Scored recordings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_results.isEmpty)
                    const ListTile(title: Text('No processed runs yet')),
                  for (final result in _results)
                    ListTile(
                      title: Text(_runName(result['session_id'] as String)),
                      subtitle: Text(
                        '${result['status']} · ${result['valid_windows']} usable windows · ${result['excluded_windows']} excluded · ${result['alert_count']} persistent deviations',
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
