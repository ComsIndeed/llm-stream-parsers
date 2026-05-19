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
      for (final event in _parser._textBuffer) {
        if (_matchesDepth(event.depths) && event.text.isNotEmpty) {
          controller.add(event.text);
        }
      }

      if (_parser._isClosed) {
        controller.close();
        return;
      }

      final sub = _parser._textController.stream.listen(
        (event) {
          if (_matchesDepth(event.depths) && event.text.isNotEmpty) {
            controller.add(event.text);
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

    for (final event in _parser._attributeBuffer) {
      if (event.tag == attributeTag && _matchesDepth(event.depths)) {
        return event.attributes;
      }
    }

    if (_parser._isClosed) {
      return const <String, String>{};
    }

    final completer = Completer<Map<String, String>>();
    late StreamSubscription<_AttributeEvent> sub;
    sub = _parser._attributeController.stream.listen(
      (event) {
        if (event.tag == attributeTag && _matchesDepth(event.depths)) {
          completer.complete(event.attributes);
          sub.cancel();
        }
      },
      onError: completer.completeError,
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(const <String, String>{});
        }
      },
    );

    return completer.future;
  }

  Stream<String?> attribute(String name) {
    final attributeTag = _attributeTag;
    if (attributeTag == null) {
      return const Stream<String?>.empty();
    }

    return Stream.multi((controller) {
      for (final event in _parser._attributeBuffer) {
        if (event.tag == attributeTag && _matchesDepth(event.depths)) {
          controller.add(event.attributes[name]);
        }
      }

      if (_parser._isClosed) {
        controller.close();
        return;
      }

      final sub = _parser._attributeController.stream.listen(
        (event) {
          if (event.tag == attributeTag && _matchesDepth(event.depths)) {
            controller.add(event.attributes[name]);
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
  final List<_TextEvent> _textBuffer = [];
  final List<_AttributeEvent> _attributeBuffer = [];
  final StreamController<_TextEvent> _textController = StreamController.broadcast();
  final StreamController<_AttributeEvent> _attributeController = StreamController.broadcast();
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
      onError: _textController.addError,
      onDone: () {
        _processPendingBuffer(isFinal: true);
        _isClosed = true;
        _textController.close();
        _attributeController.close();
      },
    );
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
      final result = _findNextMatch(_pendingBuffer, 0);
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
    final event = _TextEvent(text, Map.unmodifiable({..._depths}));
    _textBuffer.add(event);
    _textController.add(event);
  }

  void _handleOpen(_TagMatch match) {
    final tag = match.tag;
    _depths[tag.openKey] = (_depths[tag.openKey] ?? 0) + 1;
    if (tag.hasAttributes) {
      final attributes = tag.parseAttributes(match.attributeText ?? '');
      final event = _AttributeEvent(
        tag.openKey,
        attributes,
        Map.unmodifiable({..._depths}),
      );
      _attributeBuffer.add(event);
      _attributeController.add(event);
    }
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
  }

  _TagMatch? _findNextMatch(String buffer, int startIndex) {
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
          final suffixIndex = buffer.indexOf(tag.openSuffix, openIndex + tag.openPrefix.length);
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
    final trimmed = rawAttributes.trim();
    if (trimmed.isEmpty) {
      return const <String, String>{};
    }

    if (format == AttributeFormat.keyOnly) {
      return {'value': trimmed};
    }

    final attributes = <String, String>{};
    final doubleQuote = RegExp(r'(\w+)\s*=\s*"([^"]*)"');
  final singleQuote = RegExp(r"(\w+)\s*=\s*'([^']*)'");
    for (final match in doubleQuote.allMatches(trimmed)) {
      attributes[match.group(1)!] = match.group(2) ?? '';
    }
    for (final match in singleQuote.allMatches(trimmed)) {
      attributes[match.group(1)!] = match.group(2) ?? '';
    }
    return attributes;
  }
}

class _TextEvent {
  final String text;
  final Map<String, int> depths;

  _TextEvent(this.text, this.depths);
}

class _AttributeEvent {
  final String tag;
  final Map<String, String> attributes;
  final Map<String, int> depths;

  _AttributeEvent(this.tag, this.attributes, this.depths);
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
