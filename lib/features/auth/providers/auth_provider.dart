import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_streak/features/auth/data/auth_repository.dart';
import 'package:gym_streak/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final userProfileProvider = StreamProvider.family<UserModel?, String>((
  ref,
  uid,
) {
  return ref.watch(authRepositoryProvider).userProfileStream(uid);
});

final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).userProfileStream(uid);
});
