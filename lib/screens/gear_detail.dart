import 'package:flutter/material.dart';
import '../models/gear.dart';
import 'home.dart' show iconForGearType, StatusChip;

class GearDetailScreen extends StatefulWidget {
  const GearDetailScreen({super.key, required this.gear});
  final Gear gear;

  @override
  State<GearDetailScreen> createState() => _GearDetailScreenState();
}

class _GearDetailScreenState extends State<GearDetailScreen> {
  void _addUsageNote() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Usage Note'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g., Felt hot today'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (note != null && note.isNotEmpty) {
      setState(() => widget.gear.usageNotes.insert(0, note));
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.gear;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('${g.brand} ${g.model}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUsageNote,
        icon: const Icon(Icons.note_add),
        label: const Text('Add Usage Note'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card with type icon, name, type label, and status chip
          Card(
            elevation: 0,
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      iconForGearType(g.type),
                      color: scheme.onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${g.brand} ${g.model}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              _cap(g.type),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusChip(status: g.status),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Notes section
          Text('Notes', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            g.notes.isEmpty ? 'No notes added.' : g.notes,
            style: g.notes.isEmpty
                ? theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            )
                : theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // Usage notes section
          Text('Usage Notes', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          if (g.usageNotes.isEmpty)
            Text(
              'No usage notes yet. Tap the button below to add one.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...g.usageNotes.map(
                  (n) => Card(
                elevation: 0,
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                child: ListTile(
                  leading: Icon(Icons.edit_note, color: scheme.onSurfaceVariant),
                  title: Text(n),
                ),
              ),
            ),
          const SizedBox(height: 80), // padding for FAB
        ],
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
