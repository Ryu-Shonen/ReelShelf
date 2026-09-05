import 'package:flutter/material.dart';

import '../services/upc_itemdb_service.dart';

class PhysicalReleaseSearchScreen extends StatefulWidget {
  const PhysicalReleaseSearchScreen({super.key});

  @override
  State<PhysicalReleaseSearchScreen> createState() =>
      _PhysicalReleaseSearchScreenState();
}

class _PhysicalReleaseSearchScreenState
    extends State<PhysicalReleaseSearchScreen> {
  final _controller = TextEditingController();
  final _service = const UpcItemDbService();

  List<UpcItem> _results = const [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
    });

    try {
      final results = await _service.search(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _error = error.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ausgabe oder Boxset suchen')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controller,
                  enabled: !_loading,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'z. B. Hayao Miyazaki Collection',
                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                    suffixIcon: IconButton(
                      onPressed: _loading ? null : _search,
                      icon: const Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Die Suche nutzt die kostenlose Produktdatenbank UPCitemdb. Für eine exakte Ausgabe ist der Barcode meist zuverlässiger als die Textsuche.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: !_searched
                ? _EmptyMessage(
                    icon: Icons.all_inbox_outlined,
                    text:
                        'Suche nach einer konkreten Blu-ray, 4K UHD, Sonderedition oder Collection.',
                  )
                : _results.isEmpty
                    ? const _EmptyMessage(
                        icon: Icons.search_off_rounded,
                        text: 'Keine passende physische Ausgabe gefunden.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return _ReleaseResultCard(
                            item: item,
                            onTap: () => Navigator.of(context).pop(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseResultCard extends StatelessWidget {
  const _ReleaseResultCard({
    required this.item,
    required this.onTap,
  });

  final UpcItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductImage(url: item.primaryImage),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    if (item.brand.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _SmallBadge(item.suggestedMediaFormat),
                        if (item.ean.isNotEmpty)
                          _SmallBadge('EAN ${item.ean}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 96,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: url == null
          ? const Icon(Icons.album_outlined, size: 28)
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.album_outlined, size: 28),
            ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 42,
              color: Colors.white.withValues(alpha: 0.28),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
