import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../bloc/rest_provider.dart';
import '../models/request_model.dart';
import 'json_viewer.dart';

class RequestPanel extends StatelessWidget {
  const RequestPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: 'Params'),
              Tab(text: 'Authorization'),
              Tab(text: 'Headers'),
              Tab(text: 'Body'),
            ],
          ),
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: TabBarView(
                children: [
                  _ParamsTab(),
                  _AuthTab(),
                  _HeadersTab(),
                  _BodyTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParamsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final restProvider = context.watch<RestProvider>();
    return _KeyValueTable(
      key: ValueKey('params-${restProvider.request.queryParams.length}-${restProvider.request.url}'),
      title: 'Query Params',
      data: restProvider.request.queryParams,
      onChanged: () => restProvider.updateQueryParams(),
    );
  }
}

class _HeadersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final restProvider = context.watch<RestProvider>();
    return _KeyValueTable(
      key: ValueKey('headers-${restProvider.request.headers.length}-${restProvider.request.url}'),
      title: 'Headers',
      data: restProvider.request.headers,
      onChanged: () => restProvider.refresh(),
    );
  }
}

class _KeyValueTable extends StatelessWidget {
  final String title;
  final List<KeyValue> data;
  final VoidCallback onChanged;

  const _KeyValueTable({super.key, required this.title, required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: data.length + 1,
              itemBuilder: (context, index) {
                if (index == data.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        data.add(KeyValue());
                        onChanged();
                      },
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Add row', style: TextStyle(fontSize: 12)),
                    ),
                  );
                }
                return _KeyValueRow(
                  key: ValueKey(data[index]),
                  kv: data[index],
                  onChanged: onChanged,
                  onRemove: () {
                    data.removeAt(index);
                    onChanged();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatefulWidget {
  final KeyValue kv;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _KeyValueRow({super.key, required this.kv, required this.onChanged, required this.onRemove});

  @override
  State<_KeyValueRow> createState() => _KeyValueRowState();
}

class _KeyValueRowState extends State<_KeyValueRow> {
  late TextEditingController _keyController;
  late TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.kv.key);
    _valueController = TextEditingController(text: widget.kv.value);
  }

  @override
  void didUpdateWidget(_KeyValueRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_keyController.text != widget.kv.key) {
      _keyController.text = widget.kv.key;
    }
    if (_valueController.text != widget.kv.value) {
      _valueController.text = widget.kv.value;
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: widget.kv.enabled,
              onChanged: (val) {
                widget.kv.enabled = val!;
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _keyController,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(hintText: 'Key'),
                onChanged: (val) {
                  widget.kv.key = val;
                  if (val.isNotEmpty && !widget.kv.enabled) {
                    widget.kv.enabled = true;
                  }
                  widget.onChanged();
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _valueController,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(hintText: 'Value'),
                onChanged: (val) {
                  widget.kv.value = val;
                  if (val.isNotEmpty && !widget.kv.enabled) {
                    widget.kv.enabled = true;
                  }
                  widget.onChanged();
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}

class _AuthTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final restProvider = context.watch<RestProvider>();
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Auth Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 4),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).inputDecorationTheme.fillColor,
                border: Border.all(color: Theme.of(context).inputDecorationTheme.enabledBorder!.borderSide.color),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: restProvider.request.authType,
                  isDense: true,
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                  onChanged: (val) {
                    restProvider.request.authType = val!;
                    restProvider.refresh();
                  },
                  items: ['No Auth', 'Basic Auth', 'Bearer Token', 'JWT Token'].map((a) {
                    return DropdownMenuItem(value: a, child: Text(a));
                  }).toList(),
                ),
              ),
            ),
            if (restProvider.request.authType == 'Basic Auth') ...[
              const SizedBox(height: 16),
              const Text('Username', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              _AuthField(
                initialValue: restProvider.request.authData['username'] ?? '',
                hint: 'Username',
                onChanged: (val) {
                  restProvider.request.authData['username'] = val;
                  restProvider.refresh();
                },
              ),
              const SizedBox(height: 12),
              const Text('Password', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              _AuthField(
                initialValue: restProvider.request.authData['password'] ?? '',
                hint: 'Password',
                obscure: true,
                onChanged: (val) {
                  restProvider.request.authData['password'] = val;
                  restProvider.refresh();
                },
              ),
            ],
            if (restProvider.request.authType == 'Bearer Token' || restProvider.request.authType == 'JWT Token') ...[
              const SizedBox(height: 16),
              const Text('Token', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              _AuthField(
                initialValue: restProvider.request.authData['token'] ?? '',
                hint: 'Paste token here...',
                onChanged: (val) {
                  restProvider.request.authData['token'] = val;
                  restProvider.refresh();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AuthField extends StatefulWidget {
  final String initialValue;
  final String hint;
  final bool obscure;
  final ValueChanged<String> onChanged;

  const _AuthField({required this.initialValue, required this.hint, this.obscure = false, required this.onChanged});

  @override
  State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_AuthField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _controller,
        obscureText: widget.obscure,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(hintText: widget.hint),
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _BodyTab extends StatefulWidget {
  @override
  State<_BodyTab> createState() => _BodyTabState();
}

class _BodyTabState extends State<_BodyTab> {
  bool _previewMode = false;
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
    final restProvider = context.watch<RestProvider>();
    final isJson = restProvider.request.rawType == RawType.json;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              ...BodyType.values.map((type) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Radio<BodyType>(
                          value: type,
                          groupValue: restProvider.request.bodyType,
                          onChanged: (val) {
                            restProvider.request.bodyType = val!;
                            restProvider.refresh();
                          },
                        ),
                      ),
                      Text(type.label, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              }),
              const Spacer(),
              if (restProvider.request.bodyType == BodyType.raw && isJson) ...[
                TextButton.icon(
                  onPressed: () {
                    try {
                      final dynamic decoded = jsonDecode(restProvider.request.bodyContent);
                      final pretty = const JsonEncoder.withIndent('    ').convert(decoded);
                      restProvider.request.bodyContent = pretty;
                      restProvider.refresh();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Invalid JSON: $e'), behavior: SnackBarBehavior.floating, width: 300),
                      );
                    }
                  },
                  icon: const Icon(Icons.format_align_left, size: 14),
                  label: const Text('BEAUTIFY', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(() => _previewMode = !_previewMode),
                  icon: Icon(_previewMode ? Icons.edit : Icons.remove_red_eye, size: 14),
                  label: Text(_previewMode ? 'EDIT' : 'PREVIEW', style: const TextStyle(fontSize: 11)),
                ),
              ],
            ],
          ),
        ),
        if (restProvider.request.bodyType == BodyType.raw)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).inputDecorationTheme.fillColor,
                    border: Border.all(color: Theme.of(context).inputDecorationTheme.enabledBorder!.borderSide.color),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<RawType>(
                      value: restProvider.request.rawType,
                      isDense: true,
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                      onChanged: (val) {
                        restProvider.request.rawType = val!;
                        restProvider.refresh();
                      },
                      items: RawType.values.map((t) {
                        return DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()));
                      }).toList(),
                    ),
                  ),
                ),
                if (_previewMode && isJson) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: SearchToolbar(
                      controller: _jsonController,
                      searchController: _searchController,
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (restProvider.request.bodyType != BodyType.none)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _previewMode && isJson
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).inputDecorationTheme.fillColor,
                        border: Border.all(color: Theme.of(context).inputDecorationTheme.enabledBorder!.borderSide.color),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: _FormattedJson(
                        jsonString: restProvider.request.bodyContent,
                        controller: _jsonController,
                      ),
                    )
                  : _BodyEditor(
                      initialValue: restProvider.request.bodyContent,
                      onChanged: (val) => restProvider.request.bodyContent = val,
                    ),
            ),
          ),
      ],
    );
  }
}

