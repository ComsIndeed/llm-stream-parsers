import 'dart:async';
import 'package:test/test.dart';
import 'package:llm_tag_parser/llm_tag_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS & SAMPLES
// ─────────────────────────────────────────────────────────────────────────────

Stream<String> streamTextInChunks(
  String text, {
  int chunkSize = 5,
  Duration delay = const Duration(milliseconds: 5),
}) async* {
  for (var i = 0; i < text.length; i += chunkSize) {
    final end = (i + chunkSize).clamp(0, text.length);
    yield text.substring(i, end);
    await Future.delayed(delay);
  }
}

const sampleMultiInterface = '''
Preamble text.

<interface id="main-panel" visible="true">
{"type": "main"}
</interface>

Middle conversational text.

<interface id="side-panel" visible="false">
{"type": "sidebar"}
</interface>

End text.
''';

const sampleSelfClosingAttrs = '''
Some text before.
<interface id="self-closing-loader" type="spinner" />
Some text after.
''';

const sampleUnclosedAttrs = '''
Start text.
<interface id="unclosed-panel" type="canvas"
''';

void main() {
  group('Tag Attribute Subscriptions (getAttributeStream & getAttributeFuture)', () {
    
    // ───────────────────────────────────────────
    // SECTION: getAttributeStream
    // ───────────────────────────────────────────
    group('getAttributeStream', () {
      test('emits correct values sequentially for multiple tag occurrences', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks(sampleMultiInterface),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );

        final idStream = parser.within('<interface {attrs}>').getAttributeStream('id');
        final visibleStream = parser.within('<interface {attrs}>').getAttributeStream('visible');

        final idValues = await idStream.toList();
        final visibleValues = await visibleStream.toList();

        expect(idValues, equals(['main-panel', 'side-panel']));
        expect(visibleValues, equals(['true', 'false']));
      });

      test('emits null when attribute is missing from the tag', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks(sampleMultiInterface),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );

        final nonexistentStream = parser.within('<interface {attrs}>').getAttributeStream('nonexistent');
        final values = await nonexistentStream.toList();

        expect(values, equals([null, null]));
      });

      test('emits nothing and completes if tag is never found in stream', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('Plain text without any interface tags.'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );

        final idStream = parser.within('<interface {attrs}>').getAttributeStream('id');
        final values = await idStream.toList();

        expect(values, isEmpty);
      });

      test('works with self-closing tags', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks(sampleSelfClosingAttrs),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );

        final idStream = parser.within('<interface {attrs}>').getAttributeStream('id');
        final typeStream = parser.within('<interface {attrs}>').getAttributeStream('type');

        final idValues = await idStream.toList();
        final typeValues = await typeStream.toList();

        expect(idValues, equals(['self-closing-loader']));
        expect(typeValues, equals(['spinner']));
      });
    });

    // ───────────────────────────────────────────
    // SECTION: getAttributeFuture
    // ───────────────────────────────────────────
    group('getAttributeFuture', () {
      test('resolves to the value of the first matching occurrence', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks(sampleMultiInterface),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );

        final idFuture = parser.within('<interface {attrs}>').getAttributeFuture('id');
        final visibleFuture = parser.within('<interface {attrs}>').getAttributeFuture('visible');

        expect(await idFuture, equals('main-panel'));
        expect(await visibleFuture, equals('true'));
      });

      test('resolves to null when attribute is missing from the first tag', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks(sampleMultiInterface),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );

        final nonexistentFuture = parser.within('<interface {attrs}>').getAttributeFuture('nonexistent');
        expect(await nonexistentFuture, isNull);
      });

      test('resolves to null if tag is never found in stream before it ends', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks('Plain text without any interface tags.'),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );

        final idFuture = parser.within('<interface {attrs}>').getAttributeFuture('id');
        expect(await idFuture, isNull);
      });

      test('resolves to null for unclosed tags when stream ends before open tag suffix is matched', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks(sampleUnclosedAttrs),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );

        final idFuture = parser.within('<interface {attrs}>').getAttributeFuture('id');
        expect(await idFuture, isNull);
      });
    });

    // ───────────────────────────────────────────
    // SECTION: Late Subscribers
    // ───────────────────────────────────────────
    group('Late Subscribers buffering support', () {
      test('late stream subscriber receives all previously buffered attribute values', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks(sampleMultiInterface),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );

        // Wait for the stream processing to fully complete before subscribing
        await parser.outside('<interface {attrs}>').future;

        final idStream = parser.within('<interface {attrs}>').getAttributeStream('id');
        final values = await idStream.toList();

        expect(values, equals(['main-panel', 'side-panel']));
      });

      test('late future subscriber resolves to first occurrence attribute value correctly', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks(sampleMultiInterface),
          tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
        );

        // Wait for stream to fully finish
        await parser.outside('<interface {attrs}>').future;

        final idFuture = parser.within('<interface {attrs}>').getAttributeFuture('id');
        expect(await idFuture, equals('main-panel'));
      });
    });

    // ───────────────────────────────────────────
    // SECTION: Unregistered Tags
    // ───────────────────────────────────────────
    group('Unregistered Tags behavior', () {
      test('unregistered tag attributes return empty stream or null future', () async {
        final parser = LlmTagParser(
          stream: streamTextInChunks(sampleMultiInterface),
          tags: [], // No registered tags
        );

        final idStream = parser.within('<interface {attrs}>').getAttributeStream('id');
        final idFuture = parser.within('<interface {attrs}>').getAttributeFuture('id');

        expect(await idStream.toList(), isEmpty);
        expect(await idFuture, isNull);
      });
    });
  });
}
