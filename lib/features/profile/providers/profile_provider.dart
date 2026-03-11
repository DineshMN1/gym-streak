import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_streak/features/auth/data/auth_repository.dart';
import 'package:gym_streak/features/auth/providers/auth_provider.dart';

// Re-export the relevant providers from auth for profile use
final profileAuthRepoProvider = Provider<AuthRepository>((ref) {
  return ref.watch(authRepositoryProvider);
});
