import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../data/database_helper.dart';
import '../models/gear.dart';
import '../models/usage_note.dart';
import 'home.dart' show iconForGearType, labelForGearType, StatusChip;

class GearDetailScreen extends StatefulWidget {
  const GearDetailScreen({super.key, required this.gear});
  final Gear gear;

  @override
  State<GearDetailScreen> createState() => _GearDetailScreenState();
}

class _GearDetailScreenState extends State<GearDetailScreen> {
  final _uuid = const Uuid();
  List<UsageNote> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  String get _userId => Supabase.instance.client.auth.currentUser!.id;

  Future<void> _loadNotes() async {
    final notes = await DatabaseHelper.instance.getUsageNotesByGear(widget.gear.id);
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _addUsageNote() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Usage Note'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g., Felt hot today'),
          autofocus: true,
          maxLines: 3,
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

    if (text == null || text.isEmpty) return;

    final now = DateTime.now();
    final note = UsageNote(
      id: _uuid.v4(),
      gearId: widget.gear.id,
      userId: _userId,
      text: text,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending_create',
    );
    await DatabaseHelper.instance.insertUsageNote(note);
    await _loadNotes();
  }

  Future<void> _deleteNote(UsageNote note) async {
    await DatabaseHelper.instance.softDeleteUsageNote(note.id);
    await _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.gear;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateFormat = DateFormat('MMM d, y · h:mm a');

    return Scaffold(
      appBar: AppBar(title: Text('${g.brand} ${g.model}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUsageNote,
        icon: const Icon(Icons.note_add),
        label: const Text('Add Usage Note'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                              labelForGearType(g.type),
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

          Text('Notes', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            (g.notes == null || g.notes!.isEmpty) ? 'No notes added.' : g.notes!,
            style: (g.notes == null || g.notes!.isEmpty)
                ? theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            )
                : theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          Text('Usage Notes', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          if (_notes.isEmpty)
            Text(
              'No usage notes yet. Tap the button below to add one.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ..._notes.map(
                  (n) => Card(
                elevation: 0,
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                child: ListTile(
                  leading: Icon(Icons.edit_note, color: scheme.onSurfaceVariant),
                  title: Text(n.text),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      dateFormat.format(n.createdAt.toLocal()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteNote(n),
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}