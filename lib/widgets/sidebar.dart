import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  int _activeTab = 0; // 0 for Collections, 1 for History
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restProvider = context.watch<RestProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F5F9);

    return Material(
      color: bgColor,
      child: Container(
        width: widget.width,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
        ),
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
          icon: Icon(Icons.folder_outlined, color: _activeTab == 0 ? primaryColor : Colors.grey, size: 20),
          onPressed: () {
            setState(() => _activeTab = 0);
            widget.onToggle();
          },
          tooltip: 'Collections',
        ),
        IconButton(
          icon: Icon(Icons.history, color: _activeTab == 1 ? primaryColor : Colors.grey, size: 20),
          onPressed: () {
            setState(() => _activeTab = 1);
            widget.onToggle();
          },
          tooltip: 'History',
        ),
      ],
    );
  }

  Widget _buildExpandedContent(BuildContext context, RestProvider restProvider, Color bgColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: _buildTabButton(0, 'Collections', Icons.folder_outlined)),
                    const SizedBox(width: 4),
                    Flexible(child: _buildTabButton(1, 'History', Icons.history)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.menu, size: 18),
                onPressed: widget.onToggle,
                tooltip: 'Collapse Sidebar',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 14, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 14), 
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _activeTab == 0 
            ? _CollectionsTreeView(restProvider: restProvider, searchQuery: _searchQuery)
            : _HistoryView(restProvider: restProvider, searchQuery: _searchQuery),
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
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11, 
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? primaryColor : Colors.grey,
                ),
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
  final String searchQuery;
  const _HistoryView({required this.restProvider, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    var history = restProvider.history;
    
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      history = history.where((item) {
        final url = item.request.url.toLowerCase();
        final method = item.request.method.name.toLowerCase();
        return url.contains(query) || method.contains(query);
      }).toList();
    }

    if (history.isEmpty) {
      return Center(
        child: Text(
          searchQuery.isEmpty ? 'No history yet' : 'No results found', 
          style: const TextStyle(color: Colors.grey, fontSize: 12)
        )
      );
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
      builder: (context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () {
            provider.clearHistory();
            Navigator.pop(context);
          },
        },
        child: AlertDialog(
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
      ),
    );
  }
}

