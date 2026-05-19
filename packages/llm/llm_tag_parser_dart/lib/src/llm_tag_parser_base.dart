import 'dart:async';

enum AttributeFormat {
  xml,
  keyOnly,
}

class LlmTag {
  final String open;
  final String close;

  LlmTag({
    required this.open,
    required this.close,
  });

  LlmTag withAttributes(String placeholder, {required AttributeFormat format}) {
    return this;
  }
}

class LlmTagContent {
  Stream<String> get stream => const Stream<String>.empty();
  Future<String> get future => Future.value('');
  Future<Map<String, String>> get attributes => Future.value(const <String, String>{});
  Stream<String?> attribute(String name) => const Stream<String?>.empty();

  LlmTagContent within(String tag) => this;
  LlmTagContent outside(String tag) => this;
}

class LlmTagParser {
  LlmTagParser({
    required Stream<String> stream,
    required List<LlmTag> tags,
  });

  LlmTagContent within(String tag) => LlmTagContent();
  LlmTagContent outside(String tag) => LlmTagContent();
}
