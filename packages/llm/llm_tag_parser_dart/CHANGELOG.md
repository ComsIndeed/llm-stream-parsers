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
