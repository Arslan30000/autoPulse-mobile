import 'package:supabase_flutter/supabase_flutter.dart';

/// A missing backend keeps Bluetooth and local recordings usable offline.
class AccountService {
  static final instance = AccountService();
  SupabaseClient? _client;
  SupabaseClient? get client => _client;
  String? get userId => _client?.auth.currentUser?.id;
  String? get email => _client?.auth.currentUser?.email;
  String get displayName =>
      _client?.auth.currentUser?.userMetadata?['display_name'] as String? ?? '';
  void configure(SupabaseClient? client) => _client = client;

  Future<void> signIn(String email, String password) async {
    if (_client == null) throw StateError('Cloud storage is not configured.');
    await _client!.auth.signInWithPassword(email: email, password: password);
  }

  /// Email confirmation may mean registration succeeds without signing in.
  Future<bool> signUp(
    String email,
    String password, {
    String displayName = '',
  }) async {
    if (_client == null) throw StateError('Cloud storage is not configured.');
    final result = await _client!.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName.trim()},
    );
    return result.session != null;
  }

  Future<void> signOut() async {
    await _client?.auth.signOut(scope: SignOutScope.local);
  }

  Future<void> updateName(String name) async {
    if (_client == null || userId == null) {
      throw StateError('Sign in to update your profile.');
    }
    await _client!.auth.updateUser(
      UserAttributes(data: {'display_name': name.trim()}),
    );
  }
}
