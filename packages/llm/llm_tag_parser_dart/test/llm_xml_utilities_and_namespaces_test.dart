import 'dart:async';
import 'package:test/test.dart';
import 'package:llm_tag_parser/llm_tag_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Stream<String> streamTextInChunks(
  String text, {
  int chunkSize = 5,
  Duration delay = const Duration(milliseconds: 1),
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
  group('LlmTagParser - XML Utilities & Dot-Notation Namespaces', () {
    
    // ─────────────────────────────────────────────────────────────────────────
    // 1. XmlTagUtilities static tests
    // ─────────────────────────────────────────────────────────────────────────
    group('XmlTagUtilities.getTagName', () {
      test('extracts clean name from simple tag', () {
        expect(XmlTagUtilities.getTagName('<interface>'), equals('interface'));
        expect(XmlTagUtilities.getTagName('<interface {attrs}>'), equals('interface'));
      });

      test('extracts name with dot notation and namespaces', () {
        expect(XmlTagUtilities.getTagName('<Material.Card>'), equals('Material.Card'));
        expect(XmlTagUtilities.getTagName('<Material.Card {attrs}>'), equals('Material.Card'));
        expect(XmlTagUtilities.getTagName('<ui:button>'), equals('ui:button'));
        expect(XmlTagUtilities.getTagName('<ui:button {attrs}>'), equals('ui:button'));
      });

      test('extracts name with self-closing and spacing attributes', () {
        expect(XmlTagUtilities.getTagName('<interface {attrs}/>'), equals('interface'));
        expect(XmlTagUtilities.getTagName('<Material.Card />'), equals('Material.Card'));
      });

      test('returns null for non-XML/HTML format tags', () {
        expect(XmlTagUtilities.getTagName('[interface]'), isNull);
        expect(XmlTagUtilities.getTagName(r'$think$'), isNull);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 2. TagNode.tagName property integration
    // ─────────────────────────────────────────────────────────────────────────
    test('TagNode exposes tagName property', () async {
      final input = '<Material.Card id="main">Card Content</Material.Card>';
      final parser = LlmTagParser(
        stream: streamTextInChunks(input),
        tags: [LlmTag(open: '<Material.Card {attrs}>', close: '</Material.Card>')],
      );

      final instances = await parser.within('<Material.Card {attrs}>').instances.toList();
      expect(instances.length, equals(1));
      expect(instances[0].tagName, equals('Material.Card'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Namespace and dot-notation tag streaming & parsing
    // ─────────────────────────────────────────────────────────────────────────
    test('Dot-notation and namespace tags stream and parse attributes correctly', () async {
      final input = 
        '<Material.Card elevation="4" margin="8">\n'
          '<ui:button type="flat" disabled>Click Me</ui:button>\n'
        '</Material.Card>';

      final parser = LlmTagParser(
        stream: streamTextInChunks(input),
        tags: [
          LlmTag(open: '<Material.Card {attrs}>', close: '</Material.Card>'),
          LlmTag(open: '<ui:button {attrs}>', close: '</ui:button>'),
        ],
      );

      final cardInstances = await parser.within('<Material.Card {attrs}>').instances.toList();
      final buttonInstances = await parser.within('<ui:button {attrs}>').instances.toList();

      expect(cardInstances.length, equals(1));
      expect(buttonInstances.length, equals(1));

      expect(cardInstances[0].tagName, equals('Material.Card'));
      expect(cardInstances[0].attributes['elevation'], equals('4'));
      expect(cardInstances[0].attributes['margin'], equals('8'));

      expect(buttonInstances[0].tagName, equals('ui:button'));
      expect(buttonInstances[0].attributes['type'], equals('flat'));
      expect(buttonInstances[0].attributes['disabled'], equals('true'));
    });
  });
}
