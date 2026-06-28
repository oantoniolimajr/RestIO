import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class JsonViewerController extends ChangeNotifier {
  String _searchText = '';
  int _matchCount = 0;
  int _currentMatchIndex = -1;

  String get searchText => _searchText;
  int get matchCount => _matchCount;
  int get currentMatchIndex => _currentMatchIndex;

  void updateSearch(String text) {
    _searchText = text;
    _currentMatchIndex = -1; 
    notifyListeners();
  }

  void nextMatch() {
    if (_matchCount > 0) {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matchCount;
      notifyListeners();
    }
  }

  void previousMatch() {
    if (_matchCount > 0) {
      _currentMatchIndex = (_currentMatchIndex - 1 + _matchCount) % _matchCount;
      notifyListeners();
    }
  }

  void _updateMatches(int count) {
    if (_matchCount != count) {
      _matchCount = count;
      if (_matchCount > 0 && _currentMatchIndex == -1) {
        _currentMatchIndex = 0;
      } else if (_matchCount == 0) {
        _currentMatchIndex = -1;
      }
      Future.microtask(() => notifyListeners());
    }
  }
}

class JsonViewer extends StatefulWidget {
  final dynamic data;
  final double fontSize;
  final JsonViewerController? controller;
  final bool isRaw;
  final List<Widget>? additionalActions;

  const JsonViewer({
    super.key, 
    required this.data, 
    this.fontSize = 15.0,
    this.controller,
    this.isRaw = false,
    this.additionalActions,
  });

  @override
  State<JsonViewer> createState() => _JsonViewerState();
}

