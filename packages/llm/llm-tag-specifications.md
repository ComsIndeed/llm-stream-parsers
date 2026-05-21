# LLM Tag Parser Specifications

## Overview

`llm_tag_parser` is a stream-aware tag parser for LLM response streams. It
isolates tagged blocks (e.g. `<thinking>`, `<interface>`, `[thinking]`) from
surrounding text in real-time, without waiting for the full response to
complete.

**This is a STREAMING parser.** Content is emitted chunk by chunk as it arrives
— not after the stream ends.

---

## Expectations

### Core Concept

LLM providers use a variety of tag formats to delimit special blocks within
their response streams:

```
<thinking>
The user is doing a simple greeting.
</thinking>
Hi, what can I do for you?
```

The parser separates content `.within()` tags from content `.outside()` tags,
exposing each as independent streams.

---

### Syntax and Usage

#### Intended (Minimal) Usage

```dart
final parser = LlmTagParser(
  stream: llmStream,
  tags: [
    LlmTag(open: '<thinking>', close: '</thinking>'),
  ],
);

// Stream content inside the tag
parser.within('<thinking>').stream.listen((chunk) => print(chunk));

// Stream content outside the tag
parser.outside('<thinking>').stream.listen((chunk) => print(chunk));

// Await full content of a tag block
final fullThought = await parser.within('<thinking>').future;
```

#### Full API

```dart
// ─────────────────────────────────────────────
// SETUP
// ─────────────────────────────────────────────

final parser = LlmTagParser(
  stream: llmStream,
  tags: [
    // Plain tags — no attributes
    LlmTag(open: '<thinking>', close: '</thinking>'),

    // XML-style tags with attributes (default placeholder: {attrs})
    LlmTag(open: '<interface {attrs}>', close: '</interface>'),

    // Custom placeholder override (for devs who actually use {attrs} in their tags)
    LlmTag(open: '<interface|||>', close: '</interface>')
      .withAttributes('|||', format: AttributeFormat.xml),

    // Non-XML tag formats
    LlmTag(open: '[thinking]', close: '[/thinking]'),
    LlmTag(open: r'$think$', close: r'$end$'),
  ],
);

// ─────────────────────────────────────────────
// SUBSCRIBING TO CONTENT
// ─────────────────────────────────────────────

// Content inside a tag — as it streams
parser.within('<thinking>').stream.listen((chunk) => ...);

// Content outside a tag — as it streams
parser.outside('<thinking>').stream.listen((chunk) => ...);

// Await the full accumulated content of a tag block
final full = await parser.within('<thinking>').future;

// ─────────────────────────────────────────────
// DEEP NESTING
// ─────────────────────────────────────────────

// Content inside <tool_use> that is itself inside <thinking>
parser.within('<thinking>').within('<tool_use>').stream.listen((chunk) => ...);

// Content inside <tool_use> that is NOT inside <thinking>
parser.outside('<thinking>').within('<tool_use>').stream.listen((chunk) => ...);

// ─────────────────────────────────────────────
// ATTRIBUTES
// ─────────────────────────────────────────────

// Access attributes from a matched tag as a Future<Map<String, String>>
final attrs = await parser.within('<interface {attrs}>').attributes;
// Given <interface id="main-window">, returns: {"id": "main-window"}

// Access a single attribute value as a stream
parser.within('<interface {attrs}>').attribute('id').listen((value) => ...);
```

---

### Tag Registration

Tags must be declared upfront in the constructor. This is intentional:

- The parser buffers content for declared tags from the very first token
- Late subscribers still receive all buffered chunks — no content is missed
- Undeclared tags are ignored entirely and pass through as plain text to
  `.outside()` streams

This design also prevents unintended tag parsing. For example, if `<interface>`
contains raw HTML, registering only `<interface>` means inner HTML tags are
treated as plain text content — not as parseable tags.

---

### Tag Formats

Tags are declared using `LlmTag(open, close)`. The `open` string is matched as a
prefix against incoming stream content. Any format is supported:

