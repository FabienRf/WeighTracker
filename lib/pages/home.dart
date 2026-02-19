import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:WeighTracker/services/id_generator.dart';
import 'package:WeighTracker/models/weight_entry.dart';
import 'package:WeighTracker/models/user_profile.dart';
import 'package:WeighTracker/pages/profile_selection.dart';
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
    // Load the active profile, reload entries, and add an initial weigh-in
    // if none exist yet.
    if (!mounted) return;
    await _loadEntries();
    _updateCurrentWeight();
    // If there are no entries yet and we have a profile, add an initial weigh-in
    if (_entries.isEmpty) {
      final id = await IdGenerator.getNextId(_profile?.id);
      _entries.add(
        WeightEntry(
          id: id,
          date: DateTime.now(),
          weight: _profile!.weight,
          note: 'Initial weight',
        ),
      );
      await _saveEntries();
      _updateCurrentWeight();
    }
    setState(() {});
  }

  void _updateCurrentWeight() {
    // Update `currentWeight`: use the latest entry if available, otherwise the profile weight (or 0.0).
    if (_entries.isNotEmpty) {
      final latest = _entries.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
      currentWeight = latest.weight;
    } else {
      currentWeight = _profile?.weight ?? 0.0;
    }
  }

  Future<void> _loadEntries() async {
    // Load weight entries from `SharedPreferences` (JSON).
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
    // Save weight entries into `SharedPreferences` as JSON.
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
        title: const Text('Set a new weight goal'),
        content: TextField(
          controller: goalController,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Goal weight (kg)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
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
                      'Invalid weight — enter a number for the goal',
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    goalController.dispose();
  }

  Future<void> _addEntryDialog() async {
    // Show a dialog to add a weigh-in (weight, date, note).
    final weightController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) => AlertDialog(
          title: const Text('Add a weigh-in'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                autofocus: true,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
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
                    child: const Text('Choose'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
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
                      content: Text('Invalid weight — enter a number'),
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

                // Prevent multiple entries for the same day (ignore time portion)
                if (_entries.any(
                  (e) => datesAreSameDay(e.date, selectedDate),
                )) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('An entry already exists for this date'),
                    ),
                  );
                  return;
                } else if (_entries.any(
                  (e) => selectedDate.isAfter(DateTime.now()),
                )) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'You cannot add an entry for a future date',
                      ),
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
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    // Dispose controllers after the dialog is closed.
    weightController.dispose();
    noteController.dispose();
  }

  Future<void> _removeEntry(int index) async {
    // Remove an entry by index and update current weight and storage.
    setState(() {
      _entries.removeAt(index);
      _updateCurrentWeight();
    });
    await _saveEntries();
  }

  // WeightEntry _getEntryById(int id) {
  //   // Return the entry matching `id`.
  //   return _entries.firstWhere((e) => e.id == id);
  // }

  WeightEntry? _getLatestEntry() {
    // Return the latest entry by date, or `null` if none.
    if (_entries.isEmpty) return null;
    return _entries.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
  }

  double _progressPercentage() {
    // Compute progress toward the goal in percent (0..100).
    // Use the latest weigh-in if available, otherwise `currentWeight`.
    if (_profile == null) return 0.0;
    final goal = _profile!.goalWeight;
    final start = _profile!.weight;
    final latest = _getLatestEntry()?.weight ?? currentWeight;
    // Avoid division by zero if start == goal
    if ((goal - start).abs() < 1e-9) return 0.0;
    final percent = ((latest - start) / (goal - start)) * 100.0;
    return percent.clamp(0.0, 100.0);
  }

  bool datesAreSameDay(DateTime date1, DateTime date2) {
    // Compare only the date portion (ignore time).
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildWeightChart() {
    // Build the line chart widget showing weight evolution.
    try {
      final spots = <FlSpot>[];

      if (_entries.isEmpty) {
        final base = currentWeight > 0 ? currentWeight : 0.0;
        spots.add(FlSpot(0, base));
      } else {
        final sorted = List<WeightEntry>.from(_entries)
          ..sort((a, b) => a.date.compareTo(b.date));
        // Normalize dates to midnight to compute whole-day differences.
        final rangeStart = DateTime.now().subtract(_dureeGraphique);
        final startDay = DateTime(
          rangeStart.year,
          rangeStart.month,
          rangeStart.day,
        );
        for (var e in sorted) {
          final dateOnly = DateTime(e.date.year, e.date.month, e.date.day);
          final x = dateOnly.difference(startDay).inDays.toDouble();
          if (!dateOnly.isBefore(startDay)) {
            spots.add(FlSpot(x, e.weight));
          }
        }
      }

      double minX = spots.map((s) => s.x).reduce((a, b) => a < b ? a : b);
      double maxX = spots.map((s) => s.x).reduce((a, b) => a > b ? a : b);
      double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
      double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

      if ((maxX - minX).abs() < 1e-9) maxX = minX + 1;
      if ((maxY - minY).abs() < 1e-9) maxY = minY + 1;
      // Add vertical padding proportional to the data range (with a floor)
      // to avoid points touching the chart edges.
      final yPadding = ((maxY - minY) * 0.15).abs();
      double intervalY = (maxY - minY) / 5;

      minY = minY - yPadding;
      maxY = maxY + yPadding;

      return LineChart(
        LineChartData(
          // domainAxis: charts.NumericAxisSpec(
          //   showAxisLine: false,
          //   renderSpec: charts.NoneRenderSpec(),
          // ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: _profile?.goalWeight ?? 0.0,
                color: Colors.green,
                strokeWidth: 2,
                dashArray: [5, 5],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 4, bottom: 4),
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  labelResolver: (_) => 'Goal',
                ),
              ),
            ],
          ),

          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: intervalY,
                minIncluded: false,
                maxIncluded: false,
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              showOnTopOfTheChartBoxArea: false,

              getTooltipColor: (touchedSpot) =>
                  Theme.of(context).colorScheme.surface,
            ),
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
        child: Text('No data to display with the current settings'),
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
    // Build a custom radio button for selecting the chart range.
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
          // Add top spacer on narrow screens (phones)
          if (MediaQuery.of(context).size.width < 600)
            Container(
              height: 32,
              color: colorScheme.primaryContainer.withOpacity(0.6),
            ),
          // Row with profile name, icon, and button to set a new goal
          Container(
            color: colorScheme.primaryContainer.withOpacity(0.6),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
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
                  ),

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
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const SizedBox(height: 22),

                // Row showing the latest weight in large text
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
                              fontSize: 18, // Smaller size for "kg"
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Row with remaining weight to goal and progress percentage
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_profile != null)
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ), // Default text style
                          children: [
                            TextSpan(text: 'Remaining: '),
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
                        'Progress: ${_progressPercentage().toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row with a horizontal progress bar toward the goal
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

                // Row showing goal weight and starting weight below the current weight
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
                const SizedBox(height: 32),

                // Row appearing when the goal is reached, with a celebration message and button to set a new goal
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
                        'Goal reached!',
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(child: Container()),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                        ),
                        onPressed: () => _updateProfileGoalDialog(),
                        child: Text(
                          'New goal',
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // GestureDetector(
                      // onTap: () => _updateProfileGoalDialog(),
                      // child: Text(
                      //   'Nouveaux',
                      //   style: textTheme.titleMedium?.copyWith(
                      //     color: Colors.white,
                      //     backgroundColor: colorScheme.primary,
                      //     fontWeight: FontWeight.bold,
                      //   ),
                      // ),
                      // ),
                    ],
                  ),

                const SizedBox(height: 12),

                // Line chart showing weight changes with each recorded weigh-in
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
                                    // Chart (fixed height to avoid unbounded constraints)
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
                                                                  'Chart range:',
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
                                                                          "7 D",
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
                                                                          "30 D",
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
                                                                          "1 Y",
                                                                          const Duration(
                                                                            days:
                                                                                365,
                                                                          ),
                                                                          dialogSetState:
                                                                              dialogSetState,
                                                                        ),
                                                                        _customRadio(
                                                                          "All",
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
                                                                      'Close',
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
                      ? const Center(child: Text('No weigh-ins recorded'))
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
                                  '${e.weight.toStringAsFixed(3)} kg on ${DateFormat('dd/MM/yyyy').format(e.date)}',
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
