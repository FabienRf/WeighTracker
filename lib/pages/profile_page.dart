import 'package:flutter/material.dart';
import 'package:WeighTracker/models/user_profile.dart';
import 'package:WeighTracker/pages/profile_selection.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    // Clear active profile and return to selection screen.
    await UserProfile.clear();

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ProfileSelectionPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: UserProfile.loadActive(),
      builder: (context, snap) {
        final profile = snap.data;
        final textTheme = Theme.of(context).textTheme;
        final colorScheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show active profile details (name, height, weight, goal).
                Text('Name', style: textTheme.labelLarge),
                Text(profile?.name ?? '-', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Height', style: textTheme.labelLarge),
                Text(
                  '${profile?.height ?? '-'} cm',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Weight', style: textTheme.labelLarge),
                Text(
                  '${profile?.weight ?? '-'} kg',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Goal', style: textTheme.labelLarge),
                Text(
                  '${profile?.goalWeight ?? '-'} kg',
                  style: textTheme.titleMedium,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => _logout(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                    child: const Text('Switch profile'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
