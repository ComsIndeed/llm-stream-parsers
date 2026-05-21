<div align="center">

# LLM Tag Parser

**The streaming tag parser for AI applications**

[![pub package](https://img.shields.io/pub/v/llm_tag_parser.svg)](https://pub.dev/packages/llm_tag_parser)
[![Dart](https://img.shields.io/badge/dart-%3E%3D3.11.0-blue)]()
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)

Parse and isolate tagged blocks reactively as LLM responses stream in. Subscribe
to blocks and receive values chunk-by-chunk as they are generated: no waiting
for the complete response.

[**API Docs**](https://pub.dev/documentation/llm_tag_parser/latest/) ·
[**GitHub**](https://github.com/ComsIndeed/llm-stream-parsers/tree/main/packages/llm/llm_tag_parser_dart)

</div>

## Table of Contents

- [The Problem](#the-problem)
- [The Solution](#the-solution)
- [Quick Start](#quick-start)
- [How It Works](#how-it-works)
- [Feature Highlights](#feature-highlights)
  - [Streaming Inner Content](#streaming-inner-content)
  - [Streaming Outer Content](#streaming-outer-content)
  - [Hierarchical Nesting](#hierarchical-nesting)
  - [Attribute Extraction](#attribute-extraction)
  - [Custom Delimiters](#custom-delimiters)
  - [Robust Stream Buffering](#robust-stream-buffering)
- [Complete Example](#complete-example)
- [API Reference](#api-reference)
- [Robustness](#robustness)
- [LLM Provider Setup](#llm-provider-setup)
- [Contributing](#contributing)
- [License](#license)

---

## The Problem

LLMs stream responses token-by-token. Often, they generate mixed responses
containing both conversational text and specialized blocks like thoughts, tool
calls, or code blocks. Traditional string-searching or regex-based approaches
fail because:

| Approach                       | Problem                                                    |
| ------------------------------ | ---------------------------------------------------------- |
| Wait for complete response     | Introduces high latency, defeats the purpose of streaming  |
| Substring search on raw stream | Fails on partial tags split across chunks, high complexity |
| Custom state-machine parser    | Hard to implement, error-prone, handles boundaries poorly  |

## The Solution

LLM Tag Parser processes streams token-by-token as they arrive, allowing you to
subscribe to content inside tags, content outside tags, and even nested tags the
moment they begin streaming.

Instead of waiting for the entire response to finish, you can:

- Render thought blocks in a collapsible UI element in real-time
- Stream tool parameters progressively
- Keep conversational text completely separated from structured code blocks

---

## Quick Start

```yaml
# pubspec.yaml
dependencies:
  llm_tag_parser: ^0.1.2
```

```dart
import 'package:llm_tag_parser/llm_tag_parser.dart';

final parser = LlmTagParser(
  stream: llmResponseStream,
  tags: [
    LlmTag(open: '<thinking>', close: '</thinking>'),
  ],
);

// Stream thought content chunk-by-chunk
parser.within('<thinking>').stream.listen((chunk) {
  print('Thought: $chunk');
});

// Stream conversational text outside thinking blocks
parser.outside('<thinking>').stream.listen((chunk) {
  print('Chat: $chunk');
});
```

---

## How It Works

### Two APIs for Every Match

Every isolated block (within or outside) provides both a stream for real-time
updates and a future for the complete value:

```dart
final content = parser.within('<thinking>');

content.stream.listen((chunk) => ...); // Incremental chunks as they arrive
final complete = await content.future;  // The fully accumulated string
```

| Use Case                                     | API       |
| -------------------------------------------- | --------- |
| Smooth UI typing effects                     | `.stream` |
| Accumulating tool calls, JSON, or processing | `.future` |

---

## Feature Highlights

### Streaming Inner Content

Isolate and render block contents as they stream in:

```dart
parser.within('<thinking>').stream.listen((chunk) {
  updateThoughtUI(chunk);
});
```

### Streaming Outer Content

Capture only the main conversational text, omitting thoughts or tool invocations
completely:

```dart
parser.outside('<thinking>').stream.listen((chunk) {
  updateMainChatUI(chunk);
});
```

### Hierarchical Nesting

Tag parsing supports nesting. You can drill down into tag hierarchies:

```dart
// Extract tool_use that is inside a thinking block
parser.within('<thinking>').within('<tool_use>').stream.listen((chunk) {
  print('Nested tool chunk: $chunk');
});
```

### Attribute Extraction

XML-style tags often pack metadata:

```dart
final parser = LlmTagParser(
  stream: stream,
  tags: [
    LlmTag(open: '<interface {attrs}>', close: '</interface>'),
  ],
);

// Get a Map of the parsed attributes
final attrs = await parser.within('<interface {attrs}>').attributes;
print('ID: ${attrs['id']}');

// Or listen to an attribute value as it streams
parser.within('<interface {attrs}>').attribute('id').listen((idValue) {
  print('ID updated: $idValue');
});
```

### Custom Delimiters

Not every model produces XML. You can register any pair of custom tags:

```dart
final parser = LlmTagParser(
  stream: stream,
  tags: [
    LlmTag(open: '[thinking]', close: '[/thinking]'),
    LlmTag(open: r'$think$', close: r'$end$'),
  ],
);
```

### Robust Stream Buffering

To prevent race conditions where a subscriber listens to the stream after the
initial tokens have already passed, the parser automatically buffers. A late
subscriber will always receive all prior emitted chunks:

```dart
final content = parser.within('<thinking>');

// Delay subscription by some time
await Future.delayed(const Duration(milliseconds: 100));

// Still receives all chunks from the beginning of the block
content.stream.listen((chunk) => print(chunk));
```

---

## Complete Example

```dart
import 'package:llm_tag_parser/llm_tag_parser.dart';

void main() async {
  final stream = llm.streamChat('Explain quantum physics');

  final parser = LlmTagParser(
    stream: stream,
    tags: [
      LlmTag(open: '<thinking>', close: '</thinking>'),
      LlmTag(open: '<interface {attrs}>', close: '</interface>'),
    ],
  );

  // Render thought block live
  parser.within('<thinking>').stream.listen((chunk) {
    print('Thought chunk: $chunk');
  });

  // Extract attributes and content from interface block
  final interface = parser.within('<interface {attrs}>');
  
  interface.attributes.then((attrs) {
    print('Render UI Panel ID: ${attrs['id']}');
  });

  interface.stream.listen((chunk) {
    print('UI Code chunk: $chunk');
  });

  // Stream conversational response
  parser.outside('<thinking>').outside('<interface {attrs}>').stream.listen((chunk) {
    print('Chat chunk: $chunk');
  });
}
```

---

## API Reference

### LlmTagParser Methods

| Method          | Returns         | Description                                                   |
| --------------- | --------------- | ------------------------------------------------------------- |
| `.within(tag)`  | `LlmTagContent` | Isolate the inner content of a tag.                           |
| `.outside(tag)` | `LlmTagContent` | Isolate the outer content (conversational text) around a tag. |

### LlmTagContent Interface

```dart
.stream      // Stream<String> - buffered, replays past chunks to late subscribers
.future      // Future<String> - resolves with the complete accumulated text
.attributes  // Future<Map<String, String>> - resolves with parsed attributes map
.attribute(name) // Stream<String?> - streams the individual attribute value
.within(tag)   // LlmTagContent - chains nested tag lookups
.outside(tag)  // LlmTagContent - chains nested sibling filters
```

---

## Robustness

Battle-tested resilience handling the realities of streaming LLM outputs:

| Category                 | What is Covered                                                                                                                                                             |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Backtracking**         | False alarm tag beginnings (like `x < thinking`) are gracefully returned to conversational text instead of being swallowed.                                                 |
| **Ambiguity**            | Handles overlapping tag prefixes (like `<think>` and `<thinking>`) using longest-match win resolution.                                                                      |
| **Self-Closing Tags**    | Automatically recognizes `<tag />` forms, closing the content stream immediately and extracting attributes.                                                                 |
| **Attribute Keys**       | Full support for namespaces, hyphens, periods, and numbers in keys (e.g., `data-id`, `xml:lang`, `ns:a.b-c_d`).                                                             |
| **Unquoted Values**      | Handles forgiving unquoted value assignments gracefully (e.g., `id=main`).                                                                                                  |
| **Escaped Quotes**       | Parses escaped quotation characters (e.g., `\"`, `\'`) inside values without data truncation.                                                                               |
| **Boolean Flags**        | Automatically identifies boolean/key-only attributes (e.g., `disabled` or `checked`) and maps them as flags.                                                                |
| **Delimiter Collisions** | Quote-aware tag boundaries prevent parsing errors when mathematical operators (like `age > 21`), nested brackets, or tag closing sequences occur inside attribute values.   |
| **Chunk Boundaries**     | Token and attribute detection remains fully invariant whether keywords and values arrive as a single chunk or are split character-by-character across streaming boundaries. |

---

## LLM Provider Setup

<details>
<summary><strong>OpenAI</strong></summary>

```dart
final response = await openai.chat.completions.create(
  model: 'gpt-4',
  messages: messages,
  stream: true,
);

final contentStream = response.map((chunk) => 
  chunk.choices.first.delta.content ?? ''
);

final parser = LlmTagParser(
  stream: contentStream,
  tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
);
```

</details>

<details>
<summary><strong>Anthropic Claude</strong></summary>

```dart
final stream = anthropic.messages.stream(
  model: 'claude-3-5-sonnet',
  messages: messages,
);

final contentStream = stream.map((event) => event.delta?.text ?? '');

final parser = LlmTagParser(
  stream: contentStream,
  tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
);
```

</details>

<details>
<summary><strong>Google Gemini</strong></summary>

```dart
final response = model.generateContentStream(prompt);
final contentStream = response.map((chunk) => chunk.text ?? '');

final parser = LlmTagParser(
  stream: contentStream,
  tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
);
```

</details>

---

## Contributing

Contributions welcome!

1. Check open issues on GitHub
2. Open an issue before making major changes
3. Run `dart test` before submitting
4. Match existing codebase code style

---

## License

MIT - see [LICENSE](LICENSE)

---

<div align="center">

**Made for Flutter developers building the next generation of AI-powered apps**

[GitHub](https://github.com/ComsIndeed/llm-stream-parsers/tree/main/packages/llm/llm_tag_parser_dart)
· [pub.dev](https://pub.dev/packages/llm_tag_parser) ·
[Issues](https://github.com/ComsIndeed/llm-stream-parsers/issues)

</div>
