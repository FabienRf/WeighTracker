import 'dart:convert';

import 'package:flutter/material.dart';
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
  late Duration _dureeGraphique = const Duration(days: 7);
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
    // Charge le profil actif depuis le stockage.
    // Rôle: initialise `_profile`, recharge les entrées et ajoute
    // une pesée initiale si aucune entrée n'existe.
    if (!mounted) return;
    await _loadEntries();
    _updateCurrentWeight();
    // If there are no entries yet and we have a profile, add an initial weight entry
    // Si aucune pesée n'existe et qu'un profil est chargé, ajoute une pesée initiale
    if (_entries.isEmpty) {
      final id = await IdGenerator.getNextId(_profile?.id);
      _entries.add(
        WeightEntry(
          id: id,
          date: DateTime.now(),
          weight: _profile!.weight,
          note: 'Poids initial',
        ),
      );
      await _saveEntries();
      _updateCurrentWeight();
    }
    setState(() {});
  }

  void _updateCurrentWeight() {
    // Met à jour `currentWeight` : prend la dernière entrée si disponible,
    // sinon utilise le poids du profil (ou 0.0 si aucun profil).
    if (_entries.isNotEmpty) {
      final latest = _entries.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
      currentWeight = latest.weight;
    } else {
      currentWeight = _profile?.weight ?? 0.0;
    }
  }

  Future<void> _loadEntries() async {
    // Charge les entrées de poids depuis `SharedPreferences` (JSON).
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
    // Sauvegarde les entrées de poids dans `SharedPreferences` au format JSON.
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> _updateProfileGoalDialog() async {
    final goalController = TextEditingController(
      text: _profile != null ? _profile!.goalWeight.toString() : '',
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Définir un nouvel objectif de poids'),
        content: TextField(
          controller: goalController,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Objectif de poids (kg)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final raw = goalController.text;
              double goal;
              try {
                final cleaned = raw
                    .replaceAll(',', '.')
                    .replaceAll(RegExp(r'[^0-9.\-]'), '');
                goal = double.parse(cleaned);
              } catch (e) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Poids invalide — entrez un nombre pour l\'objectif',
                    ),
                  ),
                );
                return;
              }

              setState(() {
                if (_profile != null) {
                  _profile = _profile!.copyWith(goalWeight: goal);
                  _profile!.save();
                  _updateCurrentWeight();
                }
              });
              Navigator.of(context).pop();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    goalController.dispose();
  }

  Future<void> _addEntryDialog() async {
    // Affiche une boîte de dialogue pour ajouter une pesée (poids, date, note).
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
                autofocus: true,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Poids (kg)'),
              ),
              const SizedBox(height: 4),
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

                // empeche l'ajout de plusieurs entrées pour la même date (en comparant uniquement la partie date, pas l'heure)
                if (_entries.any(
                  (e) => datesAreSameDay(e.date, selectedDate),
                )) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Une entrée existe déjà pour cette date'),
                    ),
                  );
                  return;
                } else {
                  setState(() {
                    _entries.insert(0, entry);
                    _updateCurrentWeight();
                  });
                  debugPrint(
                    'Added entry id=$id, afterIds=${_entries.map((e) => e.id).toList()}',
                  );
                }

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
    // Libère les contrôleurs une fois la boîte de dialogue fermée.
    weightController.dispose();
    noteController.dispose();
  }

  Future<void> _removeEntry(int index) async {
    // Supprime une entrée par index et met à jour le poids courant et le stockage.
    setState(() {
      _entries.removeAt(index);
      _updateCurrentWeight();
    });
    await _saveEntries();
  }

  WeightEntry _getEntryById(int id) {
    // Retourne l'entrée correspondant à `id`.
    return _entries.firstWhere((e) => e.id == id);
  }

  WeightEntry? _getLatestEntry() {
    // Retourne la dernière entrée triée par date, ou `null` si aucune entrée.
    if (_entries.isEmpty) return null;
    return _entries.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
  }

  double _progressPercentage() {
    // Calcule la progression vers l'objectif en pourcentage (0..100).
    // Utilise la dernière pesée si disponible, sinon `currentWeight`.
    return (_profile!.goalWeight == _getLatestEntry())
        ? 1.00
        : ((currentWeight - _profile!.weight) /
              (_profile!.goalWeight - _profile!.weight) *
              100);
  }

  bool datesAreSameDay(DateTime date1, DateTime date2) {
    // Compare uniquement la partie date (ignore l'heure).
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildWeightChart() {
    // Construit le widget graphique (LineChart) affichant l'évolution du poids.
    try {
      final spots = <FlSpot>[];

      if (_entries.isEmpty) {
        final base = currentWeight > 0 ? currentWeight : 0.0;
        spots.add(FlSpot(0, base));
      } else {
        final sorted = List<WeightEntry>.from(_entries)
          ..sort((a, b) => a.date.compareTo(b.date));
        // Normalize to date-only (midnight) so differences use full calendar days
        // Normalise les dates à la partie jour (minuit) pour calculer les
        // différences en nombre de jours pleins.
        final firstDate = DateTime(
          sorted.first.date.year,
          sorted.first.date.month,
          sorted.first.date.day,
        );
        final startDay = DateTime.now().subtract(_dureeGraphique);
        for (var e in sorted) {
          final dateOnly = DateTime(e.date.year, e.date.month, e.date.day);
          final x = dateOnly.difference(startDay).inDays.toDouble();
          if (e.date.isAfter(startDay)) {
            spots.add(FlSpot(x, e.weight));
          }
        }
      }

      double minX = spots.map((s) => s.x).reduce((a, b) => a < b ? a : b);
      double maxX = spots.map((s) => s.x).reduce((a, b) => a > b ? a : b);
      double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
      double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

      if ((maxX - minX).abs() < 1e-9) maxX = minX + 1;
      // Use a relative padding based on span, with a reasonable minimum.
      // Calcule un padding vertical proportionnel à l'amplitude des données
      // (avec une valeur minimale) pour éviter que les points touchent les bords.
      final yPadding = ((maxY - minY) * 0.15).abs();
      final effectivePadding = yPadding < 0.5 ? 0.5 : yPadding;
      minY = minY - effectivePadding;
      maxY = maxY + effectivePadding;

      // Use the same startDay that was used to compute x values so X labels match points
      // `startDate` correspond au début de la période affichée (utilisé
      // pour convertir les positions X en dates lisibles).
      final startDay = DateTime.now().subtract(_dureeGraphique);
      DateTime startDate = DateTime(
        startDay.year,
        startDay.month,
        startDay.day,
      );

      String bottomTitle(double value) {
        // Génère le label de l'axe X (format dd/MM) pour une position donnée.
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
                getTitlesWidget: (value, meta) {
                  const tickCount = 5;
                  final span = (maxX - minX);
                  final intervalX = span == 0 ? 1.0 : span / (tickCount - 1);
                  final tolerance = (intervalX.abs() * 0.5) + 1e-9;
                  for (var i = 0; i < tickCount; i++) {
                    final tick = minX + i * intervalX;
                    if ((value - tick).abs() <= tolerance) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          bottomTitle(tick),
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  const tickCount = 5;
                  final spanY = (maxY - minY);
                  final intervalY = spanY == 0 ? 1.0 : spanY / (tickCount - 1);
                  final toleranceY = (intervalY.abs() * 0.5) + 1e-9;
                  for (var i = 0; i < tickCount; i++) {
                    final tick = minY + i * intervalY;
                    if ((value - tick).abs() <= toleranceY) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: Text(
                          tick.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    }
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
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      );
    } catch (e) {
      return const Center(
        child: Text('Aucune donnée à afficher avec les paramètres actuels'),
      );
    }
  }

  Widget _customRadio(
    String text,
    Duration value, {
    bool isFirst = false,
    bool isLast = false,
    StateSetter? dialogSetState,
  }) {
    // Crée un bouton radio personnalisé pour sélectionner la durée du graphique.
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _dureeGraphique == value;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0.0),
        child: OutlinedButton(
          onPressed: () {
            if (dialogSetState != null) {
              dialogSetState(() {
                _dureeGraphique = value;
              });
            }
            setState(() {
              _dureeGraphique = value;
            });
          },
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.grey),
            backgroundColor: selected
                ? colorScheme.primary
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isFirst ? 8.0 : 0.0),
                bottomLeft: Radius.circular(isFirst ? 8.0 : 0.0),
                topRight: Radius.circular(isLast ? 8.0 : 0.0),
                bottomRight: Radius.circular(isLast ? 8.0 : 0.0),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12.0),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // Row avec nom de profil, icône et bouton pour définir un nouvel objectif de poid
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
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.account_circle,
                                  size: 40,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _profile?.name ?? 'WeighTrack',
                                  style: textTheme.titleLarge,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Bouton qui ouvre une pop-up pour re-définir l'objectif du profil actuel (perte ou gain de poids)
                    ),
                    Column(
                      children: [
                        Container(
                          height: 40,
                          width: 40,
                          child: ElevatedButton(
                            onPressed: () => _updateProfileGoalDialog(),
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: EdgeInsets.zero,
                              backgroundColor: colorScheme.primary,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 30,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Row affichant le dernier poids en grande taille
                Row(
                  children: [
                    RichText(
                      text: TextSpan(
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
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
                    if (_profile != null)
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
                                  '${((_getLatestEntry() != null ? _getLatestEntry()!.weight : _profile!.weight) - _profile!.goalWeight).abs().toStringAsFixed(1)} kg',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    if (_profile != null)
                      Text(
                        'Progression: ${_progressPercentage().toStringAsFixed(1)}%',
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
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        color: colorScheme.primary,
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
                              '${_profile!.weight} kg',
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
                            if (_profile != null)
                              Text(
                                '🎯 ${_profile!.goalWeight.toStringAsFixed(1)} kg',
                                style: const TextStyle(fontSize: 16),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 52),

                // Row qui apparait si l'objectif est atteint ou dépassé, avec un message de félicitations et une icône, ainsi qu'un bouton qui appele une pop-up pour definir un nouvel objectif
                if (_progressPercentage() >= 100)
                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events_outlined,
                        size: 22,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Objectif atteint !',
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),

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
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              // add button centered across available space
                                              Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  SizedBox(
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
                                                            colorScheme.primary,
                                                        elevation: 0,
                                                        shadowColor:
                                                            Colors.transparent,
                                                      ),
                                                      child: Icon(
                                                        Icons.add,
                                                        size: 22,
                                                        color: colorScheme
                                                            .onPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              // settings button fixed width, no shadow
                                              Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (context) => StatefulBuilder(
                                                          builder:
                                                              (
                                                                dialogContext,
                                                                dialogSetState,
                                                              ) => AlertDialog(
                                                                title: const Text(
                                                                  'Durée du graphique :',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color: Colors
                                                                        .black,
                                                                  ),
                                                                ),
                                                                content: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        _customRadio(
                                                                          "7 J",
                                                                          const Duration(
                                                                            days:
                                                                                7,
                                                                          ),
                                                                          isFirst:
                                                                              true,
                                                                          dialogSetState:
                                                                              dialogSetState,
                                                                        ),
                                                                        _customRadio(
                                                                          "30 J",
                                                                          const Duration(
                                                                            days:
                                                                                30,
                                                                          ),
                                                                          dialogSetState:
                                                                              dialogSetState,
                                                                        ),
                                                                        _customRadio(
                                                                          "6 M",
                                                                          const Duration(
                                                                            days:
                                                                                180,
                                                                          ),
                                                                          dialogSetState:
                                                                              dialogSetState,
                                                                        ),
                                                                        _customRadio(
                                                                          "1 A",
                                                                          const Duration(
                                                                            days:
                                                                                365,
                                                                          ),
                                                                          dialogSetState:
                                                                              dialogSetState,
                                                                        ),
                                                                        _customRadio(
                                                                          "Tous",
                                                                          const Duration(
                                                                            days:
                                                                                36500,
                                                                          ),
                                                                          isLast:
                                                                              true,
                                                                          dialogSetState:
                                                                              dialogSetState,
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
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
                                                    child: const Icon(
                                                      Icons.tune,
                                                    ),
                                                  ),
                                                ],
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

          const SizedBox(height: 22),

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
                                  '${e.weight.toStringAsFixed(3)} kg, le ${DateFormat('dd/MM/yyyy').format(e.date)}',
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
