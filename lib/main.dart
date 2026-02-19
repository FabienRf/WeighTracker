import 'package:flutter/material.dart';
import 'package:WeighTracker/pages/home.dart';
import 'package:WeighTracker/pages/profile_selection.dart';
import 'package:WeighTracker/models/user_profile.dart';

// Brand primary color
const Color kBrandColor = Color.fromARGB(255, 197, 40, 90);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kBrandColor),
        appBarTheme: const AppBarTheme(centerTitle: false),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
        ),
      ),
      // Decide the initial screen based on the active profile.
      // Loads (and migrates) the profile, shows `HomePage` if present,
      // otherwise shows the profile selection screen.
      home: FutureBuilder<UserProfile?>(
        future: UserProfile.load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const HomePage();
          }
          return const ProfileSelectionPage();
        },
      ),
    );
  }
}
