import 'dart:convert';
import 'package:flutter/material.dart';
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

  const _KeyValueTable({required this.title, required this.data, required this.onChanged});

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
                final kv = data[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: kv.enabled,
                          onChanged: (val) {
                            kv.enabled = val!;
                            onChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: TextField(
                            style: const TextStyle(fontSize: 13),
                            textAlignVertical: TextAlignVertical.center,
                            decoration: const InputDecoration(
                              hintText: 'Key', 
                            ),
                            onChanged: (val) {
                              kv.key = val;
                              onChanged();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: TextField(
                            style: const TextStyle(fontSize: 13),
                            textAlignVertical: TextAlignVertical.center,
                            decoration: const InputDecoration(
                              hintText: 'Value', 
                            ),
                            onChanged: (val) {
                              kv.value = val;
                              onChanged();
                            },
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () {
                          data.removeAt(index);
                          onChanged();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Auth Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          Container(
            height: 44, // Matches Send button height
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
            SizedBox(
              height: 44,
              child: TextField(
                style: const TextStyle(fontSize: 13),
                textAlignVertical: TextAlignVertical.center,
                decoration: const InputDecoration(
                  hintText: 'Username',
                ),
                onChanged: (val) {
                  restProvider.request.authData['username'] = val;
                  restProvider.refresh();
                },
              ),
            ),
            const SizedBox(height: 12),
            const Text('Password', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 4),
            SizedBox(
              height: 44,
              child: TextField(
                obscureText: true,
                style: const TextStyle(fontSize: 13),
                textAlignVertical: TextAlignVertical.center,
                decoration: const InputDecoration(
                  hintText: 'Password',
                ),
                onChanged: (val) {
                  restProvider.request.authData['password'] = val;
                  restProvider.refresh();
                },
              ),
            ),
          ],
          if (restProvider.request.authType == 'Bearer Token' || restProvider.request.authType == 'JWT Token') ...[
            const SizedBox(height: 16),
            const Text('Token', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 4),
            SizedBox(
              height: 44,
              child: TextField(
                style: const TextStyle(fontSize: 13),
                textAlignVertical: TextAlignVertical.center,
                decoration: const InputDecoration(
                  hintText: 'Paste token here...',
                ),
                onChanged: (val) {
                  restProvider.request.authData['token'] = val;
                  restProvider.refresh();
                },
              ),
            ),
          ],
        ],
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
                      Text(type.name, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              }),
              const Spacer(),
              if (restProvider.request.bodyType == BodyType.raw && isJson)
                TextButton.icon(
                  onPressed: () => setState(() => _previewMode = !_previewMode),
                  icon: Icon(_previewMode ? Icons.edit : Icons.remove_red_eye, size: 14),
                  label: Text(_previewMode ? 'EDIT' : 'PREVIEW', style: const TextStyle(fontSize: 11)),
                ),
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
                  : TextField(
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace', height: 1.2),
                      decoration: const InputDecoration(
                        hintText: 'Enter body content...',
                        contentPadding: EdgeInsets.all(12),
                      ),
                      onChanged: (val) => restProvider.request.bodyContent = val,
                    ),
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
            style: const TextStyle(color: Colors.red, fontSize: 12, fontFamily: 'monospace')
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
              const Text(
                'No results',
                style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        );
      }
    );
  }
}
