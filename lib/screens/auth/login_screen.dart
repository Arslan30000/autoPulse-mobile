import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autopulse_ai/navigation/app_router.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';
import 'package:autopulse_ai/models/vehicle.dart';

class LoginScreen extends StatefulWidget {
  final bool returnToCaller;
  const LoginScreen({super.key, this.returnToCaller = false});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _account = AccountService.instance;
  bool _busy = false;
  bool _register = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _continue() {
    if (widget.returnToCaller) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, AppRouter.addVehicle);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final signedIn = _register
          ? await _account.signUp(_email.text.trim(), _password.text)
          : await _account
                .signIn(_email.text.trim(), _password.text)
                .then((_) => true);
      if (!mounted) return;
      if (signedIn) {
        _continue();
      } else {
        setState(() {
          _message =
              'Check your email to confirm your account, then sign in here.';
          _register = false;
        });
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Unable to connect. Check your internet connection and try again.',
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
      ObdController.instance.setVehicle(
        const Vehicle(make: 'Vehicle', model: '', year: 2020),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Sign out failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cloud account')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.cloud_outlined, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Back up your OBD recordings',
                  style: TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bluetooth and local recording work without an account. Sign in to upload your recordings privately.',
                ),
                const SizedBox(height: 24),
                if (_account.client == null)
                  const Text(
                    'Cloud storage is not configured for this build. You can continue offline.',
                  )
                else if (_account.userId != null) ...[
                  Text('Signed in as ${_account.email ?? 'vehicle owner'}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _continue,
                    child: const Text('Continue'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _signOut,
                    child: const Text('Sign out'),
                  ),
                ] else ...[
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    enabled: !_busy,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) =>
                        value != null &&
                            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(value.trim())
                        ? null
                        : 'Enter a valid email.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    enabled: !_busy,
                    autofillHints: [
                      _register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) =>
                        value == null ||
                            value.isEmpty ||
                            (_register && value.length < 8)
                        ? 'Enter a password${_register ? ' of at least 8 characters' : ''}.'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_register ? 'Create account' : 'Sign in'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _register = !_register;
                            _message = null;
                          }),
                    child: Text(
                      _register
                          ? 'Already registered? Sign in'
                          : 'Create an account',
                    ),
                  ),
                ],
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(_message!),
                  ),
                if (_busy) const Center(child: CircularProgressIndicator()),
                if (_account.userId == null)
                  TextButton(
                    onPressed: _busy ? null : _continue,
                    child: const Text('Continue offline'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
