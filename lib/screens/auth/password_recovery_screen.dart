import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/services/account_service.dart';

/// Recovery uses the emailed token, so it also works without app deep links.
class PasswordRecoveryScreen extends StatefulWidget {
  final String email;
  const PasswordRecoveryScreen({super.key, this.email = ''});
  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _sent = false;
  bool _verified = false;
  bool _busy = false;
  bool _hidden = true;
  String? _message;
  @override
  void dispose() {
    for (final c in [_email, _token, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final client = AccountService.instance.client;
      if (client == null) throw StateError('Account access is unavailable.');
      if (!_sent) {
        await client.auth.resetPasswordForEmail(_email.text.trim());
        if (mounted) {
          setState(() {
            _sent = true;
            _message =
                'Check your email for a recovery code. Keep this screen open.';
          });
        }
      } else {
        if (!_verified) {
          await client.auth.verifyOTP(
            email: _email.text.trim(),
            token: _token.text.trim(),
            type: OtpType.recovery,
          );
          _verified = true;
        }
        await client.auth.updateUser(UserAttributes(password: _password.text));
        if (!mounted) return;
        Navigator.pop(context);
        // A recovery token creates a session. Restart the auth screen so it
        // shows Continue for that session and restores this owner's vehicles.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated. Continue to your account.'),
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Unable to reset your password. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.lock_reset_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Get back on the road.',
                  style: AppTextStyles.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  _sent
                      ? 'Enter the recovery code from your email and choose a new password.'
                      : 'Enter your account email to request a recovery code.',
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _email,
                  enabled: !_busy && !_sent,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) =>
                      v != null &&
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v.trim())
                      ? null
                      : 'Enter a valid email address.',
                ),
                if (_sent) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _token,
                    enabled: !_busy && !_verified,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    decoration: const InputDecoration(
                      labelText: 'Recovery code',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter the code from your email.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: _hidden,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'New password',
                      helperText: 'Use at least 8 characters.',
                      suffixIcon: IconButton(
                        tooltip: _hidden ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _hidden = !_hidden),
                        icon: Icon(
                          _hidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) => v == null || v.length < 8
                        ? 'Use at least 8 characters.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirm,
                    enabled: !_busy,
                    obscureText: _hidden,
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                    ),
                    validator: (v) =>
                        v != _password.text || v == null || v.isEmpty
                        ? 'Passwords must match.'
                        : null,
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _sent = false;
                            _verified = false;
                            _token.clear();
                            _message = null;
                          }),
                    child: const Text('Request another code'),
                  ),
                ],
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Semantics(liveRegion: true, child: Text(_message!)),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_sent ? 'Update password' : 'Send recovery code'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
