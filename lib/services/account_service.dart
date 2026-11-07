import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stable application account IDs survive a change of authentication provider.
class AccountService {
  static final instance = AccountService();
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  SupabaseClient? _client;
  SupabaseClient? _legacyClient;
  firebase.FirebaseAuth? _firebase;
  StreamSubscription<Object?>? _subscription;
  String? _accountId;
  String? _resolvedSubject;
  SupabaseClient? get client => _client;
  bool get usesFirebase => _firebase != null;
  bool get needsVerification => _firebase?.currentUser?.emailVerified == false;
  bool get hasPendingIdentity =>
      usesFirebase && _firebase?.currentUser != null && _accountId == null;
  String? get userId =>
      usesFirebase ? _accountId : _client?.auth.currentUser?.id;
  String? get email => usesFirebase
      ? _firebase?.currentUser?.email
      : _client?.auth.currentUser?.email;
  String get displayName => usesFirebase
      ? _firebase?.currentUser?.displayName ?? ''
      : _client?.auth.currentUser?.userMetadata?['display_name'] as String? ??
            '';

  /// Legacy mode remains available for compatibility tests and rollback builds.
  void configure(SupabaseClient? client) {
    unawaited(_subscription?.cancel());
    _firebase = null;
    _accountId = null;
    _client = client;
    _subscription = client?.auth.onAuthStateChange.listen(
      (_) => _changes.add(null),
    );
  }

  Future<void> configureFirebase(
    firebase.FirebaseAuth auth,
    SupabaseClient client,
    SupabaseClient legacyClient,
  ) async {
    await _subscription?.cancel();
    _firebase = auth;
    _client = client;
    _legacyClient = legacyClient;
    final user = auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    // Cached identity opens this user's local data offline. All cloud access
    // still requires a valid signed token and backend ownership checks.
    _resolvedSubject = user?.uid;
    _accountId = user != null && user.emailVerified
        ? prefs.getString('account.firebase.${user.uid}')
        : null;
    _subscription = auth.idTokenChanges().listen((current) {
      if (current?.uid != _resolvedSubject || current?.emailVerified != true) {
        _accountId = null;
        _resolvedSubject = current?.uid;
      }
      _changes.add(null);
    });
  }

  /// Firebase can reopen with an older cached verification flag. Refresh it
  /// once before choosing the startup route, then recover the existing owner
  /// mapping from Supabase when this installation has no local cache yet.
  Future<void> restoreVerifiedSession() async {
    final auth = _firebase;
    if (auth == null || auth.currentUser == null) return;
    try {
      if (auth.currentUser?.emailVerified != true) {
        await auth.currentUser!.reload().timeout(const Duration(seconds: 8));
      }
      if (auth.currentUser?.emailVerified == true && _accountId == null) {
        await _resolve().timeout(const Duration(seconds: 15));
      }
    } on AuthException {
      // An old unlinked account still needs its previous password in sign-in.
    } catch (_) {
      // The existing SQLite cache and offline navigation remain available.
    }
  }

  Future<void> _resolve({String? previousPassword}) async {
    final auth = _firebase!;
    final user = auth.currentUser;
    if (user == null || !user.emailVerified) {
      throw const AuthException(
        'Check your email and verify it before signing in.',
      );
    }
    await user.getIdToken(true);
    Object? result;
    try {
      result = await _client!.rpc('resolve_firebase_account');
    } on PostgrestException catch (error) {
      if (!error.message.contains('LEGACY_LINK_REQUIRED')) rethrow;
      if (previousPassword == null || previousPassword.isEmpty) {
        throw const AuthException(
          'To restore your existing cars and runs, enter your previous AutoPulseAI password below.',
        );
      }
      final legacy = _legacyClient!;
      try {
        await legacy.auth.signInWithPassword(
          email: user.email!,
          password: previousPassword,
        );
        final ticket = await legacy.rpc('create_account_link');
        result = await _client!.rpc(
          'resolve_firebase_account',
          params: {'link_ticket': ticket},
        );
      } on AuthException {
        throw const AuthException(
          'Previous account password did not match. Your saved data has not been changed.',
        );
      } finally {
        await legacy.auth.signOut(scope: SignOutScope.local);
      }
    }
    if (auth.currentUser?.uid != user.uid) throw StateError('Account changed.');
    final id = result as String;
    await (await SharedPreferences.getInstance()).setString(
      'account.firebase.${user.uid}',
      id,
    );
    _resolvedSubject = user.uid;
    _accountId = id;
    _changes.add(null);
  }

  Future<void> signIn(String email, String password) async {
    if (_client == null) {
      throw const AuthException('Cloud storage is not configured.');
    }
    if (!usesFirebase) {
      await _client!.auth.signInWithPassword(email: email, password: password);
      return;
    }
    try {
      await _firebase!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on firebase.FirebaseAuthException catch (error) {
      throw AuthException(_friendly(error));
    }
    await _resolve(previousPassword: password);
  }

  Future<bool> signUp(
    String email,
    String password, {
    String displayName = '',
  }) async {
    if (_client == null) {
      throw const AuthException('Cloud storage is not configured.');
    }
    if (!usesFirebase) {
      final result = await _client!.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName.trim()},
      );
      return result.session != null;
    }
    try {
      final result = await _firebase!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await result.user!.updateDisplayName(displayName.trim());
      await result.user!.sendEmailVerification();
      return false;
    } on firebase.FirebaseAuthException catch (error) {
      throw AuthException(_friendly(error));
    }
  }

  Future<void> resendVerification() async {
    try {
      await _firebase?.currentUser?.sendEmailVerification();
    } on firebase.FirebaseAuthException catch (error) {
      throw AuthException(_friendly(error));
    }
  }

  Future<void> refreshVerification({String? previousPassword}) async {
    try {
      await _firebase?.currentUser?.reload();
    } on firebase.FirebaseAuthException catch (error) {
      throw AuthException(_friendly(error));
    }
    await _resolve(previousPassword: previousPassword);
  }

  Future<void> sendPasswordReset(String email) async {
    if (!usesFirebase) {
      await _client!.auth.resetPasswordForEmail(email);
      return;
    }
    try {
      await _firebase!.sendPasswordResetEmail(email: email);
    } on firebase.FirebaseAuthException catch (error) {
      throw AuthException(_friendly(error));
    }
  }

  Future<void> signOut() async {
    if (usesFirebase) {
      await _firebase!.signOut();
      _accountId = null;
    } else {
      await _client?.auth.signOut(scope: SignOutScope.local);
    }
    _changes.add(null);
  }

  Future<void> updateName(String name) async {
    if (_client == null || userId == null) {
      throw StateError('Sign in to update your profile.');
    }
    if (usesFirebase) {
      await _firebase!.currentUser!.updateDisplayName(name.trim());
      await _client!
          .from('profiles')
          .update({
            'display_name': name.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId!);
    } else {
      await _client!.auth.updateUser(
        UserAttributes(data: {'display_name': name.trim()}),
      );
    }
  }

  String _friendly(firebase.FirebaseAuthException error) =>
      switch (error.code) {
        'invalid-credential' || 'user-not-found' || 'wrong-password' => 'Email or password did not match. Existing AutoPulseAI users: create a verified account once with the same email, then link your previous account.',
        'email-already-in-use' =>
          'This email is registered. Sign in or reset your password.',
        'weak-password' => 'Choose a password with at least 8 characters.',
        'too-many-requests' =>
          'Too many requests. Wait a few minutes before trying again.',
        'network-request-failed' =>
          'No internet connection. You can continue offline.',
        _ => error.message ?? 'Account request failed. Please retry.',
      };
}
