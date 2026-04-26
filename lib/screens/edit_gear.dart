import 'package:flutter/material.dart';
import '../models/gear.dart';

class EditGearScreen extends StatefulWidget {
  const EditGearScreen({super.key, this.initial});
  final Gear? initial;

  @override
  State<EditGearScreen> createState() => _EditGearScreenState();
}

class _EditGearScreenState extends State<EditGearScreen> {
  final _formKey = GlobalKey<FormState>();
  final _types = const ['bat', 'glove', 'cleats', 'bag', 'balls', 'other'];
  final _statuses = const ['active', 'benched'];

  late String _type;
  late String _brand;
  late String _model;
  late String _status;
  late String _notes;

  @override
  void initState() {
    super.initState();
    final g = widget.initial;
    _type = g?.type ?? 'bat';
    _brand = g?.brand ?? '';
    _model = g?.model ?? '';
    _status = g?.status ?? 'active';
    _notes = g?.notes ?? '';
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();

    final result = (widget.initial ?? Gear(
      id: -1, // caller will replace with next id
      type: _type,
      brand: _brand,
      model: _model,
      status: _status,
      notes: _notes,
    )).copyWith(
      type: _type,
      brand: _brand,
      model: _model,
      status: _status,
      notes: _notes,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Gear' : 'Add Gear')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _brand,
                decoration: const InputDecoration(labelText: 'Brand'),
                onSaved: (v) => _brand = v!.trim(),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Brand required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _model,
                decoration: const InputDecoration(labelText: 'Model'),
                onSaved: (v) => _model = v!.trim(),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Model required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
                ),
                onSaved: (v) => _notes = v?.trim() ?? '',
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
