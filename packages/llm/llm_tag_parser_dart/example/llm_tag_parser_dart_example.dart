import 'package:llm_tag_parser_dart/llm_tag_parser_dart.dart';

void main() {
  final stream = Stream.fromIterable(['<thinking>', 'Hello', '</thinking>', ' world!']);
  final parser = LlmTagParserDart(
    stream: stream,
    startTags: ['<thinking>'],
    stopTags: ['</thinking>'],
  );
  print('Parser initialized: $parser');
}
