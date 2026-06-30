import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bloc/rest_provider.dart';
import '../models/history_model.dart';
import '../models/collection_model.dart';
import '../models/request_model.dart';

class Sidebar extends StatefulWidget {
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
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  int _activeTab = 0; // 0 for History, 1 for Collections

  @override
  Widget build(BuildContext context) {
    final restProvider = context.watch<RestProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F5F9);

    return Material(
      color: bgColor,
      child: Container(
        width: widget.width,
        child: widget.isCollapsed 
          ? _buildCollapsedContent(context)
          : _buildExpandedContent(context, restProvider, bgColor),
      ),
    );
  }

  Widget _buildCollapsedContent(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        const SizedBox(height: 12),
        IconButton(
          icon: const Icon(Icons.menu_open, size: 20),
          onPressed: widget.onToggle,
          tooltip: 'Expand Sidebar',
        ),
        const SizedBox(height: 12),
        IconButton(
          icon: Icon(Icons.history, color: _activeTab == 0 ? primaryColor : Colors.grey, size: 20),
          onPressed: () {
            setState(() => _activeTab = 0);
            widget.onToggle();
          },
        ),
        IconButton(
          icon: Icon(Icons.folder_outlined, color: _activeTab == 1 ? primaryColor : Colors.grey, size: 20),
          onPressed: () {
            setState(() => _activeTab = 1);
            widget.onToggle();
          },
        ),
      ],
    );
  }

  Widget _buildExpandedContent(BuildContext context, RestProvider restProvider, Color bgColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar Header & Tab Toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    _buildTabButton(0, 'History', Icons.history),
                    const SizedBox(width: 4),
                    _buildTabButton(1, 'Collections', Icons.folder_outlined),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.menu, size: 18),
                onPressed: widget.onToggle,
                tooltip: 'Collapse Sidebar',
              ),
            ],
          ),
        ),
        const SizedBox(height: 1),
        Expanded(
          child: _activeTab == 0 
            ? _HistoryView(restProvider: restProvider)
            : _CollectionsView(restProvider: restProvider),
        ),
      ],
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isActive = _activeTab == index;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? primaryColor : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11, 
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? primaryColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryView extends StatelessWidget {
  final RestProvider restProvider;
  const _HistoryView({required this.restProvider});

  @override
  Widget build(BuildContext context) {
    final history = restProvider.history;
    if (history.isEmpty) {
      return const Center(child: Text('No history yet', style: TextStyle(color: Colors.grey, fontSize: 12)));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _confirmClear(context, restProvider),
              icon: const Icon(Icons.delete_sweep_outlined, size: 14),
              label: const Text('Clear', style: TextStyle(fontSize: 11)),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) => _HistoryTile(item: history[index], restProvider: restProvider),
          ),
        ),
      ],
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

class _CollectionsView extends StatelessWidget {
  final RestProvider restProvider;
  const _CollectionsView({required this.restProvider});

  @override
  Widget build(BuildContext context) {
    final collections = restProvider.collections;
    if (collections.isEmpty) {
      return const Center(child: Text('No collections yet', style: TextStyle(color: Colors.grey, fontSize: 12)));
    }
    return ListView.builder(
      itemCount: collections.length,
      itemBuilder: (context, index) {
        final col = collections[index];
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(col.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            leading: const Icon(Icons.folder, size: 18, color: Colors.amber),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  onPressed: () => _showRenameDialog(context, col.id, col.name, true),
                  tooltip: 'Rename Collection',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  onPressed: () => _confirmDelete(context, col.name, () => restProvider.deleteCollection(col.id), true),
                  tooltip: 'Delete Collection',
                ),
              ],
            ),
            children: col.requests.map((req) => ListTile(
              dense: true,
              title: Text(req.name, style: const TextStyle(fontSize: 12)),
              subtitle: Text(req.request.method.name, style: TextStyle(color: req.request.method.color, fontSize: 10, fontWeight: FontWeight.bold)),
              onTap: () {
                restProvider.request = req.request.copy();
                restProvider.refresh();
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    onPressed: () => _showRenameDialog(context, col.id, req.name, false, requestId: req.id),
                    tooltip: 'Rename Request',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    onPressed: () => _confirmDelete(context, req.name, () => restProvider.deleteRequestFromCollection(col.id, req.id), false),
                    tooltip: 'Delete Request',
                  ),
                ],
              ),
            )).toList(),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String name, VoidCallback onConfirm, bool isCollection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCollection ? 'Delete Collection?' : 'Delete Request?'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, String collectionId, String currentName, bool isCollection, {String? requestId}) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCollection ? 'Rename Collection' : 'Rename Request'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: isCollection ? 'Collection Name' : 'Request Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                if (isCollection) {
                  restProvider.renameCollection(collectionId, controller.text);
                } else {
                  restProvider.renameRequestInCollection(collectionId, requestId!, controller.text);
                }
                Navigator.pop(context);
              }
            },
            child: const Text('RENAME'),
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
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => restProvider.loadFromHistory(item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