class _BodyEditor extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _BodyEditor({required this.initialValue, required this.onChanged});

  @override
  State<_BodyEditor> createState() => _BodyEditorState();
}

class _BodyEditorState extends State<_BodyEditor> {
  late TextEditingController _controller;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _scrollController = ScrollController();
    _scrollController.addListener(_syncScroll);
  }

  void _syncScroll() {
    setState(() {}); // Rebuild gutter to sync scroll offset
  }

  @override
  void didUpdateWidget(_BodyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_syncScroll);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lineCount = _controller.text.split('\n').length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gutterColor = isDark ? const Color(0xFF858585) : const Color(0xFF999999);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gutter
        Container(
          width: 40,
          padding: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).inputDecorationTheme.fillColor,
            border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
          ),
          child: ListView.builder(
            controller: ScrollController(initialScrollOffset: _scrollController.hasClients ? _scrollController.offset : 0),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lineCount,
            itemBuilder: (context, index) => Container(
              height: 13 * 1.4, // Matches font size * height
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${index + 1}',
                style: GoogleFonts.inter(fontSize: 11, color: gutterColor),
              ),
            ),
          ),
        ),
        // Editor
        Expanded(
          child: TextField(
            controller: _controller,
            scrollController: _scrollController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: GoogleFonts.inter(fontSize: 13, height: 1.4),
            decoration: const InputDecoration(
              hintText: 'Enter body content...',
              contentPadding: EdgeInsets.all(12),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            onChanged: (val) {
              widget.onChanged(val);
              setState(() {}); // Update line count
            },
          ),
        ),
      ],
    );
  }
}

class _FormattedJson extends StatelessWidget {
  final String jsonString;
  final JsonViewerController controller;
  const _FormattedJson({required this.jsonString, required this.controller});

  @override
  Widget build(BuildContext context) {
    try {
      final dynamic decoded = jsonDecode(jsonString);
      return JsonViewer(data: decoded, controller: controller);
    } catch (e) {
      return SelectionArea(
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            'Invalid JSON: $e', 
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12, fontFamily: 'monospace')
          ),
        ),
      );
    }
  }
}

class SearchToolbar extends StatelessWidget {
  final JsonViewerController controller;
  final TextEditingController searchController;

  const SearchToolbar({super.key, required this.controller, required this.searchController});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasText = searchController.text.isNotEmpty;
        final count = controller.matchCount;
        final index = controller.currentMatchIndex;

        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: searchController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search, size: 14),
                    suffixIcon: hasText 
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 14),
                          onPressed: () {
                            searchController.clear();
                            controller.updateSearch('');
                          },
                        )
                      : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.light ? Colors.grey[100] : Colors.grey[800],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => controller.updateSearch(val),
                ),
              ),
            ),
            if (hasText && count > 0) ...[
              const SizedBox(width: 8),
              Text(
                '${index + 1} of $count',
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                onPressed: controller.previousMatch,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                onPressed: controller.nextMatch,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ] else if (hasText && count == 0) ...[
              const SizedBox(width: 8),
              Text(
                'No results',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        );
      }
    );
  }
}
