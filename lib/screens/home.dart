import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gear.dart';
import '../data/sample_data.dart';
import 'edit_gear.dart';
import 'gear_detail.dart';
import 'about.dart';

/// Returns the Material Icon used for a given gear type.
/// Centralized so home, detail, and any future screens stay consistent.
IconData iconForGearType(String type) {
  switch (type.toLowerCase()) {
    case 'bat':
      return Icons.sports_cricket; // closest Material match for a bat shape
    case 'glove':
      return Icons.back_hand; // hand icon — best fit for "glove"
    case 'cleats':
      return Icons.directions_run;
    case 'bag':
      return Icons.work_outline; // duffle/bag silhouette
    case 'balls':
      return Icons.sports_baseball;
    case 'other':
    default:
      return Icons.inventory_2_outlined;
  }
}

/// Returns the color used to indicate gear status.
Color colorForStatus(String status, ColorScheme scheme) {
  switch (status.toLowerCase()) {
    case 'active':
      return scheme.primary;
    case 'benched':
      return scheme.outline;
    default:
      return scheme.onSurfaceVariant;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _storageKey = 'gear_list_v1';

  List<Gear> _gear = [];
  bool _loaded = false;
  final TextEditingController _searchCtrl = TextEditingController();

  // Filters
  String _typeFilter = 'All';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadGear();
  }

  int get _nextId =>
      (_gear.isEmpty ? 0 : _gear.map((g) => g.id).reduce((a, b) => a > b ? a : b)) + 1;

  List<Gear> get _visible {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _gear.where((g) {
      final matchesQuery = q.isEmpty ||
          g.brand.toLowerCase().contains(q) ||
          g.model.toLowerCase().contains(q) ||
          g.type.toLowerCase().contains(q);

      final matchesType =
          _typeFilter == 'All' || g.type.toLowerCase() == _typeFilter.toLowerCase();
      final matchesStatus =
          _statusFilter == 'All' || g.status.toLowerCase() == _statusFilter.toLowerCase();

      return matchesQuery && matchesType && matchesStatus;
    }).toList();
  }

  // --- Persistence ---

  Future<void> _loadGear() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        setState(() {
          _gear = list.map(Gear.fromJson).toList();
          _loaded = true;
        });
        return;
      } catch (_) {
        // Stored data is corrupt — fall through to seed
      }
    }

    setState(() {
      _gear = kSeedGear.map((g) => g.copyWith()).toList();
      _loaded = true;
    });
    await _saveGear();
  }

  Future<void> _saveGear() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_gear.map((g) => g.toJson()).toList());
    await prefs.setString(_storageKey, json);
  }

  // --- Mutations ---

  void _addGear() async {
    final result = await Navigator.push<Gear>(
      context,
      MaterialPageRoute(builder: (_) => const EditGearScreen()),
    );
    if (result != null) {
      setState(() {
        _gear.add(result.copyWith(id: _nextId));
      });
      await _saveGear();
    }
  }

  void _editGear(Gear g) async {
    final updated = await Navigator.push<Gear>(
      context,
      MaterialPageRoute(builder: (_) => EditGearScreen(initial: g)),
    );
    if (updated != null) {
      setState(() {
        final i = _gear.indexWhere((x) => x.id == g.id);
        if (i != -1) _gear[i] = updated.copyWith(id: g.id, usageNotes: g.usageNotes);
      });
      await _saveGear();
    }
  }

  void _deleteGear(Gear g) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete gear?'),
        content: Text('Remove ${g.brand} ${g.model}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              setState(() => _gear.removeWhere((x) => x.id == g.id));
              Navigator.pop(ctx);
              await _saveGear();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openDetail(Gear g) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GearDetailScreen(gear: g)));
  }

  void _openAbout() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    if (_gear.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 72,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No gear yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap the + button below to add your first piece of gear.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    // Filtered empty (have gear, none matches current filters)
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No matching gear',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search or filters.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gear Bag Tracker'),
        actions: [
          IconButton(onPressed: _openAbout, icon: const Icon(Icons.info_outline)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGear,
        icon: const Icon(Icons.add),
        label: const Text('Add Gear'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search brand, model, or type…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip<String>(
                    label: 'All',
                    value: 'All',
                    groupValue: _typeFilter,
                    onSelected: (v) => setState(() => _typeFilter = v),
                  ),
                  for (final t in const ['bat', 'glove', 'cleats', 'bag', 'balls', 'other'])
                    _FilterChip<String>(
                      label: t[0].toUpperCase() + t.substring(1),
                      value: t,
                      groupValue: _typeFilter,
                      onSelected: (v) => setState(() => _typeFilter = v),
                    ),
                  const SizedBox(width: 16),
                  _FilterChip<String>(
                    label: 'Active',
                    value: 'active',
                    groupValue: _statusFilter,
                    onSelected: (v) => setState(() => _statusFilter = v),
                  ),
                  _FilterChip<String>(
                    label: 'Benched',
                    value: 'benched',
                    groupValue: _statusFilter,
                    onSelected: (v) => setState(() => _statusFilter = v),
                  ),
                  _FilterChip<String>(
                    label: 'All Status',
                    value: 'All',
                    groupValue: _statusFilter,
                    onSelected: (v) => setState(() => _statusFilter = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _visible.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                itemCount: _visible.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final g = _visible[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                      scheme.primaryContainer.withValues(alpha: 0.6),
                      child: Icon(
                        iconForGearType(g.type),
                        color: scheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      '${g.brand} ${g.model}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Text(_cap(g.type)),
                          const SizedBox(width: 8),
                          StatusChip(status: g.status),
                        ],
                      ),
                    ),
                    onTap: () => _openDetail(g),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _editGear(g);
                        if (v == 'delete') _deleteGear(g);
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Reusable status indicator: colored dot + label in a soft pill.
/// Public so other screens (gear_detail) can use the same component.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isActive = status.toLowerCase() == 'active';
    final color = colorForStatus(status, scheme);
    final label = status.isEmpty ? status : status[0].toUpperCase() + status.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isActive ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip<T> extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  final String label;
  final T value;
  final T groupValue;
  final void Function(T value) onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(value),
      ),
    );
  }
}
