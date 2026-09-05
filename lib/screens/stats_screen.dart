import 'package:flutter/material.dart';

import '../state/app_state.dart';

class StatsView extends StatelessWidget {
  const StatsView({super.key});

  @override
  Widget build(BuildContext context) {
    final items = AppStateScope.of(context).ownedItems;
    final totalValue = items.fold<double>(0, (sum, item) => sum + (item.purchasePrice ?? 0));
    final favorites = items.where((e) => e.favorite).length;
    final fourK = items.where((e) => e.mediaFormat == '4K UHD').length;
    final bluRay = items.where((e) => e.mediaFormat == 'Blu-ray').length;
    final steelbooks = items.where((e) => e.mediaFormat == 'Steelbook').length;
    final withPrice = items.where((e) => e.purchasePrice != null).length;
    final totalRuntime = items.fold<int>(0, (sum, item) => sum + (item.runtime ?? 0));

    final formatCounts = <String, int>{};
    for (final item in items) {
      formatCounts[item.mediaFormat] = (formatCounts[item.mediaFormat] ?? 0) + 1;
    }
    final sortedFormats = formatCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
      children: [
        _HeroStat(
          count: items.length.toString(),
          label: 'Filme in deiner Sammlung',
          icon: Icons.local_movies_rounded,
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            _StatCard(label: '4K UHD', value: '$fourK', icon: Icons.hd_rounded),
            _StatCard(label: 'Blu-rays', value: '$bluRay', icon: Icons.album_rounded),
            _StatCard(label: 'Steelbooks', value: '$steelbooks', icon: Icons.auto_awesome_rounded),
            _StatCard(label: 'Favoriten', value: '$favorites', icon: Icons.favorite_rounded),
          ],
        ),
        const SizedBox(height: 22),
        Text('Sammlungswert', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.euro_rounded, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${totalValue.toStringAsFixed(2).replaceAll('.', ',')} €',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Kaufpreise für $withPrice von ${items.length} Filmen erfasst',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text('Formate', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: sortedFormats.isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('Noch keine Daten vorhanden.'),
                      )
                    ]
                  : sortedFormats
                      .map(
                        (entry) => ListTile(
                          title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                          trailing: Text(
                            entry.value.toString(),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Card(
          child: ListTile(
            leading: const Icon(Icons.schedule_rounded),
            title: const Text('Gesamtlaufzeit', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Nur Filme mit hinterlegter Laufzeit'),
            trailing: Text(
              totalRuntime == 0 ? '–' : '${(totalRuntime / 60).toStringAsFixed(1)} h',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.count, required this.label, required this.icon});
  final String count;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B7A).withValues(alpha: 0.95),
            const Color(0xFF8C5CFF).withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(count, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, height: 1)),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Icon(icon, size: 58, color: Colors.white.withValues(alpha: 0.85)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFF6B7A)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  Text(label, maxLines: 1, style: TextStyle(color: Colors.white.withValues(alpha: 0.55))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
