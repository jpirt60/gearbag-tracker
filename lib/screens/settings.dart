import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'delete_account_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account section
          Text('Account', style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Signed in as'),
              subtitle: Text(user?.email ?? 'Unknown'),
            ),
          ),
          const SizedBox(height: 32),

          // Danger zone
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: scheme.error),
                    const SizedBox(width: 8),
                    Text(
                      'Danger zone',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Deleting your account is permanent. All your gear, usage notes, '
                      'and sign-in data will be removed immediately and cannot be recovered.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    ),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const DeleteAccountDialog(),
                    ),
                    child: const Text('Delete my account'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}