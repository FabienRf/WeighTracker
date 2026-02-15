import 'package:flutter/material.dart';
import 'package:flutter_weightrack/models/user_profile.dart';
import 'package:flutter_weightrack/pages/profilCreation.dart';
import 'package:flutter_weightrack/pages/home.dart';

class ProfileSelectionPage extends StatefulWidget {
  const ProfileSelectionPage({super.key});

  @override
  State<ProfileSelectionPage> createState() => _ProfileSelectionPageState();
}

class _ProfileSelectionPageState extends State<ProfileSelectionPage> {
  List<UserProfile> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await UserProfile.loadAll();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _loading = false;
    });
  }

  Future<void> _selectProfile(UserProfile profile) async {
    await profile.setActive();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  Future<void> _deleteProfile(UserProfile profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le profil'),
        content: Text(
          'Voulez-vous vraiment supprimer le profil "${profile.name}" ?\n'
          'Toutes les données de poids associées seront supprimées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await profile.delete();
      _loadProfiles();
    }
  }

  Future<void> _editProfile(UserProfile profile) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilCreationPage(existingProfile: profile),
      ),
    );
    _loadProfiles();
  }

  Future<void> _addProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilCreationPage()),
    );
    _loadProfiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sélection du profil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'Aucun profil.\nCréez-en un pour commencer !',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _profiles.length,
              itemBuilder: (context, index) {
                final profile = _profiles[index];
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color.fromARGB(255, 197, 40, 90),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    profile.name,
                    style: const TextStyle(fontSize: 18),
                  ),
                  subtitle: Text(
                    '${profile.weight} kg — Objectif: ${profile.goalWeight} kg',
                  ),
                  onTap: () => _selectProfile(profile),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editProfile(profile);
                      } else if (value == 'delete') {
                        _deleteProfile(profile);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Modifier'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Supprimer',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProfile,
        backgroundColor: const Color.fromARGB(255, 197, 40, 90),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
