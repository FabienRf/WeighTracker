import 'package:flutter/material.dart';

class GraphPage extends StatelessWidget {
  const GraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("GRAPH PAGE")),
      body: const Center(
        child: ElevatedButton(
          // Action intentionally left undefined; Home will control navigation.
          onPressed: null,
          child: Text("Loading..."),
        ),
      ),
    );
  }
}
