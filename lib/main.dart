import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/auth_gate.dart';
import 'data/legacy_migration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  await LegacyMigration.runIfNeeded();
  runApp(const GearBagApp());
}

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
      home: const AuthGate(),
    );
  }
}