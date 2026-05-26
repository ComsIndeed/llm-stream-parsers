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

const sampleChronological = '''
Start conversational text.
<interface id="panel-1">Content inside first tag</interface>
Middle text between tags.
<interface id="panel-2">Content inside second tag</interface>
End text.
''';

const sampleNestedNesting = '''
<thinking>
Thinking preamble.
<tool_use>Inside nested tool_use.</tool_use>
Thinking postamble.
</thinking>
Outside tag.
''';

void main() {
  group('Tag Instance Isolation & Chronological Node Stream (v2)', () {

    // ───────────────────────────────────────────
    // SECTION: Chronological Node Order
    // ───────────────────────────────────────────
    test('emits nodes in exact chronological order', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleChronological),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final nodesList = await parser.nodes.toList();

      // We expect TextNodes and TagNodes interleaved chronologically
      expect(nodesList, isNotEmpty);

      // Verify overall structure
      final textNodes = nodesList.whereType<TextNode>().toList();
      final tagNodes = nodesList.whereType<TagNode>().toList();

      expect(tagNodes.length, equals(2));
      expect(tagNodes[0].attributes['id'], equals('panel-1'));
      expect(tagNodes[1].attributes['id'], equals('panel-2'));

      // Check specific chronological node sequence
      final firstTagIndex = nodesList.indexWhere((n) => n is TagNode);
      expect(firstTagIndex, greaterThan(0));
      expect((nodesList[firstTagIndex] as TagNode).attributes['id'], equals('panel-1'));

      // The nodes before the first TagNode should be TextNodes, and their combined text
      // should contain "Start conversational text."
      final preambleNodes = nodesList.sublist(0, firstTagIndex).whereType<TextNode>();
      final combinedPreamble = preambleNodes.map((n) => n.text).join();
      expect(combinedPreamble, contains('Start conversational text.'));

      // Followed by TextNode for "Content inside first tag" inside that tag instance stream
      final firstTagContent = await (nodesList[firstTagIndex] as TagNode).future;
      expect(firstTagContent, equals('Content inside first tag'));
    });

    // ───────────────────────────────────────────
    // SECTION: True Instance Isolation
    // ───────────────────────────────────────────
    test('tag instances have fully isolated content streams and attributes', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleChronological),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      final instances = await parser.within('<interface {attrs}>').instances.toList();

      expect(instances.length, equals(2));

      final firstInstance = instances[0];
      final secondInstance = instances[1];

      // Verify isolated attributes
      expect(firstInstance.attributes['id'], equals('panel-1'));
      expect(secondInstance.attributes['id'], equals('panel-2'));

      // Verify isolated streams
      final firstContent = await firstInstance.stream.join();
      final secondContent = await secondInstance.stream.join();

      expect(firstContent, equals('Content inside first tag'));
      expect(secondContent, equals('Content inside second tag'));

      // Verify isolated futures
      expect(await firstInstance.future, equals('Content inside first tag'));
      expect(await secondInstance.future, equals('Content inside second tag'));
    });

    // ───────────────────────────────────────────
    // SECTION: Nested Tag Isolation
    // ───────────────────────────────────────────
    test('nested tag content is routed correctly without bleeding', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleNestedNesting),
        tags: [
          LlmTag(open: '<thinking>', close: '</thinking>'),
          LlmTag(open: '<tool_use>', close: '</tool_use>'),
        ],
      );

      final thinkingInstances = await parser.within('<thinking>').instances.toList();
      final toolInstances = await parser.within('<tool_use>').instances.toList();

      expect(thinkingInstances.length, equals(1));
      expect(toolInstances.length, equals(1));

      // tool_use is nested inside thinking, so thinking's stream should contain all content
      // including tool_use text, while tool_use only contains its own isolated text.
      final thinkingContent = await thinkingInstances[0].future;
      final toolContent = await toolInstances[0].future;

      expect(toolContent.trim(), equals('Inside nested tool_use.'));
      expect(thinkingContent, contains('Thinking preamble.'));
      expect(thinkingContent, contains('Inside nested tool_use.'));
      expect(thinkingContent, contains('Thinking postamble.'));
    });

    // ───────────────────────────────────────────
    // SECTION: Late / Multiple Subscribers
    // ───────────────────────────────────────────
    test('late subscribers to nodes and tag streams receive all buffered events correctly', () async {
      final parser = LlmTagParser(
        stream: streamTextInChunks(sampleChronological),
        tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
      );

      // Wait until parser is completely closed
      await parser.outside('<interface {attrs}>').future;

      // Late subscription to parser.nodes
      final nodesList = await parser.nodes.toList();
      expect(nodesList.length, greaterThan(3));

      // Late subscription to specific TagNode streams
      final tagNodes = nodesList.whereType<TagNode>().toList();
      expect(tagNodes.length, equals(2));

      final firstContent = await tagNodes[0].stream.join();
      final secondContent = await tagNodes[1].stream.join();

      expect(firstContent, equals('Content inside first tag'));
      expect(secondContent, equals('Content inside second tag'));
    });
  });
}
