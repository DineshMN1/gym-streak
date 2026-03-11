import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_streak/features/onboarding/data/onboarding_repository.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository();
});
