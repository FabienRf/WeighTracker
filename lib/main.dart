import 'package:flutter/material.dart';
import 'package:flutter_weightrack/pages/home.dart';
import 'package:flutter_weightrack/pages/profile_selection.dart';
import 'package:flutter_weightrack/models/user_profile.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepPurple),
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
