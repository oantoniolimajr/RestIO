import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../bloc/rest_provider.dart';
import 'json_viewer.dart';
import 'request_panel.dart';

class ResponsePanel extends StatelessWidget {
  const ResponsePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final restProvider = context.watch<RestProvider>();
    final response = restProvider.response;

    if (response == null) {
      return const Center(
        child: Text(
          'Hit Send to get a response',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(text: 'Body'),
                      Tab(text: 'Cookies'),
                      Tab(text: 'Headers'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _InfoLabel(
                        label: 'Status: ',
                        value: _getStatusText(response),
                        valueColor: response.statusCode! < 400 ? Colors.green : Colors.red,
                      ),
                      const _VerticalDivider(),
                      _InfoLabel(
                        label: 'Time: ',
                        value: '${response.time.inMilliseconds}ms',
                      ),
                      const _VerticalDivider(),
                      _InfoLabel(
                        label: 'Size: ',
                        value: _formatSize(response.requestSize + response.size),
                        tooltip: 'Request: ${_formatSize(response.requestSize)} | Response: ${_formatSize(response.size)}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ResponseBody(data: response.data),
                _ResponseList(title: 'Cookies', items: response.cookies),
                _ResponseMap(title: 'Headers', data: response.headers),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _getStatusText(dynamic response) {
    final code = response.statusCode;
    final msg = response.statusMessage;
    if (msg != null && msg.isNotEmpty) return '$code - $msg';
    
    // Fallback common codes
    final fallbacks = {
      200: 'OK', 201: 'Created', 204: 'No Content',
      400: 'Bad Request', 401: 'Unauthorized', 403: 'Forbidden', 404: 'Not Found',
      500: 'Internal Server Error', 502: 'Bad Gateway', 503: 'Service Unavailable',
    };
    return '$code${fallbacks.containsKey(code) ? " - ${fallbacks[code]}" : ""}';
  }
}

class _InfoLabel extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final String? tooltip;

  const _InfoLabel({required this.label, required this.value, this.valueColor, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ],
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: content);
    }
    return content;
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Theme.of(context).dividerColor.withOpacity(0.2),
    );
  }
}

class _ResponseBody extends StatefulWidget {
  final dynamic data;
  const _ResponseBody({required this.data});

  @override
  State<_ResponseBody> createState() => _ResponseBodyState();
}

class _ResponseBodyState extends State<_ResponseBody> {
  String viewType = 'JSON';
  final JsonViewerController _jsonController = JsonViewerController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _jsonController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.05)),
            ),
          ),
          child: Row(
            children: [
              const Text('Format: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: viewType,
                  isDense: true,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                  onChanged: (val) {
                    setState(() {
                      viewType = val!;
                      _searchController.clear();
                      _jsonController.updateSearch('');
                    });
                  },
                  items: ['JSON', 'Raw'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SearchToolbar(
                  controller: _jsonController,
                  searchController: _searchController,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _FormattedJson(
            data: widget.data, 
            controller: _jsonController,
            isRaw: viewType == 'Raw',
          ),
        ),
      ],
    );
  }
}

class _FormattedJson extends StatelessWidget {
  final dynamic data;
  final JsonViewerController controller;
  final bool isRaw;
  const _FormattedJson({required this.data, required this.controller, required this.isRaw});

  @override
  Widget build(BuildContext context) {
    final restProvider = context.read<RestProvider>();
    
    try {
      dynamic decoded = data;
      if (data is String && !isRaw) {
        try { decoded = jsonDecode(data); } catch (_) { decoded = data; }
      }
      return JsonViewer(
        data: decoded, 
        controller: controller, 
        isRaw: isRaw,
        additionalActions: [
          IconButton(
            icon: const Icon(Icons.import_export, size: 18),
            tooltip: 'Export Full Log (cURL + Response)',
            onPressed: () {
              final log = restProvider.generateFullLog();
              Clipboard.setData(ClipboardData(text: log));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Full log copied to clipboard'),
                  width: 250,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
            ),
          ),
        ],
      );
    } catch (e) {
      return SelectionArea(
        child: Align(
          alignment: Alignment.topLeft,
          child: SelectableText(
            data.toString(),
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          ),
        ),
      );
    }
  }
}

class _ResponseList extends StatelessWidget {
  final String title;
  final List<String> items;
  const _ResponseList({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No cookies found', style: TextStyle(fontSize: 12, color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => ListTile(
        dense: true,
        title: Text(items[index], style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _ResponseMap extends StatelessWidget {
  final String title;
  final Map<String, List<String>> data;
  const _ResponseMap({required this.title, required this.data});

  @override
  Widget build(BuildContext context) {
    final keys = data.keys.toList();
    return ListView.builder(
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        return Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.05))),
          ),
          child: ListTile(
            dense: true,
            title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            subtitle: Text(data[key]!.join(', '), style: const TextStyle(fontSize: 11)),
          ),
        );
      },
    );
  }
}
