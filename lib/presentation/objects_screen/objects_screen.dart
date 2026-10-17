import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import './object_detail_screen.dart';
import './widgets/create_edit_object_sheet.dart';

class ObjectsScreen extends StatefulWidget {
  const ObjectsScreen({super.key});

  @override
  State<ObjectsScreen> createState() => _ObjectsScreenState();
}

class _ObjectsScreenState extends State<ObjectsScreen> {
  final _dataService = DataService(LocalStorageService());
  bool _initialized = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  List<WorkObjectModel> _activeObjects = [];
  List<WorkObjectModel> _completedObjects = [];

  @override
  void initState() {
    super.initState();
    _init();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _dataService.init();
    _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _initialized = true;
      _activeObjects = _dataService.activeObjects;
      _completedObjects = _dataService.completedObjects;
    });
  }

  List<WorkObjectModel> _filterList(List<WorkObjectModel> list) {
    if (_searchQuery.isEmpty) return list;
    return list.where((o) {
      return o.name.toLowerCase().contains(_searchQuery) ||
          o.address.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CreateEditObjectSheet(
        onSave: (name, address, note) async {
          await _dataService.createObject(
            name: name,
            address: address,
            note: note,
          );
          if (mounted) Navigator.of(context).pop();
          _refresh();
        },
      ),
    );
  }

  void _openDetail(WorkObjectModel obj) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ObjectDetailScreen(
          objectId: obj.id,
          dataService: _dataService,
          onChanged: _refresh,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredActive = _filterList(_activeObjects);
    final filteredCompleted = _filterList(_completedObjects);
    final hasAny = _activeObjects.isNotEmpty || _completedObjects.isNotEmpty;
    final hasResults =
        filteredActive.isNotEmpty || filteredCompleted.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.5),
                  radius: 1.2,
                  colors: [Color(0xFF0D1F35), AppTheme.backgroundDark],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withAlpha(10),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceM,
                    AppTheme.spaceM,
                    AppTheme.spaceM,
                    0,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.glassBackground,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusM,
                            ),
                            border: Border.all(color: AppTheme.glassBorder),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceM),
                      const Icon(
                        Icons.domain_rounded,
                        size: 22,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: AppTheme.spaceS),
                      const Text(
                        'ობიექტები',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showCreateSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(26),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusFull,
                            ),
                            border: Border.all(
                              color: AppTheme.primary.withAlpha(77),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 16,
                                color: AppTheme.primary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'ახალი',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceM),
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceM,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.glassBackground,
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          border: Border.all(color: AppTheme.glassBorder),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'ობიექტის ძებნა...',
                            hintStyle: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: AppTheme.textMuted,
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceM,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceM),
                // Content
                Expanded(
                  child: !_initialized
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primary,
                          ),
                        )
                      : !hasAny
                      ? _EmptyObjectsState(onAdd: _showCreateSheet)
                      : !hasResults
                      ? const _NoSearchResults()
                      : RefreshIndicator(
                          color: AppTheme.primary,
                          backgroundColor: AppTheme.surfaceDark,
                          onRefresh: () async => _refresh(),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(
                              AppTheme.spaceM,
                              0,
                              AppTheme.spaceM,
                              120,
                            ),
                            children: [
                              if (filteredActive.isNotEmpty) ...[
                                _SectionHeader(
                                  label: 'აქტიური ობიექტები',
                                  count: filteredActive.length,
                                  color: AppTheme.success,
                                ),
                                const SizedBox(height: AppTheme.spaceS),
                                ...filteredActive.map(
                                  (obj) => _ObjectCard(
                                    object: obj,
                                    stats: _dataService.getObjectStats(obj.id),
                                    onTap: () => _openDetail(obj),
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spaceM),
                              ],
                              if (filteredActive.isEmpty &&
                                  filteredCompleted.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppTheme.spaceM,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                      AppTheme.spaceM,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.glassBackground,
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM,
                                      ),
                                      border: Border.all(
                                        color: AppTheme.glassBorder,
                                      ),
                                    ),
                                    child: const Text(
                                      'აქტიური ობიექტები არ არის',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textMuted,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              if (filteredCompleted.isNotEmpty) ...[
                                _SectionHeader(
                                  label: 'დასრულებული ობიექტები',
                                  count: filteredCompleted.length,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(height: AppTheme.spaceS),
                                ...filteredCompleted.map(
                                  (obj) => _ObjectCard(
                                    object: obj,
                                    stats: _dataService.getObjectStats(obj.id),
                                    onTap: () => _openDetail(obj),
                                  ),
                                ),
                              ],
                            ],
                          ),
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

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ObjectCard extends StatelessWidget {
  final WorkObjectModel object;
  final Map<String, dynamic> stats;
  final VoidCallback onTap;

  const _ObjectCard({
    required this.object,
    required this.stats,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = object.status == WorkObjectStatus.active;
    final workedDays = stats['workedDays'] as int? ?? 0;
    final earned = stats['earned'] as double? ?? 0;
    final received = stats['received'] as double? ?? 0;
    final remaining = stats['remaining'] as double? ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spaceS),
        padding: const EdgeInsets.all(AppTheme.spaceM),
        decoration: BoxDecoration(
          color: AppTheme.glassBackground,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: isActive
                ? AppTheme.primary.withAlpha(40)
                : AppTheme.glassBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.primary.withAlpha(26)
                        : AppTheme.glassBackground,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    border: Border.all(
                      color: isActive
                          ? AppTheme.primary.withAlpha(51)
                          : AppTheme.glassBorder,
                    ),
                  ),
                  child: Icon(
                    Icons.domain_rounded,
                    size: 18,
                    color: isActive ? AppTheme.primary : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        object.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (object.address.isNotEmpty)
                        Text(
                          object.address,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceM),
            const Divider(color: AppTheme.glassBorder, height: 1),
            const SizedBox(height: AppTheme.spaceM),
            Row(
              children: [
                _StatChip(
                  label: '$workedDays სამ. დღე',
                  icon: Icons.calendar_today_rounded,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: AppTheme.spaceS),
                _StatChip(
                  label: '${AppTheme.formatGel(earned)} გამ.',
                  icon: Icons.trending_up_rounded,
                  color: AppTheme.success,
                ),
                const SizedBox(width: AppTheme.spaceS),
                _StatChip(
                  label: '${AppTheme.formatGel(remaining)} დარ.',
                  icon: Icons.account_balance_wallet_rounded,
                  color: remaining > 0 ? AppTheme.warning : AppTheme.textMuted,
                ),
              ],
            ),
            if (received > 0) ...[
              const SizedBox(height: AppTheme.spaceS),
              Text(
                '${AppTheme.formatGel(received)} მიღებული',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _EmptyObjectsState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyObjectsState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.glassBackground,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: const Icon(
                Icons.domain_rounded,
                size: 32,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: AppTheme.spaceL),
            const Text(
              'ჯერ ობიექტები არ დაგიმატებია',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceS),
            const Text(
              'დაამატე სამუშაო ობიექტი\nდასაწყებად',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceL),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceL,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(color: AppTheme.primary.withAlpha(77)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Text(
                      '+ ახალი ობიექტი',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textMuted),
            SizedBox(height: AppTheme.spaceM),
            Text(
              'ობიექტი ვერ მოიძებნა',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
