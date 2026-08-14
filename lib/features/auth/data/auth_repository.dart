import 'package:gym_streak/core/domain/app_failure.dart';
import 'package:gym_streak/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The deep link a password-recovery email opens.
///
/// Must match the scheme registered in `AndroidManifest.xml` and iOS
/// `Info.plist`, and be allow-listed in the Supabase dashboard.
const String passwordResetRedirect = 'io.supabase.gymstreak://reset-callback';

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

  /// The user's profile, live.
  ///
  /// Seeded with a direct read before following the realtime stream. Relying on
  /// realtime alone made the first paint depend on a websocket connecting and
  /// delivering a snapshot — until it did, the stream had produced nothing and
  /// the profile screen rendered "User not found" for a user who plainly
  /// existed. Realtime is also the first thing to fail on a flaky connection,
  /// and a profile should not vanish because a socket did.
  Stream<UserModel?> userProfileStream(String uid) async* {
    try {
      yield await getUserProfile(uid);
    } catch (_) {
      // The live stream below is still worth attempting.
    }

    UserModel? lastKnown;
    yield* guardFailureStream(
      _client.from('profiles').stream(primaryKey: ['id']).eq('id', uid).map((
        rows,
      ) {
        if (rows.isNotEmpty) {
          lastKnown = UserModel.fromMap(rows.first);
          return lastKnown;
        }
        // An empty emission does not mean the account is gone — realtime can
        // deliver one before it has caught up. Falling back to the last known
        // profile stops a loaded screen collapsing into an error. A genuinely
        // deleted account signs the user out, which the router handles.
        return lastKnown;
      }),
    );
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await guardFailures(
      () => _client.from('profiles').update(data).eq('id', uid),
    );
  }

  /// Emails a recovery link to [email].
  ///
  /// Succeeds even when no account exists — Supabase deliberately does not say
  /// either way, and neither should the UI, or the screen becomes a way to test
  /// whether an address is registered.
  ///
  /// [redirectTo] is the deep link the emailed button opens; it must also be
  /// listed under Supabase → Authentication → URL Configuration → Redirect URLs,
  /// or the link silently falls back to the project's Site URL.
  Future<void> sendPasswordReset(String email) async {
    await guardFailures(
      () => _client.auth.resetPasswordForEmail(
        email,
        redirectTo: passwordResetRedirect,
      ),
    );
  }

  /// Sets a new password for the session created by following a recovery link.
  Future<void> updatePassword(String newPassword) async {
    await guardFailures(
      () => _client.auth.updateUser(UserAttributes(password: newPassword)),
    );
  }

  Future<void> logout() async {
    await guardFailures(() => _client.auth.signOut());
  }
}
