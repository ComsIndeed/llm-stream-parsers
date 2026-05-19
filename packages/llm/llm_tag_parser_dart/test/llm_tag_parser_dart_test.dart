import 'package:llm_tag_parser_dart/llm_tag_parser_dart.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    test('Can instantiate parser', () {
      final stream = Stream.fromIterable(['test']);
      final parser = LlmTagParserDart(
        stream: stream,
        startTags: [],
        stopTags: [],
      );
      expect(parser, isNotNull);
    });
  });
}
