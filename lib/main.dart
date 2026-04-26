import 'package:flutter/material.dart';
import 'screens/home.dart';

void main() => runApp(const GearBagApp());

class GearBagApp extends StatelessWidget {
  const GearBagApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GearBag Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const HomeScreen(),
    );
  }
}
