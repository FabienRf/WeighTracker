import 'package:flutter/material.dart';
import 'package:flutter_weightrack/models/user_profile.dart';
import 'package:flutter_weightrack/pages/home.dart';

class ProfilCreationPage extends StatefulWidget {
  const ProfilCreationPage({super.key});

  @override
  State<ProfilCreationPage> createState() => _ProfilCreationPageState();
}

class _ProfilCreationPageState extends State<ProfilCreationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _goalController = TextEditingController();

  String _cleanNumber(String raw) {
    return raw.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.\-]'), '');
  }

  double? _parseDouble(String raw) {
    final s = _cleanNumber(raw);
    if (s.isEmpty) return null;
    try {
      return double.parse(s);
    } catch (_) {
      return null;
    }
  }

  int? _parseInt(String raw) {
    final s = _cleanNumber(raw);
    if (s.isEmpty) return null;
    try {
      return int.parse(s.split('.').first);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final height = _parseInt(_heightController.text);
    final weight = _parseDouble(_weightController.text);
    final goal = _parseDouble(_goalController.text);

    if (name.isEmpty || height == null || weight == null || goal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs correctement'),
        ),
      );
      return;
    }

    final profile = UserProfile(
      name: name,
      height: height,
      weight: weight,
      goalWeight: goal,
    );

    await profile.save();

    // Navigate to Home and replace this page
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer votre profil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Taille en cm (ex: 175)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Poids actuel (kg)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _goalController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Objectif de poids (kg)',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveProfile,
                child: const Text('Enregistrer le profil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
