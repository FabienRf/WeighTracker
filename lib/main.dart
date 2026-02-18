import 'package:flutter/material.dart';
import 'package:WeighTracker/pages/home.dart';
import 'package:WeighTracker/pages/profile_selection.dart';
import 'package:WeighTracker/models/user_profile.dart';

// Couleur principale de l'application (ton de marque)
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
      // Détermine l'écran initial selon la présence d'un profil actif.
      // Rôle: charge le profil (migration si besoin) et affiche `HomePage`
      // si un profil existe, sinon affiche la sélection de profil.
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
