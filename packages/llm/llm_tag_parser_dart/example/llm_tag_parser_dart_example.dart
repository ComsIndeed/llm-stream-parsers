import 'package:llm_tag_parser/llm_tag_parser.dart';

void main() {
  final stream = Stream.fromIterable(['<thinking>', 'Hello', '</thinking>', ' world!']);
  final parser = LlmTagParser(
    stream: stream,
    tags: [
      LlmTag(open: '<thinking>', close: '</thinking>'),
    ],
  );
  print('Parser initialized: $parser');
}
