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
  - [Parallel Tag Instances](#parallel-tag-instances)
  - [Chronological Node Stream](#chronological-node-stream)
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
  llm_tag_parser: ^0.2.0
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

// Convenience helpers (equivalent to the above)
final id = await parser.within('<interface {attrs}>').getAttributeFuture('id');
parser.within('<interface {attrs}>').getAttributeStream('id').listen(print);
```

### Parallel Tag Instances

When a response contains multiple occurrences of the same tag (e.g. several
parallel `<tool_use>` blocks), each occurrence is a fully isolated `TagNode`
with its own independent `stream` and `future`. Use `.instances` to route each
one as it opens:

```dart
parser.within('<tool_use>').instances.listen((tagNode) {
  // tagNode is a distinct TagNode for this specific occurrence
  tagNode.stream.listen((chunk) {
    print('Tool chunk: $chunk');
  });

  tagNode.future.then((full) {
    print('Tool complete: $full');
  });

  // Access parsed attributes directly on the TagNode
  print('Tool name: ${tagNode.attributes['name']}');
  tagNode.getAttributeFuture('name').then(print);
});
```

### Chronological Node Stream

The parser exposes a unified, chronological `nodes` stream of `LlmNode`
objects, preserving the exact timeline order of the response. This is the
low-level primitive that backs all higher-level APIs:

```dart
parser.nodes.listen((node) {
  if (node is TextNode) {
    print('Text at depths ${node.depths}: ${node.text}');
  } else if (node is TagNode) {
    print('Tag opened: ${node.tag}, attributes: ${node.attributes}');
    node.stream.listen((chunk) => print('  chunk: $chunk'));
  }
});
```

| Node Type  | Description                                                         |
| ---------- | ------------------------------------------------------------------- |
| `TextNode` | A chunk of plain text, tagged with current nesting `depths`         |
| `TagNode`  | A tag opening event, carrying `attributes`, `stream`, and `future`  |

Both node types carry a `depths` map (`Map<String, int>`) indicating how deep
inside each registered tag the content was emitted at.

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

  // Handle multiple parallel tool_use blocks via instances
  parser.within('<tool_use>').instances.listen((tagNode) {
    print('Tool opened: ${tagNode.attributes['name']}');
    tagNode.future.then((result) => print('Tool result: $result'));
  });
}
```

---

## API Reference

### LlmTagParser

| Member          | Type                  | Description                                                   |
| --------------- | --------------------- | ------------------------------------------------------------- |
| `.within(tag)`  | `LlmTagContent`       | Isolate the inner content of a tag.                           |
| `.outside(tag)` | `LlmTagContent`       | Isolate the outer content (conversational text) around a tag. |
| `.nodes`        | `Stream<LlmNode>`     | Unified chronological stream of all `TextNode`s and `TagNode`s. |

### LlmTagContent

```dart
.stream                    // Stream<String>       — buffered, replays past chunks to late subscribers
.future                    // Future<String>       — resolves with the complete accumulated text
.attributes                // Future<Map<String, String>> — resolves with parsed attributes map
.attribute(name)           // Stream<String?>      — streams the individual attribute value
.getAttributeStream(name)  // Stream<String?>      — convenience alias for .attribute(name)
.getAttributeFuture(name)  // Future<String?>      — convenience alias for awaiting .attributes[name]
.instances                 // Stream<TagNode>      — emits a TagNode for each new tag occurrence
.within(tag)               // LlmTagContent        — chains nested tag lookups
.outside(tag)              // LlmTagContent        — chains nested sibling filters
```

### LlmNode Types

```dart
// Base class
abstract class LlmNode {
  final Map<String, int> depths; // nesting depth per registered tag
}

// Plain text emitted between (or inside) tags
class TextNode extends LlmNode {
  final String text;
}

// A tag opening event
class TagNode extends LlmNode {
  final String tag;
  final Map<String, String> attributes;
  Stream<String> get stream;                        // content stream for this instance
  Future<String> get future;                        // complete content future
  Future<String?> getAttributeFuture(String name);  // attribute by name (future)
  Stream<String?> getAttributeStream(String name);  // attribute by name (stream)
}
```

---

## Robustness

Battle-tested resilience handling the realities of streaming LLM outputs:

| Category                 | What is Covered                                                                                                                                                             |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Backtracking**         | False alarm tag beginnings (like `x < thinking`) are gracefully returned to conversational text instead of being swallowed.                                                 |
| **Ambiguity**            | Handles overlapping tag prefixes (like `<think>` and `<thinking>`) using longest-match win resolution.                                                                      |
| **Self-Closing Tags**    | Automatically recognizes `<tag />` forms, closing the content stream immediately and extracting attributes.                                                                 |
| **Instance Isolation**   | Each tag occurrence (e.g. parallel `<tool_use>` blocks) is a fully isolated `TagNode` — zero content bleeding between sibling instances.                                   |
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

## Utilities

### XML Tag Utilities (`XmlTagUtilities`)

When parsing structured blocks that utilize standard XML/HTML format (including dot-notation, namespaces, and self-closing tags), you can cleanly extract the tag names or query properties:

* **`XmlTagUtilities.getTagName(String openKey)`**: A static helper that parses an XML-like tag definition (e.g., `<Material.Card {attrs}>` or `<ui:button>`) and extracts the pure tag name (`Material.Card` or `ui:button`). Returns `null` if the tag definition does not follow the `<...>` XML format.
* **`TagNode.tagName`**: A convenient getter on `TagNode` that returns the clean tag name (using `XmlTagUtilities.getTagName`) directly during streaming.

```dart
final parser = LlmTagParser(
  stream: stream,
  tags: [LlmTag(open: '<Material.Card {attrs}>', close: '</Material.Card>')],
);

parser.within('<Material.Card {attrs}>').instances.listen((instance) {
  print(instance.tagName); // Prints: "Material.Card"
});
```

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
