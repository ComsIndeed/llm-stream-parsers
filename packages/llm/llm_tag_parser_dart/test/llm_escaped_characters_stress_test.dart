import 'dart:async';
import 'dart:convert';
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
  group('LlmTagParser - Escaped Characters Stress Tests', () {
    
    // ─────────────────────────────────────────────────────────────────────────
    // Level 1: Simple Escaped Attribute Quotes
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 1: Simple escaped attribute quotes in single & double quotes', () async {
      final input = r'''<interface desc="he\"llo" simple='wor\'ld'>Content</interface>''';
      final parser = LlmTagParser(
        stream: streamTextInChunks(input),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final attrs = await parser.within('<interface {attrs}>').attributes;
      expect(attrs['desc'], equals('he"llo'));
      expect(attrs['simple'], equals("wor'ld"));
      
      final content = await collectStream(parser.within('<interface {attrs}>').stream);
      expect(content, equals('Content'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Level 2: Escaped Backslashes in Attribute Values
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 2: Escaped backslashes resolving to single backslashes', () async {
      final input = r'''<interface path="C:\\Users\\Truly" file='my\\file.txt'>Content</interface>''';
      final parser = LlmTagParser(
        stream: streamTextInChunks(input),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final attrs = await parser.within('<interface {attrs}>').attributes;
      expect(attrs['path'], equals(r'C:\Users\Truly'));
      expect(attrs['file'], equals(r'my\file.txt'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Level 3: Escaped Characters inside Content (Outside Attributes)
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 3: Escaped characters inside content are preserved verbatim', () async {
      final input = r'<interface>This is a backslash: \\ and an escaped tag: \<interface\></interface>';
      final parser = LlmTagParser(
        stream: streamTextInChunks(input),
        tags: [LlmTag(open: '<interface>', close: '</interface>')],
      );

      final content = await collectStream(parser.within('<interface>').stream);
      expect(content, equals(r'This is a backslash: \\ and an escaped tag: \<interface\>'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Level 4: Escaped Characters Cut by Chunk Boundaries (Single-char splits)
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 4: Escaped character sequence split across multiple chunks', () async {
      // Chunk cuts right through the escape: "he", "llo \\", "\"", "o"
      final chunks = ['<interface desc="he', 'llo \\', '"', 'o">Content</interface>'];
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

      final attrs = await parser.within('<interface {attrs}>').attributes;
      expect(attrs['desc'], equals('hello "o'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Level 5: Nested Tags with Mixed and Nested Escapes in Both Layers
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 5: Nested tags with mixed escapes in both layers', () async {
      final input = r'''<parent name="pa\"rent"><child value="ch\'ild" desc="nested \"quote\"">Content</child></parent>''';
      final parser = LlmTagParser(
        stream: streamTextInChunks(input),
        tags: [
          LlmTag(open: '<parent {attrs}>', close: '</parent>'),
          LlmTag(open: '<child {attrs}>', close: '</child>'),
        ],
      );

      final parentAttrs = await parser.within('<parent {attrs}>').attributes;
      final childAttrs = await parser.within('<child {attrs}>').attributes;

      expect(parentAttrs['name'], equals('pa"rent'));
      expect(childAttrs['value'], equals("ch'ild"));
      expect(childAttrs['desc'], equals('nested "quote"'));

      final childContent = await collectStream(parser.within('<child {attrs}>').stream);
      expect(childContent, equals('Content'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Level 6: Complex JSON Payload in Attributes with Escaped Quotes and Slashes
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 6: Highly intense JSON payload in attribute containing escaped quotes & slashes', () async {
      // The JSON string we want inside config attribute:
      // {"server": "localhost", "paths": ["\\bin\\app", "\\lib"], "desc": "\"extreme\""}
      // To get this, we need to escape both quotes and backslashes in the raw stream attribute.
      final input = r'<interface config="{\"server\": \"localhost\", \"paths\": [\"\\\\bin\\\\app\", \"\\\\lib\"], \"desc\": \"\\\"extreme\\\"\"}">Content</interface>';
      final parser = LlmTagParser(
        stream: streamTextInChunks(input),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final attrs = await parser.within('<interface {attrs}>').attributes;
      final configJson = attrs['config']!;
      
      // Verify parsing of individual components via JSON decoding
      final Map<String, dynamic> decoded = jsonDecode(configJson);
      expect(decoded['server'], equals('localhost'));
      expect(decoded['paths'], equals(['\\bin\\app', '\\lib']));
      expect(decoded['desc'], equals('"extreme"'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Level 7: Escape Characters Near Self-Closing Tags and Demarcators
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 7: Escapes near self-closing tags and attribute value boundaries', () async {
      final input = r'''<interface isSelf="true" path="C:\\\\" disabled /><interface path="foo\\" />''';
      final parser = LlmTagParser(
        stream: streamTextInChunks(input),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final instances = await parser.within('<interface {attrs}>').instances.toList();
      expect(instances.length, equals(2));

      final firstAttrs = instances[0].attributes;
      final secondAttrs = instances[1].attributes;

      expect(firstAttrs['isSelf'], equals('true'));
      expect(firstAttrs['path'], equals(r'C:\\'));
      expect(firstAttrs['disabled'], equals('true'));

      expect(secondAttrs['path'], equals(r'foo\'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Level 8: Escapes in Non-XML Tag Formats (Bracket & Custom Delimiters)
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 8: Escaped characters inside bracket style attributes', () async {
      final input = r'[interface id="btn\"1" style="color:\\\"red\\\""]Content[/interface]';
      final parser = LlmTagParser(
        stream: streamTextInChunks(input),
        tags: [
          LlmTag(open: '[interface {attrs}]', close: '[/interface]'),
        ],
      );

      final attrs = await parser.within('[interface {attrs}]').attributes;
      expect(attrs['id'], equals('btn"1'));
      expect(attrs['style'], equals('color:\\"red\\"'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Level 9: Unicode / Multi-byte / Complex Character Escapes
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 9: Unicode characters and generic escapes mixed together', () async {
      // In our parser implementation:
      // any backslash followed by char writes that char directly.
      // E.g. \n -> n, \t -> t, \\ -> \, \" -> ", \✨ -> ✨
      final input = r'<interface desc="Emoji: 🚀 \n Tab: \t Path: C:\\User\\✨" symbol="\"\\u2728\"">Content</interface>';
      final parser = LlmTagParser(
        stream: streamTextInChunks(input),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final attrs = await parser.within('<interface {attrs}>').attributes;
      expect(attrs['desc'], equals(r'Emoji: 🚀 n Tab: t Path: C:\User\✨'));
      expect(attrs['symbol'], equals(r'"\u2728"'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Level 10: Ultimate Chaos Escape Stream
    // ─────────────────────────────────────────────────────────────────────────
    test('Level 10: Chaos escape stream containing deep nesting, multiple self-closers, chunk size 1', () async {
      final input = 
        r'''<parent desc="p\\\"1">'''
          r'''Before child '''
          r'''<child tag="c1" info="nested\\\"val" />'''
          r''' After child'''
        r'''</parent>''';

      // Force chunk size of 1 to put massive pressure on buffer matching and escaping
      final parser = LlmTagParser(
        stream: streamTextInChunks(input, chunkSize: 1),
        tags: [
          LlmTag(open: '<parent {attrs}>', close: '</parent>'),
          LlmTag(open: '<child {attrs}>', close: '</child>'),
        ],
      );

      final parentInstance = await parser.within('<parent {attrs}>').instances.first;
      expect(parentInstance.attributes['desc'], equals(r'p\"1'));

      final childInstance = await parser.within('<child {attrs}>').instances.first;
      expect(childInstance.attributes['tag'], equals('c1'));
      expect(childInstance.attributes['info'], equals(r'nested\"val'));

      final parentContent = await parentInstance.future;
      expect(parentContent, contains('Before child '));
      expect(parentContent, contains(' After child'));
    });
  });
}
