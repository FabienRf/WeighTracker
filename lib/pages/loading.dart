import 'package:flutter/material.dart';

// Page de chargement/placeholder pour le graphique.
// Rôle: page temporaire si besoin de navigation séparée pour les graphes.
class GraphPage extends StatelessWidget {
  const GraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("GRAPH PAGE")),
      body: const Center(
        child: ElevatedButton(
          // Action intentionnellement non définie; la navigation est
          // gérée depuis la page principale (`Home`).
          onPressed: null,
          child: Text("Loading..."),
        ),
      ),
    );
  }
}
