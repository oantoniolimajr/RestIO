import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'bloc/rest_provider.dart';
import 'bloc/theme_provider.dart';
import 'models/request_model.dart';
import 'models/collection_model.dart';
import 'widgets/request_panel.dart';
import 'widgets/response_panel.dart';
import 'bootstrap_theme.dart';
import 'widgets/sidebar.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => RestProvider()),
      ],
      child: const RestIOApp(),
    ),
  );
}

class RestIOApp extends StatelessWidget {
  const RestIOApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'RestIO',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: BootstrapTheme.lightTheme,
      darkTheme: BootstrapTheme.darkTheme,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _urlController = TextEditingController();
  double _sidebarWidth = 260.0;
  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final restProvider = context.read<RestProvider>();
      _urlController.text = restProvider.request.url;
      restProvider.addListener(_onRestProviderChanged);
    });
  }

  @override
  void dispose() {
    context.read<RestProvider>().removeListener(_onRestProviderChanged);
    _urlController.dispose();
    super.dispose();
  }

  void _onRestProviderChanged() {
    final url = context.read<RestProvider>().request.url;
    if (_urlController.text != url) {
      _urlController.text = url;
    }
  }

  void _showSaveDialog(BuildContext context, RestProvider provider) {
    final nameController = TextEditingController(text: provider.request.url);
    String? selectedParentId;

    // Helper to flatten collections and folders for the dropdown
    List<Map<String, dynamic>> parentItems = [];
    
    void addFolders(List<FolderModel> folders, int level) {
      for (var folder in folders) {
        parentItems.add({
          'id': folder.id,
          'name': folder.name,
          'level': level,
          'isCollection': false,
        });
        addFolders(folder.folders, level + 1);
      }
    }

    for (var col in provider.collections) {
      parentItems.add({
        'id': col.id,
        'name': col.name,
        'level': 0,
        'isCollection': true,
      });
      addFolders(col.folders, 1);
    }

    // Pre-select first parent if exists
    if (parentItems.isNotEmpty) {
      selectedParentId = parentItems.first['id'];
    }

    void submit() {
      if (selectedParentId != null && nameController.text.trim().isNotEmpty) {
        provider.saveRequestToParent(selectedParentId!, nameController.text.trim(), provider.request);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to collection'), 
            behavior: SnackBarBehavior.floating, 
            width: 250,
          )
        );
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          void submit() {
            if (selectedParentId != null && nameController.text.trim().isNotEmpty) {
              provider.saveRequestToParent(selectedParentId!, nameController.text.trim(), provider.request);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Saved to collection'), 
                  behavior: SnackBarBehavior.floating, 
                  width: 250,
                )
              );
            }
          }

          return CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter): submit,
              const SingleActivator(LogicalKeyboardKey.numpadEnter): submit,
            },
            child: AlertDialog(
              title: const Text('Save Request'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(hintText: 'e.g. Get User Invoices'),
                      onChanged: (_) => setDialogState(() {}), // Refresh Save button state
                      onSubmitted: (_) => submit(),
                    ),
                const SizedBox(height: 16),
                const Text('Location', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 4),
                if (provider.collections.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'No collections found. Create one below to save.',
                      style: TextStyle(fontSize: 12, color: Colors.amber),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).inputDecorationTheme.fillColor,
                      border: Border.all(color: Theme.of(context).inputDecorationTheme.enabledBorder!.borderSide.color),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedParentId,
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                        onChanged: (val) => setDialogState(() => selectedParentId = val),
                        items: parentItems.map((item) {
                          final int level = item['level'];
                          final bool isCol = item['isCollection'];
                          return DropdownMenuItem<String>(
                            value: item['id'],
                            child: Padding(
                              padding: EdgeInsets.only(left: level * 16.0),
                              child: Row(
                                children: [
                                  Icon(
                                    isCol ? Icons.inventory_2_outlined : Icons.folder_outlined,
                                    size: 16,
                                    color: isCol ? Theme.of(context).colorScheme.primary : Colors.amber,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(item['name']),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    final newColController = TextEditingController();
                    void submitNewCollection() {
                      if (newColController.text.isNotEmpty) {
                        provider.createCollection(newColController.text);
                        final newId = provider.collections.last.id;
                        Navigator.pop(context);
                        
                        // Rebuild parent items for the outer dialog
                        parentItems.add({
                          'id': newId,
                          'name': newColController.text,
                          'level': 0,
                          'isCollection': true,
                        });

                        setDialogState(() {
                          selectedParentId = newId;
                        });
                      }
                    }

                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('New Collection'),
                        content: TextField(
                          controller: newColController,
                          autofocus: true,
                          decoration: const InputDecoration(hintText: 'Collection Name'),
                          onSubmitted: (_) => submitNewCollection(),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                          ElevatedButton(
                            onPressed: submitNewCollection,
                            child: const Text('CREATE'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create New Collection', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: (selectedParentId == null || nameController.text.trim().isEmpty) 
                ? null 
                : submit,
              child: const Text('SAVE'),
            ),
          ],
        ),
      );
    },
  ),
);
}

  @override
  Widget build(BuildContext context) {
    final restProvider = context.watch<RestProvider>();
    final themeProvider = context.read<ThemeProvider>();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () => restProvider.sendRequest(),
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () => restProvider.sendRequest(),
      },
      child: Scaffold(
        body: Row(
          children: [
            Sidebar(
              width: _sidebarCollapsed ? 48.0 : _sidebarWidth,
              isCollapsed: _sidebarCollapsed,
              onToggle: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            ),
            if (!_sidebarCollapsed)
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    double newWidth = _sidebarWidth + details.delta.dx;
                    if (newWidth >= 150 && newWidth <= 500) {
                      _sidebarWidth = newWidth;
                    }
                  });
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor.withOpacity(0.05),
                      border: Border(
                        left: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2), width: 1),
                      ),
                    ),
                    height: double.infinity,
                    child: Center(
                      child: Container(
                        width: 1,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  // Top Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF1F5F9) : const Color(0xFF2D2D2D),
                            border: Border.all(color: Theme.of(context).inputDecorationTheme.enabledBorder!.borderSide.color),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              bottomLeft: Radius.circular(6),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<HttpMethod>(
                              value: restProvider.request.method,
                              onChanged: (val) => restProvider.updateMethod(val!),
                              isDense: true,
                              style: TextStyle(
                                color: restProvider.request.method.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              items: HttpMethod.values.map((m) {
                                return DropdownMenuItem(
                                  value: m, 
                                  child: Text(
                                    m.name,
                                    style: TextStyle(color: m.color),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: TextField(
                              controller: _urlController,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'https://api.example.com/v1/resource',
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                  borderSide: BorderSide(color: Theme.of(context).inputDecorationTheme.enabledBorder!.borderSide.color),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                                ),
                              ),
                              onChanged: (val) => restProvider.updateUrl(val),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: restProvider.isLoading ? null : () => restProvider.sendRequest(),
                            style: ElevatedButton.styleFrom(
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(0),
                                  bottomRight: Radius.circular(0),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                            ),
                            child: restProvider.isLoading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('SEND', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 13)),
                          ),
                        ),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              if (restProvider.activeSavedRequestId != null) {
                                restProvider.updateActiveSavedRequest();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Request updated'), 
                                    behavior: SnackBarBehavior.floating, 
                                    width: 250,
                                  )
                                );
                              } else {
                                _showSaveDialog(context, restProvider);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(6),
                                  bottomRight: Radius.circular(6),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: Icon(
                              restProvider.activeSavedRequestId != null ? Icons.save : Icons.bookmark_add_outlined, 
                              size: 18, 
                              color: Colors.white
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.code, size: 20),
                          onPressed: () {
                            final curl = restProvider.generateCurl();
                            showDialog(
                              context: context,
                              builder: (context) {
                                void copy() {
                                  Clipboard.setData(ClipboardData(text: curl));
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('cURL copied to clipboard'),
                                      behavior: SnackBarBehavior.floating,
                                      width: 250,
                                    ),
                                  );
                                }

                                return CallbackShortcuts(
                                  bindings: {
                                    const SingleActivator(LogicalKeyboardKey.enter): copy,
                                    const SingleActivator(LogicalKeyboardKey.numpadEnter): copy,
                                  },
                                  child: AlertDialog(
                                    title: const Text('cURL Preview'),
                                    content: Container(
                                      width: 600,
                                      constraints: const BoxConstraints(maxHeight: 400),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness == Brightness.dark 
                                            ? const Color(0xFF1E1E1E) 
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                                      ),
                                      child: SingleChildScrollView(
                                        child: SelectableText(
                                          curl,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('CLOSE'),
                                      ),
                                      ElevatedButton(
                                        autofocus: true,
                                        onPressed: copy,
                                        child: const Text('COPY'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          tooltip: 'Preview & Copy as cURL',
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 20),
                          onPressed: () => themeProvider.toggleTheme(),
                          tooltip: 'Toggle Theme',
                        ),
                      ],
                    ),
                  ),
                  // Resizable Panels
                  Expanded(
                    child: _ResizablePanels(
                      topPanel: const RequestPanel(),
                      bottomPanel: const ResponsePanel(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResizablePanels extends StatefulWidget {
  final Widget topPanel;
  final Widget bottomPanel;

  const _ResizablePanels({required this.topPanel, required this.bottomPanel});

  @override
  State<_ResizablePanels> createState() => _ResizablePanelsState();
}

class _ResizablePanelsState extends State<_ResizablePanels> {
  double _topHeightFactor = 0.4;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            SizedBox(
              height: constraints.maxHeight * _topHeightFactor,
              child: widget.topPanel,
            ),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (details) {
                setState(() {
                  double newHeight = (constraints.maxHeight * _topHeightFactor) + details.delta.dy;
                  // Enforce minimum height of 150px for top and 100px for bottom
                  if (newHeight >= 150 && newHeight <= constraints.maxHeight - 100) {
                    _topHeightFactor = newHeight / constraints.maxHeight;
                  }
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpDown,
                child: Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withOpacity(0.05),
                    border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1), width: 0.5),
                      bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1), width: 0.5),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      height: 1.5,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: widget.bottomPanel,
            ),
          ],
        );
      },
    );
  }
}
