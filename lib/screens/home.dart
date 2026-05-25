import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../data/database_helper.dart';
import '../models/gear.dart';
import 'edit_gear.dart';
import 'gear_detail.dart';
import 'about.dart';
import '../data/sync_service.dart';
import 'settings.dart';

/// Returns the Material Icon used for a given gear type.
IconData iconForGearType(String type) {
  switch (type.toLowerCase()) {
    case 'bat':
      return Icons.sports_cricket;
    case 'glove':
      return Icons.back_hand;
    case 'cleats':
      return Icons.directions_run;
    case 'bag':
      return Icons.work_outline;
    case 'balls':
      return Icons.sports_baseball;
    case 'batting_gloves':
      return Icons.pan_tool_outlined;
    case 'other':
    default:
      return Icons.inventory_2_outlined;
  }
}

/// Display label for gear types (handles snake_case from DB).
String labelForGearType(String type) {
  switch (type.toLowerCase()) {
    case 'batting_gloves':
      return 'Batting Gloves';
    default:
      return type.isEmpty ? type : type[0].toUpperCase() + type.substring(1);
  }
}

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
  final _uuid = const Uuid();
  List<Gear> _gear = [];
  bool _loaded = false;
  final TextEditingController _searchCtrl = TextEditingController();

  String _typeFilter = 'All';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadGear();
    SyncService.instance.addListener(_onSyncStateChanged);
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onSyncStateChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSyncStateChanged() {
    // When sync goes from syncing → idle, reload from local DB
    if (SyncService.instance.state == SyncState.idle) {
      _loadGear();
    }
  }

  String get _userId => Supabase.instance.client.auth.currentUser!.id;

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

  Future<void> _loadGear() async {
    final list = await DatabaseHelper.instance.getGearList(_userId);
    if (!mounted) return;
    setState(() {
      _gear = list;
      _loaded = true;
    });
  }

  void _addGear() async {
    final result = await Navigator.push<Gear>(
      context,
      MaterialPageRoute(builder: (_) => const EditGearScreen()),
    );
    if (result != null) {
      final now = DateTime.now();
      final newGear = Gear(
        id: _uuid.v4(),
        userId: _userId,
        type: result.type,
        brand: result.brand,
        model: result.model,
        status: result.status,
        notes: result.notes,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending_create',
      );
      await DatabaseHelper.instance.insertGear(newGear);
      await _loadGear();
      SyncService.instance.pushPending();
    }
  }

  void _editGear(Gear g) async {
    final updated = await Navigator.push<Gear>(
      context,
      MaterialPageRoute(builder: (_) => EditGearScreen(initial: g)),
    );
    if (updated != null) {
      final edited = g.copyWith(
        type: updated.type,
        brand: updated.brand,
        model: updated.model,
        status: updated.status,
        notes: updated.notes,
        updatedAt: DateTime.now(),
        syncStatus: g.syncStatus == 'pending_create' ? 'pending_create' : 'pending_update',
      );
      await DatabaseHelper.instance.updateGear(edited);
      await _loadGear();
      SyncService.instance.pushPending();
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
              await DatabaseHelper.instance.softDeleteGear(g.id);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              await _loadGear();
              SyncService.instance.pushPending();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openDetail(Gear g) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GearDetailScreen(gear: g)),
    );
    // Refresh in case usage notes changed
    await _loadGear();
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
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
            Text('No matching gear', style: theme.textTheme.titleMedium),
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
          ListenableBuilder(
            listenable: SyncService.instance,
            builder: (context, _) {
              if (SyncService.instance.state == SyncState.syncing) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          ListenableBuilder(
            listenable: SyncService.instance,
            builder: (context, _) {
              final syncing = SyncService.instance.state == SyncState.syncing;
              return IconButton(
                onPressed: syncing
                    ? null
                    : () async {
                  await SyncService.instance.syncNow();
                },
                icon: const Icon(Icons.sync),
                tooltip: 'Sync now',
              );
            },
          ),
          IconButton(onPressed: _openAbout, icon: const Icon(Icons.info_outline)),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
          ),
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
                  for (final t in const [
                    'bat',
                    'glove',
                    'cleats',
                    'bag',
                    'balls',
                    'batting_gloves',
                    'other',
                  ])
                    _FilterChip<String>(
                      label: labelForGearType(t),
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
              child: RefreshIndicator(
                onRefresh: () async {
                  await SyncService.instance.syncNow();
                  // pullAll calls _loadGear via the listener, but for safety:
                  await _loadGear();
                },
                child: _visible.isEmpty
                    ? ListView(
                  // RefreshIndicator needs a scrollable child to detect pulls,
                  // even in the empty state. Single-item ListView wraps the empty UI.
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: _buildEmptyState(),
                    ),
                  ],
                )
                    : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _visible.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final g = _visible[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer.withValues(alpha: 0.6),
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
                            Text(labelForGearType(g.type)),
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
            ),
          ],
        ),
      ),
    );
  }
}

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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
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