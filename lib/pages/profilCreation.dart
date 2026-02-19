import 'package:flutter/material.dart';
import 'package:WeighTracker/models/user_profile.dart';

class ProfilCreationPage extends StatefulWidget {
  final UserProfile? existingProfile;

  const ProfilCreationPage({super.key, this.existingProfile});

  @override
  State<ProfilCreationPage> createState() => _ProfilCreationPageState();
}

class _ProfilCreationPageState extends State<ProfilCreationPage> {
  // Page and form to create or edit a user profile.
  // Collects name, height, weight, and goal; validates and saves.
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _goalController = TextEditingController();

  bool get _isEditing => widget.existingProfile != null;

  @override
  void initState() {
    super.initState();
    // If editing, prefill fields with existing values.
    if (_isEditing) {
      final p = widget.existingProfile!;
      _nameController.text = p.name;
      _heightController.text = p.height.toString();
      _weightController.text = p.weight.toString();
      _goalController.text = p.goalWeight.toString();
    }
  }

  String _cleanNumber(String raw) {
    // Clean numeric input ("," -> ".", remove non-numeric characters).
    return raw.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.-]'), '');
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
    // Validate and save the profile (create or update).
    final name = _nameController.text.trim();
    final height = _parseInt(_heightController.text);
    final weight = _parseDouble(_weightController.text);
    final goal = _parseDouble(_goalController.text);

    if (name.isEmpty || height == null || weight == null || goal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields correctly'),
        ),
      );
      return;
    }

    final profile = UserProfile(
      id: _isEditing ? widget.existingProfile!.id : UserProfile.generateId(),
      name: name,
      height: height,
      weight: weight,
      goalWeight: goal,
    );

    await profile.save();

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit profile' : 'Create profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Form(
          key: _formKey,
          child: ListView(
            children:
                [
                  // Header and short description for the page.
                  Text(
                    _isEditing ? 'Profile information' : 'New profile',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You can add weigh-ins later.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Height in cm (e.g. 175)',
                      prefixIcon: Icon(Icons.height),
                    ),
                  ),
                ] +
                (_isEditing
                    ? []
                    : [
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _weightController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Current weight (kg)',
                            prefixIcon: Icon(Icons.monitor_weight_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _goalController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Goal weight (kg)',
                            prefixIcon: Icon(Icons.flag_outlined),
                          ),
                        ),
                      ]) +
                [
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _saveProfile,
                      child: Text(
                        _isEditing
                            ? 'Save changes'
                            : 'Create profile',
                      ),
                    ),
                  ),
                ],
          ),
        ),
      ),
    );
  }
}
