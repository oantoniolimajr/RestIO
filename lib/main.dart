import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'bloc/rest_provider.dart';
import 'bloc/theme_provider.dart';
import 'models/request_model.dart';
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
                    width: 4,
                    color: Colors.transparent,
                    height: double.infinity,
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
                                  topRight: Radius.circular(6),
                                  bottomRight: Radius.circular(6),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                            ),
                            child: restProvider.isLoading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('SEND', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.code, size: 20),
                          onPressed: () {
                            final curl = restProvider.generateCurl();
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
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
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: curl));
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('cURL copied to clipboard'),
                                          behavior: SnackBarBehavior.floating,
                                          width: 250,
                                        ),
                                      );
                                    },
                                    child: const Text('COPY'),
                                  ),
                                ],
                              ),
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
  double _topHeightFactor = 0.5;

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
                  height: 10,
                  width: double.infinity,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      height: 1,
                      width: 60,
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
