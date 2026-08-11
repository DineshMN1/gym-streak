import 'package:flutter/material.dart';
import 'package:gym_streak/core/theme/app_theme.dart';
import 'package:gym_streak/supabase_config.dart';

/// Standalone app shown when the build carries no usable Supabase credentials.
///
/// Owns its own [MaterialApp] because it is handed straight to `runApp` before
/// the real app (and its router and ProviderScope) is ever constructed.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.status});

  final ConfigStatus status;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Streak',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(body: ConfigErrorScreen(status: status)),
    );
  }
}

/// The content of [ConfigErrorApp], separated so it can be widget-tested
/// inside the shared harness without nesting two [MaterialApp]s.
class ConfigErrorScreen extends StatelessWidget {
  const ConfigErrorScreen({super.key, required this.status});

  final ConfigStatus status;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.settings_suggest_rounded,
                size: 56,
                color: AppColors.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Configuration required',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                status.message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Copy env.example.json to env.json, fill in your project '
                      'URL and anon key, then run:',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      SupabaseConfig.runCommand,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'See README.md for full setup instructions.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
