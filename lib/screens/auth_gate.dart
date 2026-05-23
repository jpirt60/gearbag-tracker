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

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  String? _syncedForUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground — try to push any pending changes,
      // then pull any remote updates
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        () async {
          await SyncService.instance.pushPending();
          await SyncService.instance.pullAll();
        }();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        if (session == null) {
          _syncedForUserId = null;
          SyncService.instance.stopRealtime();
          return const LoginScreen();
        }

        if (_syncedForUserId != session.user.id) {
          _syncedForUserId = session.user.id;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await SyncService.instance.pushPending();
            final ok = await SyncService.instance.pullAll();
            if (ok) {
              SyncService.instance.startRealtime();
            }
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