| Format              | Example                                                      |
| ------------------- | ------------------------------------------------------------ |
| XML-style           | `LlmTag(open: '<thinking>', close: '</thinking>')`           |
| Bracket-style       | `LlmTag(open: '[thinking]', close: '[/thinking]')`           |
| Custom delimiters   | `LlmTag(open: r'$think$', close: r'$end$')`                  |
| XML with attributes | `LlmTag(open: '<interface {attrs}>', close: '</interface>')` |

---

### Attribute Parsing

For tags that carry attributes (e.g. `<interface id="main-window">`), use the
`{attrs}` placeholder in the `open` string to mark where attributes appear:

```dart
LlmTag(open: '<interface {attrs}>', close: '</interface>')
```

The parser splits on `{attrs}`, uses the left side as the tag prefix to match,
and parses whatever fills that position as attributes.

**Placeholder trimming:** Whitespace surrounding the removed placeholder is
trimmed automatically. `<interface {attrs}>` and `<interface{attrs}>` both
produce the tag prefix `<interface>`. This is documented behavior, not silent
magic — recommended examples always use the no-space form.

**Custom placeholder:** If `{attrs}` conflicts with your actual tag format,
override it via `.withAttributes()`:

```dart
LlmTag(open: '<interface$$$$>', close: '</interface>')
  .withAttributes('$$$$', format: AttributeFormat.xml)
```

**Attribute formats:**

| Format                          | Example input                   | Result                                   |
| ------------------------------- | ------------------------------- | ---------------------------------------- |
| `AttributeFormat.xml` (default) | `id="main-window" type="panel"` | `{"id": "main-window", "type": "panel"}` |
| `AttributeFormat.keyOnly`       | `main-window`                   | `{"value": "main-window"}`               |

---

### `.within()` vs `.outside()` Semantics

- **`.within('tag')`** — content enclosed by that tag, at any nesting depth
- **`.outside('tag')`** — everything NOT enclosed by that tag, at any nesting
  depth

`.outside()` is the complement of `.within()` across the full stream. For
sibling-only filtering, chain `.outside()` and `.within()` together:

```dart
// Content inside <tool_use> but NOT inside <thinking>
parser.outside('<thinking>').within('<tool_use>').stream.listen(...);
```

---

### Deep Nesting Example

```
<thinking>
  <tool_use>
    <step_1>
      ...
    </step_1>
  </tool_use>
</thinking>
```

```dart
final parser = LlmTagParser(
  stream: llmStream,
  tags: [
    LlmTag(open: '<thinking>', close: '</thinking>'),
    LlmTag(open: '<tool_use>', close: '</tool_use>'),
    LlmTag(open: '<step_1>', close: '</step_1>'),
  ],
);

// Top-level thinking content
parser.within('<thinking>').stream.listen((chunk) => ...);

// Nested: tool_use inside thinking
parser.within('<thinking>').within('<tool_use>').stream.listen((chunk) => ...);

// Nested: step_1 inside tool_use inside thinking
parser.within('<thinking>').within('<tool_use>').within('<step_1>').stream.listen((chunk) => ...);
```

---

### Attribute Routing Example (streaming_gen_ui use case)

```
Here is your UI:

<interface id="main-window">
{"namespace": "core:column", "children": [...]}
</interface>

Let me know if there is anything else I can help you with.
```

```dart
final parser = LlmTagParser(
  stream: llmStream,
  tags: [
    LlmTag(open: '<interface {attrs}>', close: '</interface>'),
  ],
);

// Render conversational text in the chat bubble
TextStream(parser.outside('<interface {attrs}>').stream)

// Route the JSON content to the correct view via the id attribute
final viewId = await parser.within('<interface {attrs}>').attribute('id').first;
final jsonStream = JsonStreamParser(parser.within('<interface {attrs}>').stream);
ui.displayJsonUi(viewId, jsonStream);
```

---

### Behavior Reference

| Scenario                         | Behavior                                                |
| -------------------------------- | ------------------------------------------------------- |
| Unregistered tag in stream       | Passed through as plain text to `.outside()` streams    |
| Late subscriber                  | Receives all buffered chunks since stream start         |
| Tag with no matching close tag   | Stream stays open until source stream ends              |
| Multiple occurrences of same tag | All occurrences emitted sequentially on the same stream |
| Nested same-name tags            | Undefined in v1 — avoid nesting a tag within itself     |
