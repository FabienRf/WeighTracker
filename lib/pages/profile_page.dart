import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_weightrack/models/user_profile.dart';
import 'package:flutter_weightrack/pages/profile_selection.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
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
        return Scaffold(
          appBar: AppBar(title: const Text('Profil')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nom: ${profile?.name ?? '-'}'),
                const SizedBox(height: 8),
                Text('Taille: ${profile?.height ?? '-'}'),
                const SizedBox(height: 8),
                Text('Poids: ${profile?.weight ?? '-'}'),
                const SizedBox(height: 8),
                Text('Objectif: ${profile?.goalWeight ?? '-'}'),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _logout(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Changer de profil'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
