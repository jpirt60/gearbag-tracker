import 'package:flutter/material.dart';
import '../models/gear.dart';

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
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Add')),
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
    return Scaffold(
      appBar: AppBar(title: Text('${g.brand} ${g.model}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUsageNote,
        icon: const Icon(Icons.note_add),
        label: const Text('Add Usage Note'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _kv('Type', g.type),
            _kv('Status', g.status),
            _kv('Notes', g.notes.isEmpty ? '—' : g.notes),
            const SizedBox(height: 12),
            Text('Usage Notes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (g.usageNotes.isEmpty)
              const Text('No usage notes yet.')
            else
              ...g.usageNotes.map((n) => Card(
                child: ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: Text(n),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$k:', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
