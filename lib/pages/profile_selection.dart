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
  // Liste des profils disponibles et indicateur de chargement.
  List<UserProfile> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    // Charge tous les profils sauvegardés puis met à jour l'état.
    final profiles = await UserProfile.loadAll();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _loading = false;
    });
  }

  Future<void> _selectProfile(UserProfile profile) async {
    // Définit le profil choisi comme actif et ouvre la page principale.
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
      // Supprime le profil sélectionné puis recharge la liste.
      await profile.delete();
      _loadProfiles();
    }
  }

  Future<void> _editProfile(UserProfile profile) async {
    // Ouvre la page de modification, puis recharge la liste au retour.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilCreationPage(existingProfile: profile),
      ),
    );
    _loadProfiles();
  }

  Future<void> _addProfile() async {
    // Ouvre la page de création de profil, puis recharge la liste.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilCreationPage()),
    );
    _loadProfiles();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sélection du profil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'Aucun profil.\nCréez-en un pour commencer !',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: _profiles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final profile = _profiles[index];
                // Carte résumant un profil avec actions (sélection/éditer/supprimer).
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      child: const Icon(Icons.person),
                    ),
                    title: Text(profile.name, style: textTheme.titleMedium),
                    subtitle: Text(
                      '${profile.weight.toStringAsFixed(1)} kg — Objectif: ${profile.goalWeight.toStringAsFixed(1)} kg',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
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
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete,
                                size: 20,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Supprimer',
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProfile,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
