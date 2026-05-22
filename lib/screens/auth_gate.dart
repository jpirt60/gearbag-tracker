import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/sync_service.dart';
import 'home.dart';
import 'login.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _syncedForUserId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        if (session == null) {
          // Clear sync marker on logout so next login re-syncs
          _syncedForUserId = null;
          return const LoginScreen();
        }

        // Trigger initial pull once per user session
        if (_syncedForUserId != session.user.id) {
          _syncedForUserId = session.user.id;
          // Fire-and-forget; the HomeScreen will refresh after
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final ok = await SyncService.instance.pullAll();
            if (!mounted) return;
            if (!ok && SyncService.instance.lastError != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sync failed: ${SyncService.instance.lastError}'),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          });
        }

        return const HomeScreen();
      },
    );
  }
}