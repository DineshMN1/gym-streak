import 'package:gym_streak/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Creates the auth user. The matching `profiles` row is created server-side
  /// by the `on_auth_user_created` trigger — see
  /// `supabase/migrations/20260812000300_profile_trigger.sql`.
  ///
  /// Inserting the profile from here instead would race the session: with
  /// "Confirm email" enabled `signUp` returns no session, so `auth.uid()` is
  /// NULL and the RLS insert policy rejects the write.
  ///
  /// `name` travels in the signup metadata, which is where the trigger reads it
  /// from; it is not written by this client.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );

    if (response.user == null) throw Exception('Registration failed');
  }

  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final authUser = response.user;
    if (authUser == null) throw Exception('Login failed');

    return getUserProfile(authUser.id);
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (data == null) return null;
    return UserModel.fromMap(data);
  }

  Stream<UserModel?> userProfileStream(String uid) {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((rows) {
          if (rows.isEmpty) return null;
          return UserModel.fromMap(rows.first);
        });
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _client.from('profiles').update(data).eq('id', uid);
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }
}
