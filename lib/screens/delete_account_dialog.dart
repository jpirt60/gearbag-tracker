import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import '../data/sync_service.dart';

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _confirmCtrl = TextEditingController();
  bool _deleting = false;

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);

    try {
      // 1. Stop realtime subscriptions before deleting (avoids dangling channels)
      await SyncService.instance.stopRealtime();

      // 2. Call the Postgres RPC — cascades clean up gear + usage_notes
      await Supabase.instance.client.rpc('delete_current_user');

      // 3. Wipe local sqflite — no orphaned data from the deleted account
      await _wipeLocalDatabase();

      // 4. Pop dialog + settings screen so AuthGate (after signOut) lands on LoginScreen
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

      // 5. Sign out (clears local session storage)
      await Supabase.instance.client.auth.signOut();

      // AuthGate auto-routes to LoginScreen on signOut
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  /// Wipe the local sqflite database file entirely.
  /// Faster and more thorough than DELETE FROM on each table.
  Future<void> _wipeLocalDatabase() async {
    final dbDir = await getDatabasesPath();
    final dbPath = p.join(dbDir, 'gearbag.db');
    await deleteDatabase(dbPath);
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = _confirmCtrl.text == 'DELETE' && !_deleting;

    return AlertDialog(
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently removes your account, gear, and usage notes from '
                'all your devices. This cannot be undone.',
          ),
          const SizedBox(height: 16),
          const Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Type '),
              TextSpan(
                text: 'DELETE',
                style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
              ),
              TextSpan(text: ' to confirm'),
            ]),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmCtrl,
            onChanged: (_) => setState(() {}),
            enabled: !_deleting,
            decoration: const InputDecoration(
              hintText: 'DELETE',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: canDelete ? _delete : null,
          child: Text(_deleting ? 'Deleting…' : 'Delete account'),
        ),
      ],
    );
  }
}