import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bloc/rest_provider.dart';
import '../models/history_model.dart';
import '../models/request_model.dart';

class Sidebar extends StatelessWidget {
  final double width;
  final bool isCollapsed;
  final VoidCallback onToggle;

  const Sidebar({
    super.key, 
    required this.width, 
    required this.isCollapsed, 
    required this.onToggle
  });

  @override
  Widget build(BuildContext context) {
    final restProvider = context.watch<RestProvider>();
    final history = restProvider.history;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F5F9);

    if (isCollapsed) {
      return Container(
        width: width,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            IconButton(
              icon: const Icon(Icons.menu_open, size: 20),
              onPressed: onToggle,
              tooltip: 'Expand Sidebar',
            ),
            const SizedBox(height: 12),
            const Icon(Icons.history, size: 20, color: Colors.grey),
          ],
        ),
      );
    }

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history, size: 18, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'HISTORY',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (history.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.grey),
                        onPressed: () => _confirmClear(context, restProvider),
                        tooltip: 'Clear History',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.menu, size: 18),
                      onPressed: onToggle,
                      tooltip: 'Collapse Sidebar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: history.isEmpty
                ? const Center(
                    child: Text(
                      'No history yet',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      return _HistoryTile(item: item, restProvider: restProvider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, RestProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text('This will remove all 50 last requests.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              provider.clearHistory();
              Navigator.pop(context);
            },
            child: const Text('CLEAR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryItem item;
  final RestProvider restProvider;

  const _HistoryTile({required this.item, required this.restProvider});

  @override
  Widget build(BuildContext context) {
    final method = item.request.method;
    final url = item.request.url.isEmpty ? '(No URL)' : item.request.url;
    
    return InkWell(
      onTap: () => restProvider.loadFromHistory(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.05))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  method.name,
                  style: TextStyle(
                    color: method.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 8),
                if (item.statusCode != null)
                  Text(
                    '${item.statusCode}',
                    style: TextStyle(
                      color: item.statusCode! >= 200 && item.statusCode! < 300 ? Colors.green : Colors.red,
                      fontSize: 10,
                    ),
                  ),
                const Spacer(),
                Text(
                  _formatTime(item.timestamp),
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
