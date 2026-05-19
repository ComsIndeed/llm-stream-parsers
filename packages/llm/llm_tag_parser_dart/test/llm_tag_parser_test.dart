import 'dart:async';
import 'package:test/test.dart';
import 'package:llm_tag_parser/llm_tag_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Splits [text] into chunks of [chunkSize] characters and emits them
/// on a stream with [delay] between each chunk.
Stream<String> streamTextInChunks(
  String text, {
  int chunkSize = 5,
  Duration delay = const Duration(milliseconds: 10),
}) async* {
  for (var i = 0; i < text.length; i += chunkSize) {
    final end = (i + chunkSize).clamp(0, text.length);
    yield text.substring(i, end);
    await Future.delayed(delay);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXT SAMPLES
// ─────────────────────────────────────────────────────────────────────────────

const sampleSimple = '''
<thinking>
The user is doing a simple greeting.
</thinking>
Hi, what can I do for you?
''';

const sampleOutsideOnly = '''
Hello, this is plain text with no tags at all.
''';

const sampleInsideOnly = '''
<thinking>Only inside content, nothing after.</thinking>''';

const sampleDeepNesting = '''
<thinking>
  <tool_use>
    <step_1>
      Step 1 content here.
    </step_1>
    Some tool_use content outside step_1.
  </tool_use>
  Some thinking content outside tool_use.
</thinking>
After thinking.
''';

const sampleAttributes = '''
Here is your UI:

<interface id="main-window" type="panel">
{"namespace": "core:text", "value": "Hello World"}
</interface>

Let me know if there is anything else I can help you with.
''';

const sampleMultipleOccurrences = '''
<thinking>First thought.</thinking>
Some text.
<thinking>Second thought.</thinking>
More text.
<thinking>Third thought.</thinking>
''';

const sampleBracketStyle = '''
[thinking]
Bracket-style thinking block.
[/thinking]
Response text here.
''';

const sampleCustomDelimiter = r'''
$think$
Custom delimiter thinking.
$end$
Response after custom.
''';

const sampleUnregisteredTag = '''
<thinking>Registered content.</thinking>
<artifact>This tag is not registered.</artifact>
Normal text outside.
''';

const sampleUnclosedTag = '''
<thinking>
This tag is never closed.
The stream just ends here.
''';

const sampleAdjacentTags = '''
<thinking>First block.</thinking><thinking>Second block immediately after.</thinking>
''';

const sampleTextBetweenTags = '''
Before first.
<thinking>Inside first.</thinking>
Between first and second.
<thinking>Inside second.</thinking>
After second.
''';

const sampleEmptyTag = '''
<thinking></thinking>
Text after empty tag.
''';

const sampleTagAtStreamStart = '<thinking>Starts immediately.</thinking> Then text.';

const sampleTagAtStreamEnd = 'Text first. <thinking>Tag at the very end.</thinking>';

const sampleChunkSplitsTag = '''<thinking>Split across chunks.</thinking>Normal.''';

const sampleNestedOutside = '''
<thinking>
  <tool_use>Tool use inside thinking.</tool_use>
  Thinking outside tool_use.
</thinking>
<tool_use>Tool use outside thinking.</tool_use>
Final text.
''';

const sampleAttributesCustomPlaceholder = '''
<interface|||id="side-panel">
{"namespace": "core:column"}
</interface>
Conversational text.
''';

const sampleMultipleAttributes = '''
<interface id="main-window" type="panel" version="2">
Content here.
</interface>
''';

const sampleWhitespaceAroundPlaceholder = '''
<interface id="padded">
Content.
</interface>
''';

const sampleFalseAlarm = 'This is a <thinking false alarm because it has no closing bracket.';

const sampleSelfClosingTag = 'Before <interface id="loader" /> After';

const sampleMalformedAttributes = 'Before <interface id="main type=panel>Content</interface> After';

const sampleInterleavedTags = '<thinking><tool_use>Interleaved</thinking></tool_use>';

const samplePrefixOverlap = '<thinking>Hello</thinking>';

// ─────────────────────────────────────────────────────────────────────────────
// UTILITY: collect full stream into string
// ─────────────────────────────────────────────────────────────────────────────

Future<String> collectStream(Stream<String> stream) async {
  final buffer = StringBuffer();
  await for (final chunk in stream) {
    buffer.write(chunk);
  }
  return buffer.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// TESTS
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ───────────────────────────────────────────
  // GROUP: Basic within / outside
  // ───────────────────────────────────────────
  group('Basic within() and outside()', () {
    test('within() receives content inside tag', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleSimple),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final content = await collectStream(parser.within('<thinking>').stream);
      expect(content.trim(), contains('The user is doing a simple greeting.'));
    });

    test('outside() receives content outside tag', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleSimple),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final content = await collectStream(parser.outside('<thinking>').stream);
      expect(content.trim(), contains('Hi, what can I do for you?'));
    });

    test('outside() does not contain tag content', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleSimple),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final content = await collectStream(parser.outside('<thinking>').stream);
      expect(content, isNot(contains('simple greeting')));
    });

    test('within() does not contain outside content', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleSimple),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final content = await collectStream(parser.within('<thinking>').stream);
      expect(content, isNot(contains('Hi, what can I do for you?')));
    });

    test('outside() with no tags in stream returns full text', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleOutsideOnly),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final content = await collectStream(parser.outside('<thinking>').stream);
      expect(content.trim(), equals('Hello, this is plain text with no tags at all.'));
    });

    test('within() with no tags in stream emits nothing', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleOutsideOnly),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final content = await collectStream(parser.within('<thinking>').stream);
      expect(content, isEmpty);
    });

    test('within() with no outside content returns tag content only', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleInsideOnly),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final content = await collectStream(parser.within('<thinking>').stream);
      expect(content.trim(), equals('Only inside content, nothing after.'));
    });
  });

  // ───────────────────────────────────────────
  // GROUP: .future
  // ───────────────────────────────────────────
  group('.future', () {
    test('future resolves to full content of tag block', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleSimple),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final full = await parser.within('<thinking>').future;
      expect(full.trim(), contains('The user is doing a simple greeting.'));
    });

    test('future resolves after stream completes', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleSimple, chunkSize: 1),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final full = await parser.within('<thinking>').future;
      expect(full, isNotEmpty);
    });

    test('future on outside() resolves to full outside content', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleSimple),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final full = await parser.outside('<thinking>').future;
      expect(full.trim(), contains('Hi, what can I do for you?'));
    });
  });

  // ───────────────────────────────────────────
  // GROUP: Deep nesting
  // ───────────────────────────────────────────
  group('Deep nesting', () {
    late LlmTagParser parser;

    setUp(() {
      parser = LlmTagParser(
        stream: streamTextInChunks(sampleDeepNesting),
        tags: [
          LlmTag(open: '<thinking>', close: '</thinking>'),
          LlmTag(open: '<tool_use>', close: '</tool_use>'),
          LlmTag(open: '<step_1>', close: '</step_1>'),
        ],
      );
    });

    test('within(thinking) includes all thinking content', () async {
      final content = await collectStream(parser.within('<thinking>').stream);
      expect(content, contains('tool_use'));
      expect(content, contains('Step 1 content here.'));
      expect(content, contains('Some thinking content outside tool_use.'));
    });

    test('within(thinking).within(tool_use) gets nested content', () async {
      final content = await collectStream(
        parser.within('<thinking>').within('<tool_use>').stream,
      );
      expect(content, contains('Step 1 content here.'));
      expect(content, contains('Some tool_use content outside step_1.'));
    });

    test('within(thinking).within(tool_use) excludes outside thinking', () async {
      final content = await collectStream(
        parser.within('<thinking>').within('<tool_use>').stream,
      );
      expect(content, isNot(contains('Some thinking content outside tool_use.')));
    });

    test('within(thinking).within(tool_use).within(step_1) gets deepest content', () async {
      final content = await collectStream(
        parser.within('<thinking>').within('<tool_use>').within('<step_1>').stream,
      );
      expect(content.trim(), contains('Step 1 content here.'));
    });

    test('outside(thinking) gets only post-thinking text', () async {
      final content = await collectStream(parser.outside('<thinking>').stream);
      expect(content.trim(), contains('After thinking.'));
      expect(content, isNot(contains('Step 1 content here.')));
    });

    test('outside(thinking).within(tool_use) is empty for this sample', () async {
      final content = await collectStream(
        parser.outside('<thinking>').within('<tool_use>').stream,
      );
      // All tool_use in the sample is inside thinking
      expect(content, isEmpty);
    });
  });

  // ───────────────────────────────────────────
  // GROUP: Nested outside + within composition
  // ───────────────────────────────────────────
  group('outside() + within() composition (sibling filtering)', () {
    test('outside(thinking).within(tool_use) captures tool_use outside thinking', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleNestedOutside),
        tags: [
          LlmTag(open: '<thinking>', close: '</thinking>'),
          LlmTag(open: '<tool_use>', close: '</tool_use>'),
        ],
      );

      final content = await collectStream(
        parser.outside('<thinking>').within('<tool_use>').stream,
      );
      expect(content.trim(), contains('Tool use outside thinking.'));
      expect(content, isNot(contains('Tool use inside thinking.')));
    });
  });

  // ───────────────────────────────────────────
  // GROUP: Attributes
  // ───────────────────────────────────────────
  group('Attributes', () {
    test('attributes returns parsed key-value map', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleAttributes),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final attrs = await parser.within('<interface {attrs}>').attributes;
      expect(attrs['id'], equals('main-window'));
      expect(attrs['type'], equals('panel'));
    });

    test('attribute(name) stream emits correct value', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleAttributes),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final id = await parser.within('<interface {attrs}>').attribute('id').first;
      expect(id, equals('main-window'));
    });

    test('within() content stream unaffected by attribute parsing', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleAttributes),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final content = await collectStream(parser.within('<interface {attrs}>').stream);
      expect(content, contains('"namespace": "core:text"'));
    });

    test('outside() excludes interface block', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleAttributes),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final content = await collectStream(parser.outside('<interface {attrs}>').stream);
      expect(content, contains('Here is your UI:'));
      expect(content, contains('Let me know if there is anything else'));
      expect(content, isNot(contains('"namespace"')));
    });

    test('multiple attributes parsed correctly', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleMultipleAttributes),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final attrs = await parser.within('<interface {attrs}>').attributes;
      expect(attrs['id'], equals('main-window'));
      expect(attrs['type'], equals('panel'));
      expect(attrs['version'], equals('2'));
    });

    test('whitespace around placeholder is trimmed correctly', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleWhitespaceAroundPlaceholder),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final attrs = await parser.within('<interface {attrs}>').attributes;
      expect(attrs['id'], equals('padded'));
    });

    test('custom placeholder override works', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleAttributesCustomPlaceholder),
        tags: [
          LlmTag(open: '<interface|||>', close: '</interface>')
            .withAttributes('|||', format: AttributeFormat.xml),
        ],
      );

      final attrs = await parser.within('<interface|||>').attributes;
      expect(attrs['id'], equals('side-panel'));
    });

    test('missing optional attribute returns null from attribute()', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleAttributes),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final val = await parser.within('<interface {attrs}>').attribute('nonexistent').first;
      expect(val, isNull);
    });
  });

  // ───────────────────────────────────────────
  // GROUP: Non-XML tag formats
  // ───────────────────────────────────────────
  group('Non-XML tag formats', () {
    test('bracket-style tags parsed correctly', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleBracketStyle),
        tags: [LlmTag(open: '[thinking]', close: '[/thinking]')],
      );

      final inside = await collectStream(parser.within('[thinking]').stream);
      final outside = await collectStream(parser.outside('[thinking]').stream);

      expect(inside.trim(), contains('Bracket-style thinking block.'));
      expect(outside.trim(), contains('Response text here.'));
    });

    test('custom delimiter style parsed correctly', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleCustomDelimiter),
        tags: [LlmTag(open: r'$think$', close: r'$end$')],
      );

      final inside = await collectStream(parser.within(r'$think$').stream);
      final outside = await collectStream(parser.outside(r'$think$').stream);

      expect(inside.trim(), contains('Custom delimiter thinking.'));
      expect(outside.trim(), contains('Response after custom.'));
    });
  });

  // ───────────────────────────────────────────
  // GROUP: Unregistered tags
  // ───────────────────────────────────────────
  group('Unregistered tags', () {
    test('unregistered tag content passes through to outside()', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleUnregisteredTag),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final outside = await collectStream(parser.outside('<thinking>').stream);
      // The <artifact> block and its content should be in outside
      expect(outside, contains('This tag is not registered.'));
    });

    test('unregistered tag delimiters appear in outside() as plain text', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleUnregisteredTag),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final outside = await collectStream(parser.outside('<thinking>').stream);
      expect(outside, contains('<artifact>'));
      expect(outside, contains('</artifact>'));
    });

    test('registered within() not polluted by unregistered tags', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleUnregisteredTag),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final inside = await collectStream(parser.within('<thinking>').stream);
      expect(inside, isNot(contains('artifact')));
    });
  });

  // ───────────────────────────────────────────
  // GROUP: Edge cases — stream boundaries
  // ───────────────────────────────────────────
  group('Edge cases — stream boundaries', () {
    test('tag split across chunk boundaries is parsed correctly', () async {
      // Force chunk size of 1 so every delimiter is split
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleChunkSplitsTag, chunkSize: 1),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final inside = await collectStream(parser.within('<thinking>').stream);
      final outside = await collectStream(parser.outside('<thinking>').stream);

      expect(inside.trim(), equals('Split across chunks.'));
      expect(outside.trim(), equals('Normal.'));
    });

    test('tag at very start of stream is detected', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleTagAtStreamStart),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final inside = await collectStream(parser.within('<thinking>').stream);
      expect(inside.trim(), equals('Starts immediately.'));
    });

    test('tag at very end of stream is detected', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleTagAtStreamEnd),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final inside = await collectStream(parser.within('<thinking>').stream);
      expect(inside.trim(), equals('Tag at the very end.'));
    });

    test('empty tag block emits empty string from within()', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleEmptyTag),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final inside = await collectStream(parser.within('<thinking>').stream);
      expect(inside.trim(), isEmpty);
    });

    test('outside() after empty tag receives following text', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleEmptyTag),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final outside = await collectStream(parser.outside('<thinking>').stream);
      expect(outside.trim(), contains('Text after empty tag.'));
    });
  });

  // ───────────────────────────────────────────
  // GROUP: Edge cases — unclosed tags
  // ───────────────────────────────────────────
  group('Edge cases — unclosed tags', () {
    test('unclosed tag: within() stream closes when source stream ends', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleUnclosedTag),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      // Should complete (not hang) when the source stream ends
      final inside = await collectStream(parser.within('<thinking>').stream)
          .timeout(const Duration(seconds: 2));
      expect(inside, contains('This tag is never closed.'));
    });

    test('unclosed tag: future resolves with partial content on stream end', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleUnclosedTag),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final full = await parser.within('<thinking>').future
          .timeout(const Duration(seconds: 2));
      expect(full, isNotEmpty);
      expect(full, contains('This tag is never closed.'));
    });
  });

  // ───────────────────────────────────────────
  // GROUP: Edge cases — multiple occurrences
  // ───────────────────────────────────────────
  group('Edge cases — multiple occurrences of same tag', () {
    test('within() emits content from all occurrences sequentially', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleMultipleOccurrences),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final content = await collectStream(parser.within('<thinking>').stream);
      expect(content, contains('First thought.'));
      expect(content, contains('Second thought.'));
      expect(content, contains('Third thought.'));
    });

    test('outside() emits text between multiple occurrences', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleMultipleOccurrences),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final content = await collectStream(parser.outside('<thinking>').stream);
      expect(content, contains('Some text.'));
      expect(content, contains('More text.'));
    });

    test('adjacent same tags both captured', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleAdjacentTags),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final content = await collectStream(parser.within('<thinking>').stream);
      expect(content, contains('First block.'));
      expect(content, contains('Second block immediately after.'));
    });

    test('text between multiple tags is preserved in outside()', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleTextBetweenTags),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      final content = await collectStream(parser.outside('<thinking>').stream);
      expect(content, contains('Before first.'));
      expect(content, contains('Between first and second.'));
      expect(content, contains('After second.'));
    });
  });

  // ───────────────────────────────────────────
  // GROUP: Late subscriber buffering
  // ───────────────────────────────────────────
  group('Late subscriber buffering', () {
    test('late subscriber on within() receives all buffered content', () async {
      final completer = Completer<LlmTagParser>();

      // Start the stream
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleSimple, delay: const Duration(milliseconds: 50)),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      // Delay subscription by longer than the chunk delay
      await Future.delayed(const Duration(milliseconds: 200));

      // Subscribe late — should still get all content
      final content = await collectStream(parser.within('<thinking>').stream);
      expect(content.trim(), contains('The user is doing a simple greeting.'));

      completer.complete(parser);
    });

    test('late subscriber on outside() receives all buffered content', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleSimple, delay: const Duration(milliseconds: 50)),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );

      await Future.delayed(const Duration(milliseconds: 200));

      final content = await collectStream(parser.outside('<thinking>').stream);
      expect(content.trim(), contains('Hi, what can I do for you?'));
    });
  });

  // ───────────────────────────────────────────
  // GROUP: Chunk size variance
  // ───────────────────────────────────────────
  group('Chunk size variance', () {
    for (final chunkSize in [1, 2, 3, 7, 13, 50, 200]) {
      test('chunk size $chunkSize produces correct output', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks(sampleSimple, chunkSize: chunkSize),
          tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
        );

        final inside = await collectStream(parser.within('<thinking>').stream);
        final outside = await collectStream(parser.outside('<thinking>').stream);

        expect(inside.trim(), contains('The user is doing a simple greeting.'));
        expect(outside.trim(), contains('Hi, what can I do for you?'));
      });
    }
  });

  // ───────────────────────────────────────────
  // GROUP: Edge cases — Level 5 Hardcore Resilience
  // ───────────────────────────────────────────
  group('Edge cases — Level 5 Hardcore Resilience', () {
    test('false alarm / partial match backtrack', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleFalseAlarm),
        tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
      );
      final outside = await collectStream(parser.outside('<thinking>').stream);
      final inside = await collectStream(parser.within('<thinking>').stream);
      expect(outside, contains('<thinking'));
      expect(inside, isEmpty);
    });

    test('prefix overlap selects the longest match', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(samplePrefixOverlap),
        tags: [
          LlmTag(open: '<think>', close: '</think>'),
          LlmTag(open: '<thinking>', close: '</thinking>'),
        ],
      );
      final thinking = await collectStream(parser.within('<thinking>').stream);
      final think = await collectStream(parser.within('<think>').stream);
      expect(thinking.trim(), equals('Hello'));
      expect(think, isEmpty);
    });

    test('self-closing tag resolves immediately with empty stream', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleSelfClosingTag),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );
      final inside = await collectStream(parser.within('<interface {attrs}>').stream);
      final outside = await collectStream(parser.outside('<interface {attrs}>').stream);
      final attrs = await parser.within('<interface {attrs}>').attributes;

      expect(inside.trim(), isEmpty);
      expect(outside, contains('Before  After'));
      expect(attrs['id'], equals('loader'));
    });

    test('malformed attributes parse gracefully', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleMalformedAttributes),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );
      final attrs = await parser.within('<interface {attrs}>').attributes;
      final inside = await collectStream(parser.within('<interface {attrs}>').stream);
      expect(inside, equals('Content'));
      expect(attrs, isNotNull);
    });

    test('interleaved tags handled gracefully', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleInterleavedTags),
        tags: [
          LlmTag(open: '<thinking>', close: '</thinking>'),
          LlmTag(open: '<tool_use>', close: '</tool_use>'),
        ],
      );
      final thinking = await collectStream(parser.within('<thinking>').stream);
      final tool = await collectStream(parser.within('<tool_use>').stream);
      expect(thinking, contains('Interleaved'));
      expect(tool, contains('Interleaved'));
    });
  });
}
