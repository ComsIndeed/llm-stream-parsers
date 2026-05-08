# LLM Stream Parsers

A monorepo for high-performance, incremental parsers designed for LLM streams. These parsers handle partial and malformed data in real-time, allowing you to process structured output as it arrives.

## Structure

- `packages/`: Implementation of various formats across multiple languages.
  - `json/`: Streaming JSON parsers.
  - `jsonl/`: Streaming JSONL (JSON Lines) parsers.
  - `yaml/`: Streaming YAML parsers.
  - `xml/`: Streaming XML parsers.
- `site/`: Documentation and showcase website.

## Support Matrix

| Format | Dart | TypeScript | Python | Kotlin | C# |
|--------|------|------------|--------|--------|----|
| JSON   | ✅   | 🚧         | 🚧     | 🚧     | 🚧 |
| JSONL  | 🚧   | 🚧         | -      | -      | -  |
| YAML   | 🚧   | 🚧         | -      | -      | -  |
| XML    | 🚧   | 🚧         | -      | -      | -  |

✅ = Stable | 🚧 = In Progress | - = Planned
