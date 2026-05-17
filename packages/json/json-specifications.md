# JSON Specifications for different languages

## Common format:

- The API to use for the language
  - Must feel native to the language and must be simple and intuitive
- The streaming object type for the language
  - Must be supported in every environment for the language
- The testing package to use for Test-Driven Development
  - Must just work easily without much setup, preferebly usable by AI Coding
    Agents (Github Copilot, Antigravity)
- Dependencies
  - Production dependencies: minimal and carefully selected
  - Development dependencies: for linting, type checking, and testing

## Languages

### Dart

**Repository**: `llm_json_stream_dart`

- **API**: Object-oriented with method chaining
  - `JsonStreamParser(stream)` - main parser class
  - `getStringProperty(path)`, `getNumberProperty(path)`,
    `getListProperty(path)`, etc.
  - Stream-based: `.stream` for reactive chunks, `.future` for complete values
  - Event callbacks: `.onElement()` for list items, `.onValue()` for property
    completion
  - Native to Dart with async/await and Stream patterns

- **Streaming Object Type**: `Stream<String>`
  - Part of Dart's native `dart:async` library
  - Supported everywhere Dart runs

- **Testing Package**: `test: ^1.25.6`
  - Dart's official testing framework
  - Simple and works seamlessly with Dart projects
  - 504 passing tests in the codebase

- **Dependencies**:
  - **Production**: `meta: ^1.16.0` (Dart's standard library annotations)
  - **Development**: `lints: ^6.0.0` (Dart linting rules), `test: ^1.25.6`
    (testing)

### Typescript

**Repository**: `llm-json-stream-ts`

- **API**: Object-oriented with async iterator pattern
  - `new JsonStreamParser(asyncIterable)` - main parser class
  - `getStringProperty(path)`, `getNumberProperty(path)`,
    `getArrayProperty(path)`, etc.
  - Async iterator: `for await (const chunk of parser.getStringProperty(path))`
  - Promise-based: `.promise` for complete values
  - Type-safe with TypeScript generics
  - Platform-agnostic (Node.js, Deno, Bun, browsers, Cloudflare Workers)

- **Streaming Object Type**: `AsyncIterable<string>`
  - Universal JavaScript/TypeScript interface
  - Works across all JS runtimes without dependencies
  - 100% platform-agnostic

- **Testing Package**: `bun test` (primary)
  - Built into Bun runtime
  - Jest-compatible with Node.js as fallback (`test:jest` script)
  - Simple setup, works across platforms

- **Dependencies**:
  - **Production**: Zero runtime dependencies (pure TypeScript/JavaScript)
  - **Development**:
    - `typescript: ^5.9.3` (type checking and compilation)
    - `@types/node: ^22.10.1` (Node.js type definitions)
    - `jest: ^29.7.0`, `ts-jest: ^29.2.5` (testing framework with TS support)
    - `ts-node: ^10.9.2` (TypeScript execution for development)
    - `@types/jest: ^29.5.12` (Jest type definitions) Python

### Python

### C#

### Kotlin
