import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _appName = 'Gear Bag Tracker';
  static const String _version = '1.0.0';
  static const String _developer = 'Jaron Pirtle';
  static const String _supportEmail = 'jpirt60@gmail.com'; //

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _appName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version $_version',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Track your softball gear inventory in one place. '
                'Organize bats, gloves, cleats, bags, balls, and other equipment — '
                'mark items active or benched as your gear rotation evolves throughout the season.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 24),

          _Section(label: 'Developer', value: _developer),
          _Section(label: 'Support', value: _supportEmail),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          Text(
            '© $year $_developer. All rights reserved.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => showLicensePage(
                context: context,
                applicationName: _appName,
                applicationVersion: _version,
                applicationLegalese: '© $year $_developer',
              ),
              child: const Text('Open-source licenses'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
