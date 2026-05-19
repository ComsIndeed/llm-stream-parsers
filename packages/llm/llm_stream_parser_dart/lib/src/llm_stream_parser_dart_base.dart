class LlmStreamParserDart {
  LlmStreamParserDart({
    required Stream<String> stream,
    required List<String> startTags,
    required List<String> stopTags,
  }) {
    stream.listen(onChunk);
  }

  void onChunk(String chunk) {}
}