class _JsonViewerState extends State<JsonViewer> {
  final Set<String> _collapsedPaths = {};
  final ScrollController _verticalController = ScrollController();
  final Map<int, GlobalKey> _matchIndexToKey = {};
  bool _isWordWrap = true;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(JsonViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onSearchChanged);
      widget.controller?.addListener(_onSearchChanged);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onSearchChanged);
    _verticalController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
      _scrollToMatch();
    }
  }

  void _scrollToMatch() {
    final index = widget.controller?.currentMatchIndex ?? -1;
    if (index != -1 && _matchIndexToKey.containsKey(index)) {
      final key = _matchIndexToKey[index];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 200),
          alignment: 0.5,
        );
      }
    }
  }

  void _togglePath(String path) {
    setState(() {
      if (_collapsedPaths.contains(path)) {
        _collapsedPaths.remove(path);
      } else {
        _collapsedPaths.add(path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = TextStyle(
      fontSize: widget.fontSize,
      fontFamily: 'monospace',
      height: 1.4,
      color: isDark ? Colors.white70 : Colors.black87,
    );

    final colors = _ViewerColors(
      key: isDark ? const Color(0xFF9CDCFE) : const Color(0xFF0451A5),
      string: isDark ? const Color(0xFFCE9178) : const Color(0xFFA31515),
      number: isDark ? const Color(0xFFB5CEA8) : const Color(0xFF098658),
      boolean: isDark ? const Color(0xFF569CD6) : const Color(0xFF0000FF),
      symbol: isDark ? const Color(0xFFD4D4D4) : const Color(0xFF333333),
      gutter: isDark ? const Color(0xFF858585) : const Color(0xFF999999),
      highlight: Colors.yellow.withOpacity(0.4),
      currentHighlight: Colors.orange.withOpacity(0.7),
    );

    final List<_LineData> lines = [];
    int physicalLine = 1;
    int matchCounter = 0;
    _matchIndexToKey.clear();

    if (widget.isRaw) {
      String rawText = widget.data is String ? widget.data : jsonEncode(widget.data);
      final rawLines = rawText.split('\n');
      for (var content in rawLines) {
        lines.add(_LineData(
          index: physicalLine++,
          spans: _highlightText(content, style, colors, () {
            final idx = matchCounter++;
            final key = GlobalKey();
            _matchIndexToKey[idx] = key;
            return key;
          }),
        ));
      }
    } else {
      _generateJsonLines(widget.data, r'$', 0, true, null, lines, () => physicalLine++, style, colors, () {
        final idx = matchCounter++;
        final key = GlobalKey();
        _matchIndexToKey[idx] = key;
        return key;
      });
    }

    widget.controller?._updateMatches(matchCounter);

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((l) => _buildLineRow(l, colors, constraintsWidth: 0)).toList(),
    );

    if (!_isWordWrap) {
      content = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: content,
      );
    }

    return Stack(
      children: [
        SelectionArea(
          child: SingleChildScrollView(
            controller: _verticalController,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0, right: 80.0), // Space for action buttons
              child: content,
            ),
          ),
        ),
        Positioned(
          top: 0, right: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(_isWordWrap ? Icons.wrap_text : Icons.format_align_left, size: 18),
                tooltip: _isWordWrap ? 'Disable Word Wrap' : 'Enable Word Wrap',
                onPressed: () => setState(() => _isWordWrap = !_isWordWrap),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy',
                onPressed: () {
                  final text = widget.isRaw && widget.data is String 
                      ? widget.data 
                      : const JsonEncoder.withIndent('    ').convert(widget.data);
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard'), width: 200, behavior: SnackBarBehavior.floating));
                },
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
                ),
              ),
              if (widget.additionalActions != null) ...widget.additionalActions!,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLineRow(_LineData line, _ViewerColors colors, {required double constraintsWidth}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          padding: const EdgeInsets.only(right: 8.0),
          alignment: Alignment.topRight,
          child: Text(
            '${line.index}', 
            style: TextStyle(
              fontSize: widget.fontSize * 0.8,
              fontFamily: 'monospace',
              color: colors.gutter,
              height: 1.4,
            ),
          ),
        ),
        Expanded(
          flex: _isWordWrap ? 1 : 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: line.indent * 24.0),
              if (line.isCollapsible)
                GestureDetector(
                  onTap: line.onToggle,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Icon(line.isCollapsed ? Icons.arrow_right : Icons.arrow_drop_down, size: widget.fontSize * 1.2, color: colors.symbol.withOpacity(0.5)),
                  ),
                )
              else
                SizedBox(width: widget.fontSize * 1.2),
              
              Flexible(
                flex: _isWordWrap ? 1 : 0,
                child: RichText(
                  text: TextSpan(children: line.spans),
                  softWrap: _isWordWrap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _generateJsonLines(
    dynamic data, String path, int indent, bool isLast, String? nodeKey,
    List<_LineData> lines, int Function() nextLine, TextStyle style, _ViewerColors colors,
    GlobalKey Function() onMatch
  ) {
    final keySpans = nodeKey != null ? [
      ..._highlightText('"$nodeKey"', style.copyWith(color: colors.key), colors, onMatch),
      TextSpan(text: ': ', style: style.copyWith(color: colors.symbol)),
    ] : <InlineSpan>[];

    if (data is Map || data is List) {
      final isMap = data is Map;
      final len = isMap ? (data as Map).length : (data as List).length;
      final open = isMap ? '{' : '[';
      final close = isMap ? '}' : ']';
      final isCollapsed = _collapsedPaths.contains(path);

      if (len == 0) {
        lines.add(_LineData(
          index: nextLine(), indent: indent,
          spans: [...keySpans, TextSpan(text: '$open$close${isLast ? "" : ","}', style: style.copyWith(color: colors.symbol))],
        ));
        return;
      }

      lines.add(_LineData(
        index: nextLine(), indent: indent, isCollapsible: true, isCollapsed: isCollapsed,
        onToggle: () => _togglePath(path),
        spans: [
          ...keySpans, TextSpan(text: open, style: style.copyWith(color: colors.symbol)),
          if (isCollapsed) ...[
            TextSpan(text: ' ... ', style: style.copyWith(color: colors.symbol.withOpacity(0.5))),
            TextSpan(text: close, style: style.copyWith(color: colors.symbol)),
            if (!isLast) TextSpan(text: ',', style: style.copyWith(color: colors.symbol)),
          ],
        ],
      ));

      if (isCollapsed) {
        _skip(data, nextLine);
      } else {
        if (isMap) {
          final entries = (data as Map).entries.toList();
          for (int i = 0; i < entries.length; i++) {
            _generateJsonLines(entries[i].value, '$path.${entries[i].key}', indent + 1, i == entries.length - 1, entries[i].key.toString(), lines, nextLine, style, colors, onMatch);
          }
        } else {
          final list = data as List;
          for (int i = 0; i < list.length; i++) {
            _generateJsonLines(list[i], '$path[$i]', indent + 1, i == list.length - 1, null, lines, nextLine, style, colors, onMatch);
          }
        }
        lines.add(_LineData(
          index: nextLine(), indent: indent,
          spans: [
            TextSpan(text: close, style: style.copyWith(color: colors.symbol)),
            if (!isLast) TextSpan(text: ',', style: style.copyWith(color: colors.symbol)),
          ],
        ));
      }
    } else {
      lines.add(_LineData(
        index: nextLine(), indent: indent,
        spans: [...keySpans, ..._highlightPrimitive(data, style, colors, onMatch), if (!isLast) TextSpan(text: ',', style: style.copyWith(color: colors.symbol))],
      ));
    }
  }

  void _skip(dynamic d, int Function() nextLine) {
    if (d is Map) {
      for (final v in d.values) { nextLine(); if (v is Map || v is List) _skip(v, nextLine); }
      nextLine();
    } else if (d is List) {
      for (final v in d) { nextLine(); if (v is Map || v is List) _skip(v, nextLine); }
      nextLine();
    }
  }

  List<InlineSpan> _highlightPrimitive(dynamic v, TextStyle style, _ViewerColors colors, GlobalKey Function() onMatch) {
    if (v is String) return _highlightText('"$v"', style.copyWith(color: colors.string), colors, onMatch);
    if (v is num) return _highlightText(v.toString(), style.copyWith(color: colors.number), colors, onMatch);
    if (v is bool || v == null) return _highlightText(v.toString(), style.copyWith(color: colors.boolean), colors, onMatch);
    return _highlightText(v.toString(), style, colors, onMatch);
  }

  List<InlineSpan> _highlightText(String text, TextStyle style, _ViewerColors colors, GlobalKey Function() onMatch) {
    final query = widget.controller?.searchText ?? '';
    if (query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return [TextSpan(text: text, style: style)];
    }

    final spans = <InlineSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;
    int idx;

    while ((idx = lowerText.indexOf(lowerQuery, start)) != -1) {
      if (idx > start) spans.add(TextSpan(text: text.substring(start, idx), style: style));
      
      final matchKey = onMatch();
      final currentIdx = widget.controller!.currentMatchIndex;
      
      int matchCounterValue = -1;
      for (var entry in _matchIndexToKey.entries) {
        if (entry.value == matchKey) {
          matchCounterValue = entry.key;
          break;
        }
      }
      final isCurrent = matchCounterValue == currentIdx;

      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          key: matchKey,
          color: isCurrent ? colors.currentHighlight : colors.highlight,
          child: Text(text.substring(idx, idx + query.length), style: style),
        ),
      ));
      start = idx + query.length;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start), style: style));
    return spans;
  }
}

class _LineData {
  final int index;
  final int indent;
  final List<InlineSpan> spans;
  final bool isCollapsible;
  final bool isCollapsed;
  final VoidCallback? onToggle;
  _LineData({required this.index, this.indent = 0, required this.spans, this.isCollapsible = false, this.isCollapsed = false, this.onToggle});
}

class _ViewerColors {
  final Color key, string, number, boolean, symbol, gutter, highlight, currentHighlight;
  _ViewerColors({required this.key, required this.string, required this.number, required this.boolean, required this.symbol, required this.gutter, required this.highlight, required this.currentHighlight});
}
