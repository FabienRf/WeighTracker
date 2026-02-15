import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_weightrack/services/id_generator.dart';
import 'package:flutter_weightrack/models/weight_entry.dart';
import 'package:flutter_weightrack/models/user_profile.dart';
import 'package:flutter_weightrack/pages/profile_page.dart';
import 'package:flutter_weightrack/pages/profile_selection.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String get _storageKey => 'weight_entries_${_profile?.id ?? ''}';

  List<WeightEntry> _entries = [];
  late double currentWeight;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _loadProfile();
    _updateCurrentWeight();
  }

  Future<void> _loadProfile() async {
    _profile = await UserProfile.loadActive();
    if (!mounted) return;
    await _loadEntries();
    _updateCurrentWeight();
    setState(() {});
  }

  void _updateCurrentWeight() {
    if (_entries.isNotEmpty) {
      final latest = _entries.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
      currentWeight = latest.weight;
    } else {
      currentWeight = _profile?.weight ?? 0.0;
    }
  }

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _entries = decoded
            .map((e) => WeightEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _entries = [];
      }
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> _addEntryDialog() async {
    final weightController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) => AlertDialog(
          title: const Text('Ajouter une pesée'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Poids (kg)'),
              ),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (facultatif)',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Date: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        selectedDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                        );
                        dialogSetState(() {});
                      }
                    },
                    child: const Text('Choisir'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final raw = weightController.text;
                final note = noteController.text.trim();

                double weight;
                try {
                  final cleaned = raw
                      .replaceAll(',', '.')
                      .replaceAll(RegExp(r'[^0-9.\-]'), '');
                  weight = double.parse(cleaned);
                } catch (e) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Poids invalide — entrez un nombre'),
                    ),
                  );
                  return;
                }

                final id = await IdGenerator.getNextId(_profile?.id);
                final entry = WeightEntry(
                  id: id,
                  date: selectedDate,
                  weight: weight,
                  note: note,
                );
                if (!mounted) return;
                debugPrint(
                  'Adding entry id=$id, beforeIds=${_entries.map((e) => e.id).toList()}',
                );
                setState(() {
                  _entries.insert(0, entry);
                  _updateCurrentWeight();
                });
                debugPrint(
                  'Added entry id=$id, afterIds=${_entries.map((e) => e.id).toList()}',
                );
                await _saveEntries();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
    // dispose controllers after the dialog is closed
    weightController.dispose();
    noteController.dispose();
  }

  Future<void> _removeEntry(int index) async {
    setState(() {
      _entries.removeAt(index);
      _updateCurrentWeight();
    });
    await _saveEntries();
  }

  WeightEntry _getEntryById(int id) {
    return _entries.firstWhere((e) => e.id == id);
  }

  WeightEntry? _getLatestEntry() {
    if (_entries.isEmpty) return null;
    return _entries.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
  }

  double _progressPercentage() {
    if (_profile == null) return 0.0;

    final start = _profile!.weight;

    final latest = currentWeight;

    final goal = _profile!.goalWeight;
    final totalNeeded = (start - goal).abs();
    if (totalNeeded < 1e-9) return 0.0;

    final progressMade = (start - latest).abs();
    // arrondir à 1 décimale et limiter entre 0 et 100
    final percent = (progressMade / totalNeeded * 100)
        .clamp(0.0, 100.0)
        .toDouble();
    return percent.roundToDouble();
  }

  Widget _buildWeightChart() {
    try {
      final spots = <FlSpot>[];

      if (_entries.isEmpty) {
        final base = currentWeight > 0 ? currentWeight : 0.0;
        spots.add(FlSpot(0, base));
      } else {
        final sorted = List<WeightEntry>.from(_entries)
          ..sort((a, b) => a.date.compareTo(b.date));
        final firstDate = sorted.first.date;
        for (var e in sorted) {
          final x = e.date.difference(firstDate).inDays.toDouble();
          spots.add(FlSpot(x, e.weight));
        }
      }

      double minX = spots.map((s) => s.x).reduce((a, b) => a < b ? a : b);
      double maxX = spots.map((s) => s.x).reduce((a, b) => a > b ? a : b);
      double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
      double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

      if ((maxX - minX).abs() < 1e-9) maxX = minX + 1;
      final yPadding = ((maxY - minY) * 0.15).clamp(0.5, 10.0);
      minY = minY - yPadding;
      maxY = maxY + yPadding;

      DateTime startDate;
      if (_entries.isEmpty) {
        startDate = DateTime.now().subtract(const Duration(days: 2));
      } else {
        final sorted = List<WeightEntry>.from(_entries)
          ..sort((a, b) => a.date.compareTo(b.date));
        startDate = sorted.first.date;
      }

      String bottomTitle(double value) {
        final dayOffset = value.round();
        final date = startDate.add(Duration(days: dayOffset));
        return DateFormat('dd/MM').format(date);
      }

      return LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (maxX - minX) / 4 == 0 ? 1 : (maxX - minX) / 4,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    bottomTitle(value),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: ((maxY - minY) / 4) == 0 ? 1 : ((maxY - minY) / 4),
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  final step = ((maxY - minY) / 4) == 0
                      ? 1
                      : ((maxY - minY) / 4);
                  // compute the nearest index (0..4) for this value
                  final idxDouble = (value - minY) / (step == 0 ? 1 : step);
                  final idx = idxDouble.round();
                  if (idx < 0 || idx > 4) return const SizedBox.shrink();
                  final expected = minY + step * idx;
                  // accept small rounding differences (quarter step)
                  if ((value - expected).abs() <= (step * 0.25) + 1e-9) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: Text(
                        expected.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              barWidth: 3,
              dotData: FlDotData(show: true),
              color: const Color.fromARGB(255, 197, 40, 90),
            ),
          ],
        ),
      );
    } catch (e) {
      return const Center(child: Text('Erreur affichage graphique'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // Row avec nom de profil et icône
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileSelectionPage(),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            const Icon(
                              Icons.account_circle,
                              size: 22,
                              color: const Color.fromARGB(255, 197, 40, 90),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _profile?.name ?? 'WeighTrack',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Row affichant le dernier poids en grande taille
                Row(
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: Colors.black,
                        ), // Couleur par défaut
                        children: [
                          TextSpan(
                            text:
                                '${_getLatestEntry() != null ? _getLatestEntry()!.weight.toStringAsFixed(1) : _profile!.weight.toStringAsFixed(1)} ',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: 'kg',
                            style: TextStyle(
                              fontSize: 18, // Taille réduite pour "kg"
                              fontWeight: FontWeight
                                  .bold, // ou normal selon votre besoin
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Row avec le poid restant vers l'objectif(perte ou gain) à gauche et à droite le pourcentage de progression
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_profile?.weight != null && _getLatestEntry() != null)
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ), // Style par défaut
                          children: [
                            TextSpan(text: 'Restant : '),
                            TextSpan(
                              text:
                                  '${(_getLatestEntry()!.weight - _profile!.goalWeight).abs().toStringAsFixed(1)} kg',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    if (_profile?.weight != null && _getLatestEntry() != null)
                      Text(
                        'Progression: ${_progressPercentage()}%',
                        style: const TextStyle(fontSize: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row avec une barre de progression horizontale indiquant visuellement la progression vers l'objectif
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _progressPercentage() / 100.0,
                        backgroundColor: Colors.grey[300],
                        color: const Color.fromARGB(255, 197, 40, 90),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row affichant l'objectif de poids et le dernier poids enregistré en petit en dessous du poids actuel
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_profile != null)
                              const Icon(
                                Icons.flag_outlined,
                                size: 22,
                                color: Colors.green,
                              ),
                            Text(
                              '${_profile!.goalWeight} kg',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_profile != null && _getLatestEntry() != null)
                              Text(
                                '🎯 ${_getLatestEntry()!.weight.toStringAsFixed(1)} kg',
                                style: const TextStyle(fontSize: 16),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 52),

                // Row graphique linéaire montrant l'évolution du poids au fil du temps, avec des points pour chaque pesée enregistrée
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 282,
                      width: MediaQuery.of(context).size.width * 0.92,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.25),
                            spreadRadius: 4,
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Center(
                          child: SizedBox(
                            height: 340,
                            width: double.infinity,
                            child: Card(
                              elevation: 0,
                              color: Colors.transparent,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0,
                                  vertical: 4.0,
                                ),
                                child: Column(
                                  children: [
                                    // graphique (taille fixe pour éviter contraintes non bornées)
                                    SizedBox(
                                      height: 240,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Expanded(child: _buildWeightChart()),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              // add button centered across available space
                                              Expanded(
                                                child: Center(
                                                  child: SizedBox(
                                                    height: 48,
                                                    width: 48,
                                                    child: ElevatedButton(
                                                      onPressed: () =>
                                                          _addEntryDialog(),
                                                      style: ElevatedButton.styleFrom(
                                                        shape:
                                                            const CircleBorder(),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        backgroundColor:
                                                            const Color.fromARGB(
                                                              255,
                                                              197,
                                                              40,
                                                              90,
                                                            ),
                                                        elevation: 0,
                                                        shadowColor:
                                                            Colors.transparent,
                                                      ),
                                                      child: const Icon(
                                                        Icons.add,
                                                        size: 22,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // settings button fixed width, no shadow
                                              Container(
                                                width: 56,
                                                alignment:
                                                    Alignment.centerRight,
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => AlertDialog(
                                                        title: const Text(
                                                          'Paramètres du graphique',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        content: const Text(
                                                          'Fonctionnalité à venir...',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  context,
                                                                ).pop(),
                                                            child: const Text(
                                                              'Fermer',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                    shadowColor:
                                                        Colors.transparent,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 6,
                                                        ),
                                                  ),
                                                  child: const Icon(Icons.tune),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _entries.isEmpty
                      ? const Center(child: Text('Aucune pesée enregistrée'))
                      : ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final e = _entries[index];
                            return Dismissible(
                              key: ValueKey(e.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (_) {
                                debugPrint(
                                  'Dismissing index=$index, id=${e.id}',
                                );
                                _updateCurrentWeight();
                                _removeEntry(index);
                              },
                              child: ListTile(
                                title: Text(
                                  '${e.weight.toStringAsFixed(1)} kg, le ${DateFormat('dd/MM/yyyy').format(e.date)}',
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _addEntryDialog,
      //   child: const Icon(Icons.add),
      // ),
    );
  }
}
