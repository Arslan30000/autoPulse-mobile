import 'package:supabase_flutter/supabase_flutter.dart';

/// A missing backend keeps Bluetooth and local recordings usable offline.
class AccountService {
  static final instance = AccountService();
  SupabaseClient? _client;
  SupabaseClient? get client => _client;
  String? get userId => _client?.auth.currentUser?.id;
  String? get email => _client?.auth.currentUser?.email;
  void configure(SupabaseClient client) => _client = client;

  Future<void> signIn(String email, String password) async {
    if (_client == null) throw StateError('Cloud storage is not configured.');
    await _client!.auth.signInWithPassword(email: email, password: password);
  }

  /// Email confirmation may mean registration succeeds without signing in.
  Future<bool> signUp(String email, String password) async {
    if (_client == null) throw StateError('Cloud storage is not configured.');
    final result = await _client!.auth.signUp(email: email, password: password);
    return result.session != null;
  }

  Future<void> signOut() async {
    await _client?.auth.signOut(scope: SignOutScope.local);
  }
}
