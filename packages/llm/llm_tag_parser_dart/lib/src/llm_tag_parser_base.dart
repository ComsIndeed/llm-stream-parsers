import 'dart:async';

enum AttributeFormat {
  xml,
  keyOnly,
}

class LlmTag {
  final String open;
  final String close;
  final String? attributePlaceholder;
  final AttributeFormat? attributeFormat;

  LlmTag({
    required this.open,
    required this.close,
    this.attributePlaceholder,
    this.attributeFormat,
  });

  LlmTag withAttributes(String placeholder, {required AttributeFormat format}) {
    return LlmTag(
      open: open,
      close: close,
      attributePlaceholder: placeholder,
      attributeFormat: format,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// V2 NODE TYPES
// ─────────────────────────────────────────────────────────────────────────────

abstract class LlmNode {
  final Map<String, int> depths;
  const LlmNode({required this.depths});
}

class TextNode extends LlmNode {
  final String text;
  const TextNode(this.text, {required super.depths});

  @override
  String toString() => 'TextNode("$text", depths: $depths)';
}

class _ActiveTagInstance {
  final String openKey;
  final StreamController<String> controller = StreamController.broadcast();
  final List<String> chunks = [];
  final Completer<String> completer = Completer<String>();
  bool isClosed = false;

  _ActiveTagInstance({required this.openKey});

  void add(String chunk) {
    if (isClosed) return;
    chunks.add(chunk);
    controller.add(chunk);
  }

  void close() {
    if (isClosed) return;
    isClosed = true;
    controller.close();
    completer.complete(chunks.join(''));
  }
}

class TagNode extends LlmNode {
  final String tag;
  final Map<String, String> attributes;
  final _ActiveTagInstance _activeInstance;

  TagNode({
    required this.tag,
    required this.attributes,
    required _ActiveTagInstance activeInstance,
    required super.depths,
  })  : _activeInstance = activeInstance;

  Stream<String> get stream {
    return Stream.multi((controller) {
      for (final chunk in _activeInstance.chunks) {
        controller.add(chunk);
      }
      if (_activeInstance.isClosed) {
        controller.close();
        return;
      }
      final sub = _activeInstance.controller.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  Future<String> get future => _activeInstance.completer.future;

  Future<String?> getAttributeFuture(String name) async => attributes[name];
  Stream<String?> getAttributeStream(String name) => Stream.value(attributes[name]);

  String? get tagName => XmlTagUtilities.getTagName(tag);

  @override
  String toString() => 'TagNode($tag, attributes: $attributes, depths: $depths)';
}

// ─────────────────────────────────────────────────────────────────────────────
// TAG CONTENT & PARSER
// ─────────────────────────────────────────────────────────────────────────────

class LlmTagContent {
  final LlmTagParser _parser;
  final Map<String, bool> _filters;
  final String? _attributeTag;

  LlmTagContent(
    this._parser, {
    Map<String, bool>? filters,
    String? attributeTag,
  })  : _filters = Map.unmodifiable(filters ?? const {}),
        _attributeTag = attributeTag;

  Stream<String> get stream {
    return Stream.multi((controller) {
      final sub = _parser.nodes.listen(
        (node) {
          if (node is TextNode && _matchesDepth(node.depths)) {
            if (node.text.isNotEmpty) {
              controller.add(node.text);
            }
          }
        },
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  Future<String> get future async {
    final buffer = StringBuffer();
    await for (final chunk in stream) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  Future<Map<String, String>> get attributes async {
    final attributeTag = _attributeTag;
    if (attributeTag == null) {
      return const <String, String>{};
    }

    await for (final node in _parser.nodes) {
      if (node is TagNode && node.tag == attributeTag && _matchesDepth(node.depths)) {
        return node.attributes;
      }
    }
    return const <String, String>{};
  }

  Stream<String?> attribute(String name) {
    final attributeTag = _attributeTag;
    if (attributeTag == null) {
      return const Stream<String?>.empty();
    }

    return Stream.multi((controller) {
      final sub = _parser.nodes.listen(
        (node) {
          if (node is TagNode && node.tag == attributeTag && _matchesDepth(node.depths)) {
            controller.add(node.attributes[name]);
          }
        },
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  Stream<String?> getAttributeStream(String name) {
    return attribute(name);
  }

  Future<String?> getAttributeFuture(String name) async {
    final attrs = await attributes;
    return attrs[name];
  }

  Stream<TagNode> get instances {
    final attributeTag = _attributeTag;
    if (attributeTag == null) {
      return const Stream<TagNode>.empty();
    }

    return Stream.multi((controller) {
      final sub = _parser.nodes.listen(
        (node) {
          if (node is TagNode && node.tag == attributeTag && _matchesDepth(node.depths)) {
            controller.add(node);
          }
        },
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  LlmTagContent within(String tag) {
    return LlmTagContent(
      _parser,
      filters: {..._filters, tag: true},
      attributeTag: tag,
    );
  }

  LlmTagContent outside(String tag) {
    return LlmTagContent(
      _parser,
      filters: {..._filters, tag: false},
      attributeTag: _attributeTag,
    );
  }

  bool _matchesDepth(Map<String, int> depths) {
    for (final entry in _filters.entries) {
      final depth = depths[entry.key] ?? 0;
      if (entry.value) {
        if (depth <= 0) {
          return false;
        }
      } else if (depth > 0) {
        return false;
      }
    }
    return true;
  }
}

class LlmTagParser {
  final Map<String, _TagDefinition> _tagDefinitions;
  final Map<String, int> _depths = {};
  final List<LlmNode> _nodeHistory = [];
  final StreamController<LlmNode> _nodesController = StreamController.broadcast();
  final List<_ActiveTagInstance> _activeInstances = [];
  final int _maxDelimiterLength;
  late final Set<String> _delimiters;
  bool _isClosed = false;

  LlmTagParser({
    required Stream<String> stream,
    required List<LlmTag> tags,
  })  : _tagDefinitions = {
          for (final tag in tags) tag.open: _TagDefinition.fromTag(tag),
        },
        _maxDelimiterLength = _computeMaxDelimiterLength(tags) {
    _delimiters = _computeDelimiters();
    for (final tag in _tagDefinitions.values) {
      _depths[tag.openKey] = 0;
    }

    stream.listen(
      _handleChunk,
      onError: (err, stack) {
        _nodesController.addError(err, stack);
      },
      onDone: () {
        _processPendingBuffer(isFinal: true);
        _closeAllActiveInstances();
        _isClosed = true;
        _nodesController.close();
      },
    );
  }

  void _closeAllActiveInstances() {
    for (final instance in _activeInstances) {
      instance.close();
    }
    _activeInstances.clear();
  }

  Stream<LlmNode> get nodes {
    return Stream.multi((controller) {
      for (final node in _nodeHistory) {
        controller.add(node);
      }
      if (_isClosed) {
        controller.close();
        return;
      }
      final sub = _nodesController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  Set<String> _computeDelimiters() {
    final Set<String> delimiters = {};
    for (final tag in _tagDefinitions.values) {
      delimiters.add(tag.close);
      delimiters.add(tag.openPrefix);
    }
    return delimiters;
  }

  int _computeDynamicKeepLength(String buffer) {
    if (buffer.isEmpty) return 0;
    
    final maxLen = buffer.length < _maxDelimiterLength ? buffer.length : _maxDelimiterLength;
    
    for (var len = maxLen; len >= 1; len--) {
      final suffix = buffer.substring(buffer.length - len);
      final isPrefixOfAny = _delimiters.any((del) => del.startsWith(suffix));
      if (isPrefixOfAny) {
        return len;
      }
    }
    
    return 0;
  }

  LlmTagContent within(String tag) => LlmTagContent(this).within(tag);
  LlmTagContent outside(String tag) => LlmTagContent(this).outside(tag);

  void _handleChunk(String chunk) {
    _pendingBuffer += chunk;
    _processPendingBuffer(isFinal: false);
  }

  void _processPendingBuffer({required bool isFinal}) {
    while (_pendingBuffer.isNotEmpty) {
      final result = _findNextMatch(_pendingBuffer, 0, isFinal);
      if (result == null) {
        if (isFinal) {
          _emitText(_pendingBuffer);
          _pendingBuffer = '';
          return;
        }

        final keepLength = _computeDynamicKeepLength(_pendingBuffer);
        if (keepLength == _pendingBuffer.length) {
          return;
        }
        final emitUntil = _pendingBuffer.length - keepLength;
        _emitText(_pendingBuffer.substring(0, emitUntil));
        _pendingBuffer = _pendingBuffer.substring(emitUntil);
        return;
      }

      if (result.start > 0) {
        _emitText(_pendingBuffer.substring(0, result.start));
      }

      if (result.isIncompleteOpen) {
        if (isFinal) {
          _emitText(_pendingBuffer.substring(result.start));
          _pendingBuffer = '';
        } else {
          _pendingBuffer = _pendingBuffer.substring(result.start);
        }
        return;
      }

      if (result.isOpen) {
        _handleOpen(result);
      } else {
        _handleClose(result);
      }

      _pendingBuffer = _pendingBuffer.substring(result.end);
    }
  }

  String _pendingBuffer = '';

  void _emitText(String text) {
    if (text.isEmpty) {
      return;
    }
    final node = TextNode(text, depths: Map.unmodifiable({..._depths}));
    _nodeHistory.add(node);
    _nodesController.add(node);

    for (final active in _activeInstances) {
      active.add(text);
    }
  }

  void _handleOpen(_TagMatch match) {
    final tag = match.tag;
    _depths[tag.openKey] = (_depths[tag.openKey] ?? 0) + 1;

    final attributes = tag.hasAttributes
        ? tag.parseAttributes(match.attributeText ?? '')
        : const <String, String>{};

    final activeInstance = _ActiveTagInstance(openKey: tag.openKey);

    if (match.isSelfClosing) {
      activeInstance.close();
    } else {
      _activeInstances.add(activeInstance);
    }

    final node = TagNode(
      tag: tag.openKey,
      attributes: Map.unmodifiable(attributes),
      activeInstance: activeInstance,
      depths: Map.unmodifiable({..._depths}),
    );
    _nodeHistory.add(node);
    _nodesController.add(node);

    if (match.isSelfClosing) {
      final current = _depths[tag.openKey] ?? 0;
      if (current > 0) {
        _depths[tag.openKey] = current - 1;
      }
    }
  }

  void _handleClose(_TagMatch match) {
    final tag = match.tag;
    final current = _depths[tag.openKey] ?? 0;
    if (current > 0) {
      _depths[tag.openKey] = current - 1;
    }

    for (var i = _activeInstances.length - 1; i >= 0; i--) {
      if (_activeInstances[i].openKey == tag.openKey) {
        _activeInstances[i].close();
        _activeInstances.removeAt(i);
        break;
      }
    }
  }

  _TagMatch? _findNextMatch(String buffer, int startIndex, bool isFinal) {
    _TagMatch? earliest;

    for (final tag in _tagDefinitions.values) {
      final closeIndex = buffer.indexOf(tag.close, startIndex);
      if (closeIndex != -1) {
        earliest = _pickEarlier(
          earliest,
          _TagMatch.close(tag, closeIndex, closeIndex + tag.close.length),
        );
      }

      if (tag.hasAttributes) {
        final openIndex = buffer.indexOf(tag.openPrefix, startIndex);
        if (openIndex != -1) {
          final suffixIndex = _findSuffixIndex(buffer, tag.openSuffix, openIndex + tag.openPrefix.length, isFinal);
          if (suffixIndex == -1) {
            earliest = _pickEarlier(
              earliest,
              _TagMatch.incompleteOpen(tag, openIndex),
            );
          } else {
            final endIndex = suffixIndex + tag.openSuffix.length;
            earliest = _pickEarlier(
              earliest,
              _TagMatch.open(
                tag,
                openIndex,
                endIndex,
                buffer.substring(openIndex + tag.openPrefix.length, suffixIndex),
              ),
            );
          }
        }
      } else {
        final openIndex = buffer.indexOf(tag.open, startIndex);
        if (openIndex != -1) {
          earliest = _pickEarlier(
            earliest,
            _TagMatch.open(tag, openIndex, openIndex + tag.open.length, null),
          );
        }
      }
    }

    return earliest;
  }

  _TagMatch? _pickEarlier(_TagMatch? current, _TagMatch candidate) {
    if (current == null) {
      return candidate;
    }
    if (candidate.start < current.start) {
      return candidate;
    }
    if (candidate.start == current.start) {
      if (candidate.isIncompleteOpen && !current.isIncompleteOpen) {
        return candidate;
      }
      if (candidate.isOpen && current.isOpen) {
        final candidateLength = candidate.end - candidate.start;
        final currentLength = current.end - current.start;
        if (candidateLength > currentLength) {
          return candidate;
        }
      }
      if (candidate.isOpen && !current.isOpen) {
        return candidate;
      }
    }
    return current;
  }
}

int _computeMaxDelimiterLength(List<LlmTag> tags) {
  var maxLength = 0;
  for (final tag in tags) {
    maxLength = [
      maxLength,
      tag.open.length,
      tag.close.length,
      tag.attributePlaceholder != null
          ? tag.open.split(tag.attributePlaceholder!).first.trimRight().length
          : 0,
    ].reduce((a, b) => a > b ? a : b);
  }
  return maxLength;
}

class _TagDefinition {
  final String openKey;
  final String close;
  final String open;
  final String openPrefix;
  final String openSuffix;
  final String? placeholder;
  final AttributeFormat? attributeFormat;

  _TagDefinition({
    required this.openKey,
    required this.open,
    required this.close,
    required this.openPrefix,
    required this.openSuffix,
    this.placeholder,
    this.attributeFormat,
  });

  factory _TagDefinition.fromTag(LlmTag tag) {
    final placeholder = tag.attributePlaceholder ?? (tag.open.contains('{attrs}') ? '{attrs}' : null);
    if (placeholder != null) {
      final parts = tag.open.split(placeholder);
      final prefix = parts.first.trimRight();
      final suffix = parts.length > 1 ? parts.last.trimLeft() : '';
      return _TagDefinition(
        openKey: tag.open,
        open: tag.open,
        close: tag.close,
        openPrefix: prefix,
        openSuffix: suffix,
        placeholder: placeholder,
        attributeFormat: tag.attributeFormat ?? AttributeFormat.xml,
      );
    }

    return _TagDefinition(
      openKey: tag.open,
      open: tag.open,
      close: tag.close,
      openPrefix: tag.open,
      openSuffix: '',
    );
  }

  bool get hasAttributes => placeholder != null;

  Map<String, String> parseAttributes(String rawAttributes) {
    if (!hasAttributes) {
      return const <String, String>{};
    }

    final format = attributeFormat ?? AttributeFormat.xml;
    var trimmed = rawAttributes.trim();
    if (trimmed.isEmpty) {
      return const <String, String>{};
    }

    if (placeholder != null && trimmed.startsWith(placeholder!)) {
      trimmed = trimmed.substring(placeholder!.length).trim();
    }

    if (format == AttributeFormat.keyOnly) {
      if (trimmed.endsWith('/')) {
        trimmed = trimmed.substring(0, trimmed.length - 1).trim();
      }
      return {'value': trimmed};
    }

    final attributes = <String, String>{};
    final len = trimmed.length;
    var i = 0;

    void skipWhitespace() {
      while (i < len && (trimmed[i] == ' ' || trimmed[i] == '\t' || trimmed[i] == '\n' || trimmed[i] == '\r')) {
        i++;
      }
    }

    while (i < len) {
      skipWhitespace();
      if (i >= len) break;

      if (trimmed[i] == '/') {
        i++;
        continue;
      }

      final keyStart = i;
      while (i < len &&
             trimmed[i] != '=' &&
             trimmed[i] != '/' &&
             trimmed[i] != ' ' &&
             trimmed[i] != '\t' &&
             trimmed[i] != '\n' &&
             trimmed[i] != '\r') {
        i++;
      }
      final key = trimmed.substring(keyStart, i).trim();
      if (key.isEmpty) {
        if (i < len) i++;
        continue;
      }

      skipWhitespace();

      if (i < len && trimmed[i] == '=') {
        i++;
        skipWhitespace();

        if (i >= len) {
          attributes[key] = '';
          break;
        }

        final char = trimmed[i];
        if (char == '"' || char == "'") {
          final quoteChar = char;
          i++;
          final valBuffer = StringBuffer();
          while (i < len) {
            if (trimmed[i] == '\\' && i + 1 < len) {
              valBuffer.write(trimmed[i + 1]);
              i += 2;
            } else if (trimmed[i] == quoteChar) {
              i++;
              break;
            } else {
              valBuffer.write(trimmed[i]);
              i++;
            }
          }
          attributes[key] = valBuffer.toString();
        } else {
          final valStart = i;
          while (i < len &&
                 trimmed[i] != '/' &&
                 trimmed[i] != ' ' &&
                 trimmed[i] != '\t' &&
                 trimmed[i] != '\n' &&
                 trimmed[i] != '\r') {
            i++;
          }
          attributes[key] = trimmed.substring(valStart, i);
        }
      } else {
        attributes[key] = 'true';
      }
    }

    return attributes;
  }
}

class _TagMatch {
  final _TagDefinition tag;
  final int start;
  final int end;
  final bool isOpen;
  final bool isIncompleteOpen;
  final String? attributeText;
  final bool isSelfClosing;

  _TagMatch._(
    this.tag,
    this.start,
    this.end,
    this.isOpen,
    this.isIncompleteOpen,
    this.attributeText,
    this.isSelfClosing,
  );

  factory _TagMatch.open(
    _TagDefinition tag,
    int start,
    int end,
    String? attributeText,
  ) {
    final selfClosing = attributeText != null && attributeText.trimRight().endsWith('/');
    return _TagMatch._(tag, start, end, true, false, attributeText, selfClosing);
  }

  factory _TagMatch.close(_TagDefinition tag, int start, int end) {
    return _TagMatch._(tag, start, end, false, false, null, false);
  }

  factory _TagMatch.incompleteOpen(_TagDefinition tag, int start) {
    return _TagMatch._(tag, start, start, true, true, null, false);
  }
}

int _findSuffixIndex(String buffer, String suffix, int startSearchFrom, bool isFinal) {
  final len = buffer.length;
  var i = startSearchFrom;

  while (i < len) {
    final char = buffer[i];
    if (char == '\\' && i + 1 < len) {
      i += 2;
      continue;
    }

    if (char == '"' || char == "'") {
      final quoteChar = char;
      var closedQuoteFound = false;
      var k = i + 1;
      while (k < len) {
        final c = buffer[k];
        if (c == '\\' && k + 1 < len) {
          k += 2;
          continue;
        }
        if (c == quoteChar) {
          closedQuoteFound = true;
          break;
        }
        k++;
      }

      if (closedQuoteFound) {
        i = k + 1;
        continue;
      } else {
        if (!isFinal) {
          return -1;
        }
      }
    }

    if (buffer.startsWith(suffix, i)) {
      return i;
    }
    i++;
  }
  return -1;
}

class XmlTagUtilities {
  static String? getTagName(String openKey) {
    var name = openKey.trim();
    if (!name.startsWith('<') || !name.endsWith('>')) {
      return null;
    }
    name = name.substring(1, name.length - 1).trim();
    
    var endIdx = name.length;
    for (var i = 0; i < name.length; i++) {
      final c = name[i];
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '|' || c == '{' || c == '/') {
        endIdx = i;
        break;
      }
    }
    name = name.substring(0, endIdx).trim();
    return name.isEmpty ? null : name;
  }
}
