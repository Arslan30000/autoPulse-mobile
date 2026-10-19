import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/core/widgets/brand_mark.dart';
import 'package:autopulse_ai/screens/auth/password_recovery_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autopulse_ai/navigation/app_router.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/services/account_data_service.dart';

class LoginScreen extends StatefulWidget {
  final bool returnToCaller;
  const LoginScreen({super.key, this.returnToCaller = false});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _account = AccountService.instance;
  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _busy = false;
  bool _register = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() => _busy = true);
    try {
      final vehicle = await AccountDataService.instance.restoreSelection();
      if (!mounted) return;
      if (_account.userId != null &&
          vehicle == null &&
          AccountDataService.instance.resolvedOwner != _account.userId) {
        setState(
          () => _message = 'Your account is signed in, but we could not load your cars. Retry when connected, or sign out to continue offline.',
        );
        return;
      }
      if (widget.returnToCaller && vehicle != null) {
        Navigator.pop(context);
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          vehicle == null ? AppRouter.addVehicle : AppRouter.main,
          (_) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Unable to load saved data. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
          ? await _account.signUp(
              _email.text.trim(),
              _password.text,
              displayName: _name.text,
            )
          : await _account
                .signIn(_email.text.trim(), _password.text)
                .then((_) => true);
      if (!mounted) return;
      if (signedIn) {
        await _continue();
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

  void _mode(bool register) {
    if (_busy || register == _register) return;
    _form.currentState?.reset();
    setState(() {
      _register = register;
      _message = null;
      _confirm.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.returnToCaller)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: _busy ? null : () => Navigator.pop(context),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: BrandMark(width: 192)),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: const BoxDecoration(
                    color: AppColors.tealSurface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(36),
                    ),
                  ),
                  child: AutofillGroup(
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _register
                                ? 'Your next chapter starts here.'
                                : 'Welcome back.',
                            style: AppTextStyles.headlineMedium.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign up to save your vehicles and recordings.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_account.userId == null) ...[
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppColors.background.withValues(
                                  alpha: .45,
                                ),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Row(
                                children: [
                                  _tab('Login', false),
                                  _tab('Register', true),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_register) ...[
                              TextFormField(
                                controller: _name,
                                enabled: !_busy,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                decoration: _decoration(
                                  'Your name',
                                  Icons.person_outline_rounded,
                                ),
                                validator: (value) =>
                                    value == null ||
                                        value.trim().isEmpty ||
                                        value.trim().length > 100
                                    ? 'Enter your name (up to 100 characters).'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                            ],
                            TextFormField(
                              controller: _email,
                              enabled: !_busy,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              autofillHints: const [AutofillHints.email],
                              decoration: _decoration(
                                'Email',
                                Icons.alternate_email_rounded,
                              ),
                              validator: (value) =>
                                  value == null ||
                                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                          .hasMatch(value.trim())
                                  ? 'Enter a valid email address.'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _password,
                              enabled: !_busy,
                              obscureText: _hidePassword,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: _register
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!_register &&
                                    !_busy &&
                                    _account.client != null) {
                                  _submit();
                                }
                              },
                              autofillHints: [
                                _register
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              decoration:
                                  _decoration(
                                    'Password',
                                    Icons.lock_outline_rounded,
                                  ).copyWith(
                                    helperText: _register
                                        ? 'Use at least 8 characters.'
                                        : null,
                                    suffixIcon: IconButton(
                                      tooltip: _hidePassword
                                          ? 'Show password'
                                          : 'Hide password',
                                      onPressed: () => setState(
                                        () => _hidePassword = !_hidePassword,
                                      ),
                                      icon: Icon(
                                        _hidePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                              validator: (value) =>
                                  value == null ||
                                      value.isEmpty ||
                                      (_register && value.length < 8)
                                  ? 'Enter a password${_register ? ' of at least 8 characters' : ''}.'
                                  : null,
                            ),
                            if (_register) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _confirm,
                                enabled: !_busy,
                                obscureText: _hideConfirm,
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  if (!_busy && _account.client != null) {
                                    _submit();
                                  }
                                },
                                decoration:
                                    _decoration(
                                      'Confirm password',
                                      Icons.lock_outline_rounded,
                                    ).copyWith(
                                      suffixIcon: IconButton(
                                        tooltip: _hideConfirm
                                            ? 'Show confirmation'
                                            : 'Hide confirmation',
                                        onPressed: () => setState(
                                          () => _hideConfirm = !_hideConfirm,
                                        ),
                                        icon: Icon(
                                          _hideConfirm
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                      ),
                                    ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Confirm your password.'
                                    : value != _password.text
                                    ? 'Passwords do not match.'
                                    : null,
                              ),
                            ] else
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _busy || _account.client == null
                                      ? null
                                      : () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  PasswordRecoveryScreen(
                                                    email: _email.text.trim(),
                                                  ),
                                            ),
                                          );
                                          if (mounted) setState(() {});
                                        },
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.textPrimary,
                                  ),
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                            const SizedBox(height: 24),
                            if (_account.client == null) ...[
                              const Text(
                                'Account access is unavailable in this offline build. You can still use the app without an account.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            FilledButton(
                              onPressed: _busy || _account.client == null
                                  ? null
                                  : _submit,
                              child: _busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _register ? 'Create account' : 'Sign in',
                                    ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _busy ? null : () => _mode(!_register),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                              ),
                              child: Text(
                                _register
                                    ? 'Already registered? Sign in'
                                    : 'Create an account',
                              ),
                            ),
                          ] else ...[
                            Text(
                              'Signed in as ${_account.email ?? 'vehicle owner'}',
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _busy ? null : _continue,
                              child: const Text('Continue'),
                            ),
                            TextButton(
                              onPressed: _busy ? null : _signOut,
                              child: const Text('Sign out'),
                            ),
                          ],
                          if (_message != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  _message!,
                                  style: const TextStyle(height: 1.5),
                                ),
                              ),
                            ),
                          if (_account.userId == null) ...[
                            const SizedBox(height: 8),
                            const Divider(color: AppColors.borderLight),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _busy ? null : _continue,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                              ),
                              child: const Text('Continue without an account'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _tab(String label, bool register) => Expanded(
    child: Semantics(
      selected: _register == register,
      child: TextButton(
        onPressed: _busy ? null : () => _mode(register),
        style: TextButton.styleFrom(
          backgroundColor: _register == register
              ? AppColors.background
              : Colors.transparent,
          foregroundColor: _register == register
              ? AppColors.textPrimary
              : AppColors.textSecondary,
          minimumSize: const Size(48, 46),
          textStyle: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        child: Text(label),
      ),
    ),
  );

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20),
    filled: true,
    fillColor: AppColors.background.withValues(alpha: .35),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  );
}
