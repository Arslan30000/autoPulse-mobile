import 'package:flutter/material.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:autopulse_ai/services/account_data_service.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';
import 'package:autopulse_ai/navigation/app_router.dart';
import 'package:autopulse_ai/screens/auth/login_screen.dart';
import 'package:autopulse_ai/screens/vehicle/vehicles_screen.dart';
import 'package:autopulse_ai/screens/history/recordings_screen.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/recording_sync_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _data = AccountDataService.instance;
  final _account = AccountService.instance;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _data.addListener(_refresh);
    ObdController.instance.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _data.removeListener(_refresh);
    ObdController.instance.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _login() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(returnToCaller: true),
      ),
    );
    _refresh();
  }

  Future<void> _editName() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _ProfileNameDialog(initialValue: _account.displayName),
    );
    if (name == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _account.updateName(name);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not update profile. Check your connection and retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await ObdController.instance.disconnect();
      await _account.signOut();
      await _data.restoreSelection(cloud: false);
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRouter.login,
          (_) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign out failed. Please retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final obd = ObdController.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(
                _account.displayName.isNotEmpty
                    ? _account.displayName
                    : 'Vehicle owner',
              ),
              subtitle: Text(
                _account.email ?? 'Offline mode — saved on this phone',
              ),
              trailing: _account.userId != null
                  ? IconButton(
                      onPressed: _busy ? null : _editName,
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit profile',
                    )
                  : null,
            ),
          ),
          if (_account.userId == null)
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Sign in or create account'),
              onTap: _login,
            ),
          ListTile(
            leading: const Icon(Icons.directions_car),
            title: const Text('My cars / Add car'),
            subtitle: Text(
              obd.vehicle.id == null
                  ? 'No car selected'
                  : obd.vehicle.fullDisplayName,
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const VehiclesScreen()),
              );
              _refresh();
            },
          ),
          ListTile(
            leading: const Icon(Icons.bluetooth),
            title: const Text('OBD-II connection'),
            subtitle: Text(obd.isReady ? 'Connected' : 'Connect from Live'),
            onTap: () => Navigator.pushNamed(context, AppRouter.live),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Saved runs'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => RecordingsScreen(
                  store: obd.repository as RecordingStore,
                  sync: RecordingSyncService.instance,
                ),
              ),
            ),
          ),
          if (_account.userId != null) ...[
            ListTile(
              leading: _data.busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_sync),
              title: const Text('Sync cars and runs'),
              subtitle: Text(
                _data.message ??
                    'Completed account runs back up automatically when online.',
              ),
              onTap: _data.busy ? null : _data.synchronize,
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              subtitle: const Text('Your saved phone data is kept.'),
              onTap: _busy ? null : _signOut,
            ),
          ],
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Data and privacy'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Your recording data'),
                content: const Text(
                  'Bluetooth recording works offline. Cars and completed runs created while signed in back up to your private account when connected. Older offline runs stay on this phone until you explicitly upload them from Saved runs. Signing out keeps local data; another account cannot access your account runs. Cloud restoration downloads uploaded runs for offline viewing. Export a run before uninstalling the app or clearing its storage.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About AutoPulseAI'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'AutoPulseAI',
              applicationVersion: '1.0.0',
              children: [
                const Text(
                  'Vehicle diagnostics and local OBD-II recording for owners.',
                ),
              ],
            ),
          ),
          if (_busy) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class _ProfileNameDialog extends StatefulWidget {
  final String initialValue;
  const _ProfileNameDialog({required this.initialValue});
  @override
  State<_ProfileNameDialog> createState() => _ProfileNameDialogState();
}

class _ProfileNameDialogState extends State<_ProfileNameDialog> {
  late final _input = TextEditingController(text: widget.initialValue);
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit profile'),
    content: TextField(
      controller: _input,
      maxLength: 100,
      decoration: const InputDecoration(labelText: 'Your name'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_input.text.trim().isNotEmpty) {
            Navigator.pop(context, _input.text.trim());
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}
