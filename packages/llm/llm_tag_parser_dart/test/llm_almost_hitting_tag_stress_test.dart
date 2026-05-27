import 'dart:async';
import 'package:test/test.dart';
import 'package:llm_tag_parser/llm_tag_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Stream<String> streamTextInChunks(
  String text, {
  int chunkSize = 5,
  Duration delay = const Duration(milliseconds: 2),
}) async* {
  for (var i = 0; i < text.length; i += chunkSize) {
    final end = (i + chunkSize).clamp(0, text.length);
    yield text.substring(i, end);
    await Future.delayed(delay);
  }
}

Future<String> collectStream(Stream<String> stream) async {
  final buffer = StringBuffer();
  await for (final chunk in stream) {
    buffer.write(chunk);
  }
  return buffer.toString();
}

void main() {
  group('LlmTagParser - Almost Hitting Tag Stress Tests', () {

    // ─────────────────────────────────────────────────────────────────────────
    // Level 1: Partial Open Tag Prefix followed by conversational text
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 1: Partial tag prefix that never completes is conversational text', () async {
      final input = 'Here is <inter, a false alarm! It should be conversational text.';
      final parser = LlmTagParser(
        stream: streamTextInChunks(input),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final outside = await collectStream(parser.outside('<interface {attrs}>').stream);
      final inside = await collectStream(parser.within('<interface {attrs}>').stream);

      expect(outside, equals(input));
      expect(inside, isEmpty);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Level 2: Partial Open Tag with Attribute Lookalike
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 2: Partial tag open with attributes lookalike but never closed', () async {
      final input = 'Check this <interface id="canvas" test conversational text.';
      final parser = LlmTagParser(
        stream: streamTextInChunks(input),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final outside = await collectStream(parser.outside('<interface {attrs}>').stream);
      final inside = await collectStream(parser.within('<interface {attrs}>').stream);

      expect(outside, equals(input));
      expect(inside, isEmpty);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Level 3: Overlapping Prefixes of Two Registered Tags
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 3: Prefix overlap selects the longest match and does not misfire', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks('<thinking>Inside thinking</thinking> and <think>Inside think</think>'),
        tags: [
          LlmTag(open: '<think>', close: '</think>'),
          LlmTag(open: '<thinking>', close: '</thinking>'),
        ],
      );

      final thinkingContent = await collectStream(parser.within('<thinking>').stream);
      final thinkContent = await collectStream(parser.within('<think>').stream);

      expect(thinkingContent, equals('Inside thinking'));
      expect(thinkContent, equals('Inside think'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Level 4: Partial Close Tag False Alarm
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 4: Partial close tag inside tag is preserved as content', () async {
      final input = '<interface>This is a test of </inter and a partial close tag.</interface>';
      final parser = LlmTagParser(
        stream: streamTextInChunks(input),
        tags: [LlmTag(open: '<interface>', close: '</interface>')],
      );

      final inside = await collectStream(parser.within('<interface>').stream);
      expect(inside, equals('This is a test of </inter and a partial close tag.'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Level 5: Delimiter-like Sequences inside Attributes of Another Tag
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 5: Tag delimiters inside attribute values are not treated as structural tags', () async {
      final input = '<interface note="Almost <interface> tag inside attr" value="</interface>">Content</interface>';
      final parser = LlmTagParser(
        stream: streamTextInChunks(input),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final attrs = await parser.within('<interface {attrs}>').attributes;
      expect(attrs['note'], equals('Almost <interface> tag inside attr'));
      expect(attrs['value'], equals('</interface>'));

      final inside = await collectStream(parser.within('<interface {attrs}>').stream);
      expect(inside, equals('Content'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Level 6: Chunk Boundary Splitting Directly Inside a Partial/Almost-Tag Match
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 6: Boundary split directly through a partial match backtracks cleanly', () async {
      final chunks = ['Here is ', '<in', 'ter', 'fa', 'ce ', 'with space so not a tag'];
      final controller = StreamController<String>();
      final parser = LlmTagParser(
        stream: controller.stream,
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      for (final chunk in chunks) {
        controller.add(chunk);
        await Future.delayed(const Duration(milliseconds: 1));
      }
      await controller.close();

      final outside = await collectStream(parser.outside('<interface {attrs}>').stream);
      expect(outside, equals('Here is <interface with space so not a tag'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Level 7: Multiple Nested / Adjacent False Alarms
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 7: Multiple adjacent unregistered tags are ignored', () async {
      final input = '<thin><thinker><think>actual think</think></thinker></thin>';
      final parser = LlmTagParser(
        stream: streamTextInChunks(input),
        tags: [LlmTag(open: '<think>', close: '</think>')],
      );

      final outside = await collectStream(parser.outside('<think>').stream);
      final inside = await collectStream(parser.within('<think>').stream);

      expect(inside, equals('actual think'));
      expect(outside, equals('<thin><thinker></thinker></thin>'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Level 8: Unregistered XML-like Elements that Look Similar to Registered Tags
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 8: Unregistered longer tag name extensions match prefix and attributes and nest', () async {
      final input = '<interfaces id="1">Not our tag</interfaces><interface-panel>Not ours</interface-panel>';
      final parser = LlmTagParser(
        stream: streamTextInChunks(input),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final instances = await parser.within('<interface {attrs}>').instances.toList();
      expect(instances.length, equals(2));

      expect(instances[0].attributes['s'], equals('true'));
      expect(instances[0].attributes['id'], equals('1'));
      expect(await instances[0].future, contains('Not our tag</interfaces>Not ours</interface-panel>'));

      expect(instances[1].attributes['-panel'], equals('true'));
      expect(await instances[1].future, equals('Not ours</interface-panel>'));

      final outside = await collectStream(parser.outside('<interface {attrs}>').stream);
      expect(outside, isEmpty);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Level 9: Self-closing False Alarms and Malformed Slash Placement
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 9: Malformed self-closing layouts and EOF within unclosed self-closers', () async {
      final input = '<interface / ><interface id="1" / ><interface id="2" /';
      final parser = LlmTagParser(
        stream: streamTextInChunks(input),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final instances = await parser.within('<interface {attrs}>').instances.toList();
      expect(instances.length, equals(2));

      expect(instances[0].attributes, isEmpty);
      expect(instances[1].attributes['id'], equals('1'));

      final outside = await collectStream(parser.outside('<interface {attrs}>').stream);
      expect(outside, equals('<interface id="2" /'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Level 10: The Ultimate "False Alarm" Stream
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 10: Extreme false alarm stream under chunk size 1 pressure', () async {
      final input = 
        '<<inte<'
        '<interface note="<think> nested" value="</interface>">'
        'Some text </interf '
        '<think>Real thinking</think>'
        '</interface>'
        '</interf>';

      final parser = LlmTagParser(
        stream: streamTextInChunks(input, chunkSize: 1),
        tags: [
          LlmTag(open: '<interface {attrs}>', close: '</interface>'),
          LlmTag(open: '<think>', close: '</think>'),
        ],
      );

      final interfaceInstance = await parser.within('<interface {attrs}>').instances.first;
      expect(interfaceInstance.attributes['note'], equals('<think> nested'));
      expect(interfaceInstance.attributes['value'], equals('</interface>'));

      final thinking = await collectStream(parser.within('<think>').stream);
      expect(thinking, equals('Real thinking'));

      final outside = await collectStream(parser.outside('<interface {attrs}>').stream);
      expect(outside, startsWith('<<inte<'));
      expect(outside, endsWith('</interf>'));
    });
  });
}
