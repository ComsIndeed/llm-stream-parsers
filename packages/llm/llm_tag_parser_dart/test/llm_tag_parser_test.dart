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

    group('Static History Restoration Chunks', () {
      test('case 1: single chunk, conversational text only (no tags)', () async {
        final text = 'Hello, this is just conversational text with no tags at all.';
        final parser = LlmTagParser(
          stream: Stream.value(text),
          tags: [
            LlmTag(
              open: '<interface{attrs}>',
              close: '</interface>',
              attributePlaceholder: '{attrs}',
            ),
          ],
        );
        final inside = await collectStream(parser.within('<interface{attrs}>').stream);
        final outside = await collectStream(parser.outside('<interface{attrs}>').stream);

        expect(inside, isEmpty);
        expect(outside.trim(), equals(text));
      });

      test('case 2: single chunk, preamble + interface tag (no after-amble)', () async {
        final text = 'Here is your panel:\n<interface viewId="canvas">{"namespace": "core:panel"}</interface>';
        final parser = LlmTagParser(
          stream: Stream.value(text),
          tags: [
            LlmTag(
              open: '<interface{attrs}>',
              close: '</interface>',
              attributePlaceholder: '{attrs}',
            ),
          ],
        );
        final inside = await collectStream(parser.within('<interface{attrs}>').stream);
        final outside = await collectStream(parser.outside('<interface{attrs}>').stream);

        expect(inside.trim(), equals('{"namespace": "core:panel"}'));
        expect(outside.trim(), equals('Here is your panel:'));
      });

      test('case 3: single chunk, preamble + interface tag + after-amble', () async {
        final text = 'Preamble text\n<interface viewId="canvas">{"namespace": "core:panel"}</interface>\nAfter-amble text';
        final parser = LlmTagParser(
          stream: Stream.value(text),
          tags: [
            LlmTag(
              open: '<interface{attrs}>',
              close: '</interface>',
              attributePlaceholder: '{attrs}',
            ),
          ],
        );
        final inside = await collectStream(parser.within('<interface{attrs}>').stream);
        final outside = await collectStream(parser.outside('<interface{attrs}>').stream);

        expect(inside.trim(), equals('{"namespace": "core:panel"}'));
        expect(outside.trim(), equals('Preamble text\n\nAfter-amble text'));
      });

      test('case 4: single chunk, multiple interface tags with text between and after', () async {
        final text = 'Preamble\n<interface viewId="c1">W1</interface>\nBetween\n<interface viewId="c2">W2</interface>\nAfter';
        final parser = LlmTagParser(
          stream: Stream.value(text),
          tags: [
            LlmTag(
              open: '<interface{attrs}>',
              close: '</interface>',
              attributePlaceholder: '{attrs}',
            ),
          ],
        );
        final inside = await collectStream(parser.within('<interface{attrs}>').stream);
        final outside = await collectStream(parser.outside('<interface{attrs}>').stream);

        expect(inside.trim(), contains('W1'));
        expect(inside.trim(), contains('W2'));
        expect(outside.trim(), equals('Preamble\n\nBetween\n\nAfter'));
      });

      test('case 5: single chunk, tag with attributes and multi-line formatting inside JSON', () async {
        final text = '''
Preamble
<interface id="main" schema="v2">
{
  "namespace": "core:pricing_table",
  "plan": "Premium"
}
</interface>
After-amble''';
        final parser = LlmTagParser(
          stream: Stream.value(text),
          tags: [
            LlmTag(
              open: '<interface{attrs}>',
              close: '</interface>',
              attributePlaceholder: '{attrs}',
            ),
          ],
        );
        final inside = await collectStream(parser.within('<interface{attrs}>').stream);
        final outside = await collectStream(parser.outside('<interface{attrs}>').stream);
        final attrs = await parser.within('<interface{attrs}>').attributes;

        expect(attrs['id'], equals('main'));
        expect(attrs['schema'], equals('v2'));
        expect(inside.trim(), contains('"namespace": "core:pricing_table"'));
        expect(outside.trim(), equals('Preamble\n\nAfter-amble'));
      });

      test('case 6: reproduce user after-amble missing with XML tag inside', () async {
        final text = '''
I understand! You would like me to provide a preamble and an after-amble before and after showing the weather information.

Here is the weather for Manila with a preamble and after-amble:

**Preamble:** I have fetched the current weather information for Manila for you.

<interface>
  <Weather city="Manila" />
</interface>

**After amble:** I hope this weather information is helpful for you!''';

        final parser = LlmTagParser(
          stream: Stream.value(text),
          tags: [
            LlmTag(
              open: '<interface{attrs}>',
              close: '</interface>',
              attributePlaceholder: '{attrs}',
            ),
          ],
        );
        final inside = await collectStream(parser.within('<interface{attrs}>').stream);
        final outside = await collectStream(parser.outside('<interface{attrs}>').stream);

        expect(inside.trim(), contains('<Weather city="Manila" />'));
        expect(outside.trim(), contains('After amble:'));
      });
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

  // ───────────────────────────────────────────
  // GROUP: Attributes Robustness - Intensive Edge Cases
  // ───────────────────────────────────────────
  group('Attributes Robustness - Intensive Edge Cases', () {
    // CATEGORY A: Key-Value Syntax & Special Character Keys
    group('Category A: Key-Value Syntax & Special Character Keys', () {
      test('A.1: Keys with standard hyphens and namespaces', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface data-id="123" xml:lang="en">Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs['data-id'], equals('123'));
        expect(attrs['xml:lang'], equals('en'));
      });

      test('A.2: Keys with dots, underscores, and mixed symbols', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface my.custom_field-name="val1" package:version="2.0">Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs['my.custom_field-name'], equals('val1'));
        expect(attrs['package:version'], equals('2.0'));
      });

      test('A.3: Mixed case sensitivity and leading symbols', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface _id="test" KEY-VALUE="extreme">Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs['_id'], equals('test'));
        expect(attrs['KEY-VALUE'], equals('extreme'));
      });

      test('A.4: Keys starting with or containing numbers', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface 123attr="one" alpha3="two">Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs['123attr'], equals('one'));
        expect(attrs['alpha3'], equals('two'));
      });

      test('A.5: Extremely intense XML-compliant special characters', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface ns:a.b-c_d="intense_val">Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs['ns:a.b-c_d'], equals('intense_val'));
      });
    });

    // CATEGORY B: Quoting Variations & Escapes
    group('Category B: Quoting Variations & Escapes', () {
      test('B.1: Simple unquoted attribute value', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface id=main>Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs['id'], equals('main'));
      });

      test('B.2: Mixed unquoted, single-quoted, and double-quoted attributes', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface id=main type=\'panel\' class="container">Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs['id'], equals('main'));
        expect(attrs['type'], equals('panel'));
        expect(attrs['class'], equals('container'));
      });

      test('B.3: Escaped double quotes inside double quotes', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface description="This is a \\"cool\\" feature" name="john">Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs['description'], equals('This is a "cool" feature'));
        expect(attrs['name'], equals('john'));
      });

      test('B.4: Escaped single quotes inside single quotes', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface phrase=\'It\\\'s a beautiful day\' active=true>Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs['phrase'], equals("It's a beautiful day"));
        expect(attrs['active'], equals('true'));
      });

      test('B.5: Highly intense nested and mixed escapes', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface json="{\\"a\\": \\"b\\", \\"c\\": \'d\'}" raw=\'escaped \\" quotes\'>Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs['json'], equals('{"a": "b", "c": \'d\'}'));
        expect(attrs['raw'], equals('escaped " quotes'));
      });
    });

    // CATEGORY C: Delimiter & Structural Bracket Collisions
    group('Category C: Delimiter & Structural Bracket Collisions', () {
      test('C.1: Attribute value containing angle bracket closing symbol', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface condition="age > 21">Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        final inside = await collectStream(parser.within('<interface {attrs}>').stream);
        expect(attrs['condition'], equals('age > 21'));
        expect(inside, equals('Content'));
      });

      test('C.2: Attribute value containing multiple mathematical operators', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface formula="a < b && c > d">Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        final inside = await collectStream(parser.within('<interface {attrs}>').stream);
        expect(attrs['formula'], equals('a < b && c > d'));
        expect(inside, equals('Content'));
      });

      test('C.3: Attribute value containing partial HTML/XML tags', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface template="<div class=\\"test\\">">Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        final inside = await collectStream(parser.within('<interface {attrs}>').stream);
        expect(attrs['template'], equals('<div class="test">'));
        expect(inside, equals('Content'));
      });

      test('C.4: Attribute value containing the full close tag sequence', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface unsafe="Inside </interface> text">Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        final inside = await collectStream(parser.within('<interface {attrs}>').stream);
        expect(attrs['unsafe'], equals('Inside </interface> text'));
        expect(inside, equals('Content'));
      });

      test('C.5: Intense nested tags, brackets, and self-closing slashes', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface data="<nested tag=\'attr\' />" test="x > y">Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        final inside = await collectStream(parser.within('<interface {attrs}>').stream);
        expect(attrs['data'], equals("<nested tag='attr' />"));
        expect(attrs['test'], equals('x > y'));
        expect(inside, equals('Content'));
      });
    });

    // CATEGORY D: Boolean & Key-Only Attributes
    group('Category D: Boolean & Key-Only Attributes', () {
      test('D.1: Single standalone boolean flag', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface disabled>Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs.containsKey('disabled'), isTrue);
      });

      test('D.2: Mixed boolean flags and standard attributes', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface checked readonly class="input" disabled>Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs.containsKey('checked'), isTrue);
        expect(attrs.containsKey('readonly'), isTrue);
        expect(attrs['class'], equals('input'));
        expect(attrs.containsKey('disabled'), isTrue);
      });

      test('D.3: Boolean flag adjacent to self-closing slash', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface id="btn" disabled/>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs['id'], equals('btn'));
        expect(attrs.containsKey('disabled'), isTrue);
      });

      test('D.4: Boolean flag with trailing self-closing spaces and slash', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface checked   />'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs.containsKey('checked'), isTrue);
      });

      test('D.5: Highly intense combination of boolean, unquoted, and slash elements', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface selected visible id=box active/>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs.containsKey('selected'), isTrue);
        expect(attrs.containsKey('visible'), isTrue);
        expect(attrs['id'], equals('box'));
        expect(attrs.containsKey('active'), isTrue);
      });
    });

    // CATEGORY E: Multi-Line, Whitespace, & Stream Boundary Variations
    group('Category E: Multi-Line, Whitespace, & Stream Boundary Variations', () {
      test('E.1: Spacing and tab variations around equal signs', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface id  \t  =  \t  "main"  type  =  \'panel\'>Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs['id'], equals('main'));
        expect(attrs['type'], equals('panel'));
      });

      test('E.2: Attributes spread across multiple lines with formatting whitespace', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface\n  id="main"\n  type="panel"\n  version="1"\n>Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs['id'], equals('main'));
        expect(attrs['type'], equals('panel'));
        expect(attrs['version'], equals('1'));
      });

      test('E.3: Zero spacing between key-values', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('<interface id="main"type="panel"class="dark">Content</interface>'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs['id'], equals('main'));
        expect(attrs['type'], equals('panel'));
        expect(attrs['class'], equals('dark'));
      });

      test('E.4: Stream chunk boundaries cutting directly through equal sign', () async {
        final chunks = ['<interface id', '="ma', 'in" ty', 'pe="pa', 'nel">Con', 'tent</interface>'];
        final controller = StreamController<String>();
        final parser = LlmTagParser(
          stream: controller.stream,
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        for (final chunk in chunks) {
          controller.add(chunk);
          await Future.delayed(const Duration(milliseconds: 5));
        }
        await controller.close();

        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs['id'], equals('main'));
        expect(attrs['type'], equals('panel'));
      });

      test('E.5: Intense chunk boundary split inside escaped quote value', () async {
        final chunks = ['<interface escaped="he', 'llo \\"', 'wor', 'ld\\"" type="panel">', 'Content</interface>'];
        final controller = StreamController<String>();
        final parser = LlmTagParser(
          stream: controller.stream,
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );
        for (final chunk in chunks) {
          controller.add(chunk);
          await Future.delayed(const Duration(milliseconds: 5));
        }
        await controller.close();

        final attrs = await parser.within('<interface {attrs}>').attributes;
        expect(attrs['escaped'], equals('hello "world"'));
        expect(attrs['type'], equals('panel'));
      });
    });
  });
}

