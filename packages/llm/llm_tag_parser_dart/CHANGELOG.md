## 0.2.1

- **Feature**: Added `XmlTagUtilities` class and `TagNode.tagName` getter to
  cleanly parse tag names (e.g. `Material.Card` or `ui:button`) from XML-like
  tag definitions.
- **Robustness**: Added 20+ comprehensive stress tests validating escape
  characters, backtrack boundary splits, and dot-notation namespace formatting.

- **Docs**: Updated README to document the 0.2.0 API surface.
  - Added `Parallel Tag Instances` section covering `.instances` and `TagNode`
    routing.
  - Added `Chronological Node Stream` section covering the low-level `nodes`
    stream and `TextNode`/`TagNode` types.
  - Expanded `Attribute Extraction` section with `.getAttributeStream()` and
    `.getAttributeFuture()` convenience helpers.
  - Expanded `API Reference` with full `LlmTagParser.nodes`, `LlmTagContent`,
    and `LlmNode` type tables.
  - Added `Instance Isolation` row to the Robustness table.
  - Updated Quick Start version pin to `^0.2.0`.

## 0.2.0

- **Feature**: Unified Chronological Node Event Stream (`nodes`).
  - Re-architected parser around a chronological stream of `LlmNode`s
    (`TextNode` and `TagNode`), preserving the exact timeline order of the
    response.
- **Feature**: True Tag Instance Isolation.
  - Every matched tag occurrence (e.g. parallel `<interface>` blocks) is
    represented as a distinct `TagNode` instance with its own completely
    isolated `stream` and `future`.
  - Zero content bleeding, leakage, or multiplexing issues between identical
    sibling tag occurrences.
- **Feature**: Dynamic Tag Instance Routing (`instances`).
  - Exposed a `.instances` reactive stream on `LlmTagContent` to easily listen
    to and route specific tag occurrences as they open.
- **Feature**: Stack-Based Nested Tag Routing.
  - Uses an internal active instance stack to correctly route nested tags (like
    `<tool_use>` inside `<thinking>`), ensuring parent instances correctly
    contain their children's content.
- **Feature**: Standard Replay Buffering.
  - Re-implemented subscriber buffering utilizing Dart's standard
    `Stream.multi`, providing robust, native support for late and multiple
    subscribers.
- **API Extension**: Added `.getAttributeStream(name)` and
  `.getAttributeFuture(name)` convenience methods.

## 0.1.2

- **Feature**: Replaced regex attribute parser with an extremely robust
  state-machine scanner.
  - Full support for hyphens, namespaces, periods, and numbers in attribute key
    names (e.g. `data-id`, `xml:lang`, `ns:a.b-c_d`).
  - Supports unquoted attribute values (e.g. `<interface id=main>`).
  - Correctly parses escaped quotes (e.g. `\"`, `\'`) inside attribute values
    without truncating them.
  - Automatically identifies boolean / key-only attributes (e.g. `disabled` or
    `checked`) and maps them to standard flags.
  - Dynamic quote-aware tag header boundaries: handles mathematical operators
    (like `age > 21`), nested brackets, and closing tag sequences occurring
    inside attribute values seamlessly.

## 0.1.1

- **Feature**: Implemented prefix-matching dynamic lookahead buffer.
  - Replaced the static sliding-window lookahead with an adaptive suffix-prefix
    scanner.
  - Reverts lookahead latency to `0` characters for standard conversational
    text.
  - Automatically buffers _only_ when the stream mimics a potential tag
    boundary, and instantly flushes buffered text if a mismatch occurs
    (0-latency backtracking).

## 0.1.0

- Initial version.
