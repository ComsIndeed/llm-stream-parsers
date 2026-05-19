## 0.1.1

- **Feature**: Implemented prefix-matching dynamic lookahead buffer.
  - Replaced the static sliding-window lookahead with an adaptive suffix-prefix scanner.
  - Reverts lookahead latency to `0` characters for standard conversational text.
  - Automatically buffers *only* when the stream mimics a potential tag boundary, and instantly flushes buffered text if a mismatch occurs (0-latency backtracking).

## 0.1.0

- Initial version.
