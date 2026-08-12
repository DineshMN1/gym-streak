import 'package:gym_streak/core/domain/app_failure.dart';
import 'package:gym_streak/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  /// The client is injected rather than read from [Supabase.instance] so this
  /// class can be constructed — and therefore tested — without a fully
  /// initialised Supabase.
  AuthRepository(this._client);

  final SupabaseClient _client;

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
    final response = await guardFailures(
      () => _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      ),
    );

    if (response.user == null) throw const UnknownFailure();
  }

  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    final response = await guardFailures(
      () => _client.auth.signInWithPassword(email: email, password: password),
    );

    final authUser = response.user;
    if (authUser == null) throw const InvalidCredentials();

    return getUserProfile(authUser.id);
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final data = await guardFailures(
      () => _client.from('profiles').select().eq('id', uid).maybeSingle(),
    );
    if (data == null) return null;
    return UserModel.fromMap(data);
  }

  Stream<UserModel?> userProfileStream(String uid) {
    return guardFailureStream(
      _client.from('profiles').stream(primaryKey: ['id']).eq('id', uid).map((
        rows,
      ) {
        if (rows.isEmpty) return null;
        return UserModel.fromMap(rows.first);
      }),
    );
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await guardFailures(
      () => _client.from('profiles').update(data).eq('id', uid),
    );
  }

  Future<void> logout() async {
    await guardFailures(() => _client.auth.signOut());
  }
}