class _CollectionsTreeView extends StatelessWidget {
  final RestProvider restProvider;
  final String searchQuery;
  const _CollectionsTreeView({required this.restProvider, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final collections = restProvider.collections;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Collections', 
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                )
              ),
              if (searchQuery.isEmpty)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  onPressed: () => _showCreateCollectionDialog(context),
                  tooltip: 'New Collection',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
            ],
          ),
        ),
        if (collections.isEmpty)
          const Expanded(child: Center(child: Text('No collections yet', style: TextStyle(color: Colors.grey, fontSize: 12))))
        else
          Expanded(
            child: ListView.builder(
              itemCount: collections.length,
              itemBuilder: (context, index) {
                final col = collections[index];
                
                if (searchQuery.isNotEmpty && !_matchesSearch(col)) {
                  return const SizedBox.shrink();
                }

                return _TreeNode(
                  key: ValueKey(col.id),
                  id: col.id,
                  name: col.name,
                  folders: col.folders,
                  requests: col.requests,
                  level: 0,
                  restProvider: restProvider,
                  isCollection: true,
                  searchQuery: searchQuery,
                );
              },
            ),
          ),
      ],
    );
  }

  bool _matchesSearch(CollectionModel col) {
    final query = searchQuery.toLowerCase();
    if (col.name.toLowerCase().contains(query)) return true;
    for (var f in col.folders) {
      if (_folderMatchesSearch(f, query)) return true;
    }
    for (var r in col.requests) {
      if (_requestMatchesSearch(r, query)) return true;
    }
    return false;
  }

  bool _folderMatchesSearch(FolderModel folder, String query) {
    if (folder.name.toLowerCase().contains(query)) return true;
    for (var f in folder.folders) {
      if (_folderMatchesSearch(f, query)) return true;
    }
    for (var r in folder.requests) {
      if (_requestMatchesSearch(r, query)) return true;
    }
    return false;
  }

  bool _requestMatchesSearch(SavedRequestModel req, String query) {
    if (req.name.toLowerCase().contains(query)) return true;
    if (req.request.url.toLowerCase().contains(query)) return true;
    if (req.request.method.name.toLowerCase().contains(query)) return true;
    return false;
  }

  void _showCreateCollectionDialog(BuildContext context) {
    final controller = TextEditingController();
    void submit() {
      if (controller.text.isNotEmpty) {
        restProvider.createCollection(controller.text);
        Navigator.pop(context);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Collection'),
        content: TextField(
          controller: controller, 
          autofocus: true, 
          decoration: const InputDecoration(hintText: 'Collection Name'),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: submit,
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
  }
}

class _TreeNode extends StatefulWidget {
  final String id;
  final String name;
  final List<FolderModel> folders;
  final List<SavedRequestModel> requests;
  final int level;
  final RestProvider restProvider;
  final bool isCollection;
  final String searchQuery;

  const _TreeNode({
    super.key,
    required this.id,
    required this.name,
    required this.folders,
    required this.requests,
    required this.level,
    required this.restProvider,
    this.isCollection = false,
    this.searchQuery = '',
  });

  @override
  State<_TreeNode> createState() => _TreeNodeState();
}

class _TreeNodeState extends State<_TreeNode> {
  bool _isExpanded = true;

  @override
  void didUpdateWidget(_TreeNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery && widget.searchQuery.isNotEmpty) {
      setState(() {
        _isExpanded = true;
      });
    }
  }

  bool _folderMatchesSearch(FolderModel folder, String query) {
    if (folder.name.toLowerCase().contains(query)) return true;
    for (var f in folder.folders) {
      if (_folderMatchesSearch(f, query)) return true;
    }
    for (var r in folder.requests) {
      if (_requestMatchesSearch(r, query)) return true;
    }
    return false;
  }

  bool _requestMatchesSearch(SavedRequestModel req, String query) {
    if (req.name.toLowerCase().contains(query)) return true;
    if (req.request.url.toLowerCase().contains(query)) return true;
    if (req.request.method.name.toLowerCase().contains(query)) return true;
    return false;
  }

  bool _anyChildMatches(String query) {
    for (var f in widget.folders) {
      if (_folderMatchesSearch(f, query)) return true;
    }
    for (var r in widget.requests) {
      if (_requestMatchesSearch(r, query)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.searchQuery.toLowerCase();
    final bool nameMatches = query.isNotEmpty && widget.name.toLowerCase().contains(query);
    
    // If searching, only show this node if it matches OR if any child matches
    if (query.isNotEmpty && !nameMatches && !_anyChildMatches(query)) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DragTarget<Map<String, dynamic>>(
          onWillAccept: (data) => data != null && data['id'] != widget.id,
          onAccept: (data) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.restProvider.moveItem(data['id']!, widget.id, data['isFolder']!);
            });
          },
          builder: (context, candidateData, rejectedData) {
            return Draggable<Map<String, dynamic>>(
              data: {'id': widget.id, 'isFolder': true},
              hitTestBehavior: HitTestBehavior.opaque,
              onDragStarted: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.restProvider.setDragging(true);
                });
              },
              onDragEnd: (_) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.restProvider.setDragging(false);
                });
              },
              feedback: Material(
                color: Colors.transparent,
                child: Opacity(
                  opacity: 0.8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.isCollection ? Icons.inventory_2_outlined : Icons.folder_outlined, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          widget.name,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _TreeTile(
                  level: widget.level,
                  label: widget.name,
                  icon: Icon(_isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, size: 16),
                  folderIcon: Icon(
                    widget.isCollection ? Icons.inventory_2_outlined : Icons.folder_outlined, 
                    size: 18, 
                    color: widget.isCollection ? Theme.of(context).colorScheme.primary : Colors.amber
                  ),
                  onTap: () {},
                  actions: [],
                  isHighlighted: false,
                  showHover: false,
                ),
              ),
              child: _TreeTile(
                level: widget.level,
                label: widget.name,
                icon: Icon(_isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, size: 16, color: Colors.grey),
                folderIcon: Icon(
                  widget.isCollection ? Icons.inventory_2_outlined : Icons.folder_outlined, 
                  size: 18, 
                  color: widget.isCollection ? Theme.of(context).colorScheme.primary : Colors.amber
                ),
                isHighlighted: candidateData.isNotEmpty,
                onTap: () {
                  if (mounted) setState(() => _isExpanded = !_isExpanded);
                },
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add_box_outlined, size: 14),
                    onPressed: () => _showCreateRequestDialog(context),
                    tooltip: 'New Request',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                  IconButton(
                    icon: const Icon(Icons.create_new_folder_outlined, size: 14),
                    onPressed: () => _showCreateFolderDialog(context),
                    tooltip: 'New Folder',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_all, size: 14),
                    onPressed: () => _confirmDuplicate(context),
                    tooltip: 'Duplicate',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    onPressed: () => _showRenameDialog(context),
                    tooltip: 'Rename',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 14),
                    onPressed: () => _confirmDelete(context),
                    tooltip: 'Delete',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            );
          },
        ),
        if (_isExpanded) ...[
          ...widget.folders
              .where((f) => widget.searchQuery.isEmpty || nameMatches || _folderMatchesSearch(f, query))
              .map((f) => _TreeNode(
                key: ValueKey(f.id),
                id: f.id,
                name: f.name,
                folders: f.folders,
                requests: f.requests,
                level: widget.level + 1,
                restProvider: widget.restProvider,
                searchQuery: nameMatches ? '' : widget.searchQuery,
              )),
          ...widget.requests
              .where((r) => widget.searchQuery.isEmpty || nameMatches || _requestMatchesSearch(r, query))
              .map((req) => _RequestLeaf(
                key: ValueKey(req.id),
                req: req,
                parentId: widget.id,
                level: widget.level + 1,
                restProvider: widget.restProvider,
              )),
        ],
      ],
    );
  }

  void _showCreateFolderDialog(BuildContext context) {
    final controller = TextEditingController();
    void submit() {
      if (controller.text.isNotEmpty) {
        widget.restProvider.createFolder(widget.id, controller.text);
        Navigator.pop(context);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller, 
          autofocus: true, 
          decoration: const InputDecoration(hintText: 'Folder Name'),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: submit,
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
  }

  void _showCreateRequestDialog(BuildContext context) {
    final controller = TextEditingController();
    void submit() {
      if (controller.text.isNotEmpty) {
        widget.restProvider.saveRequestToParent(widget.id, controller.text, RequestModel());
        Navigator.pop(context);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Request'),
        content: TextField(
          controller: controller, 
          autofocus: true, 
          decoration: const InputDecoration(hintText: 'Request Name'),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: submit,
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
  }

  void _confirmDuplicate(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.isCollection ? 'Duplicate Collection?' : 'Duplicate Folder?'),
        content: Text('Are you sure you want to duplicate "${widget.name}" and all its contents?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              if (widget.isCollection) {
                widget.restProvider.duplicateCollection(widget.id);
              } else {
                widget.restProvider.duplicateFolder(widget.id);
              }
              Navigator.pop(context);
            },
            child: const Text('DUPLICATE'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.name);
    void submit() {
      if (controller.text.isNotEmpty) {
        if (widget.isCollection) {
          widget.restProvider.renameCollection(widget.id, controller.text);
        } else {
          widget.restProvider.renameFolder(widget.id, controller.text);
        }
        Navigator.pop(context);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.isCollection ? 'Rename Collection' : 'Rename Folder'),
        content: TextField(
          controller: controller, 
          autofocus: true, 
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: submit,
            child: const Text('RENAME'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    void submit() {
      if (widget.isCollection) {
        widget.restProvider.deleteCollection(widget.id);
      } else {
        widget.restProvider.deleteFolder(widget.id);
      }
      Navigator.pop(context);
    }

    showDialog(
      context: context,
      builder: (context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () => submit(),
        },
        child: AlertDialog(
          title: Text(widget.isCollection ? 'Delete Collection?' : 'Delete Folder?'),
          content: Text('Are you sure you want to delete "${widget.name}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            TextButton(
              onPressed: submit,
              child: const Text('DELETE', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestLeaf extends StatelessWidget {
  final SavedRequestModel req;
  final String parentId;
  final int level;
  final RestProvider restProvider;

  const _RequestLeaf({
    super.key,
    required this.req,
    required this.parentId,
    required this.level,
    required this.restProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Draggable<Map<String, dynamic>>(
      data: {'id': req.id, 'isFolder': false},
      hitTestBehavior: HitTestBehavior.opaque,
      onDragStarted: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          restProvider.setDragging(true);
        });
      },
      onDragEnd: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          restProvider.setDragging(false);
        });
      },
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  req.request.method.name.substring(0, 3),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, decoration: TextDecoration.none),
                ),
                const SizedBox(width: 8),
                Text(
                  req.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13, decoration: TextDecoration.none),
                ),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _TreeTile(
          level: level,
          label: req.name,
          method: req.request.method,
          onTap: () {},
          actions: [],
          isHighlighted: false,
          showHover: false,
        ),
      ),
      child: _TreeTile(
        level: level,
        label: req.name,
        method: req.request.method,
        onTap: () {
          restProvider.loadFromCollection(req);
        },
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all, size: 12),
            onPressed: () => _confirmDuplicate(context),
            tooltip: 'Duplicate',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 12),
            onPressed: () => _showRenameDialog(context),
            tooltip: 'Rename',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 12),
            onPressed: () => _confirmDelete(context),
            tooltip: 'Delete',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
        ],
        isHighlighted: false,
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: req.name);
    void submit() {
      if (controller.text.isNotEmpty) {
        restProvider.renameRequestInCollection(req.id, controller.text);
        Navigator.pop(context);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Request'),
        content: TextField(
          controller: controller, 
          autofocus: true, 
          decoration: const InputDecoration(hintText: 'Request Name'),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: submit,
            child: const Text('RENAME'),
          ),
        ],
      ),
    );
  }

  void _confirmDuplicate(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Request?'),
        content: Text('Are you sure you want to duplicate "${req.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              restProvider.duplicateRequest(req.id);
              Navigator.pop(context);
            },
            child: const Text('DUPLICATE'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    void submit() {
      restProvider.deleteRequestFromParent(req.id);
      Navigator.pop(context);
    }

    showDialog(
      context: context,
      builder: (context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () => submit(),
        },
        child: AlertDialog(
          title: const Text('Delete Request?'),
          content: Text('Are you sure you want to delete "${req.name}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            TextButton(
              onPressed: submit,
              child: const Text('DELETE', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeTile extends StatefulWidget {
  final int level;
  final String label;
  final Widget? icon;
  final Widget? folderIcon;
  final HttpMethod? method;
  final VoidCallback onTap;
  final List<Widget> actions;
  final bool isHighlighted;
  final bool showHover;

  const _TreeTile({
    required this.level,
    required this.label,
    this.icon,
    this.folderIcon,
    this.method,
    required this.onTap,
    required this.actions,
    required this.isHighlighted,
    this.showHover = true,
  });

  @override
  State<_TreeTile> createState() => _TreeTileState();
}

class _TreeTileState extends State<_TreeTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final restProvider = context.watch<RestProvider>();
    final isDragging = restProvider.isDragging;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate indent but ensure we leave at least 60px for the content
        final double effectiveIndent = (widget.level * 24.0).clamp(0.0, (constraints.maxWidth - 60.0).clamp(0.0, double.infinity));

        Widget content = InkWell(
          onTap: widget.onTap,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.isHighlighted ? Theme.of(context).colorScheme.primary.withOpacity(0.15) : Colors.transparent,
            ),
            padding: EdgeInsets.only(
              left: 12.0 + effectiveIndent,
              right: 8.0, 
              top: 8.0, 
              bottom: 8.0
            ),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  widget.icon!,
                  const SizedBox(width: 8),
                ],
                if (widget.folderIcon != null) ...[
                  widget.folderIcon!,
                  const SizedBox(width: 10),
                ],
                if (widget.method != null) ...[
                  Flexible(
                    flex: 0,
                    child: SizedBox(
                      width: 32,
                      child: Text(
                        widget.method!.name.substring(0, 3),
                        style: TextStyle(
                          color: widget.method!.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Tooltip(
                    message: widget.label,
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: widget.level == 0 ? 13 : 12,
                        fontWeight: widget.level == 0 ? FontWeight.bold : FontWeight.normal,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_isHovering && !isDragging)
                  Flexible(
                    flex: 0,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.actions,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );

        if (!widget.showHover || isDragging) return content;

        return MouseRegion(
          onEnter: (_) {
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isHovering = true);
              });
            }
          },
          onExit: (_) {
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isHovering = false);
              });
            }
          },
          child: content,
        );
      },
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      method.name,
                      style: TextStyle(
                        color: method.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
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
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _formatTime(item.timestamp),
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
