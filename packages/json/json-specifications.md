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
    completion (essential for UI reactivity)
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
  - Event callbacks: `.onElement()` for list items, `.onValue()` for property
    completion (essential for UI reactivity)
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
    - `@types/jest: ^29.5.12` (Jest type definitions)

### Python

**Repository**: `llm-json-stream-python`

- **API**: Object-oriented, natively leveraging Python's asynchronous data
  model.
  - `JsonStreamParser(async_iterable)` - main parser class.
  - `get_string_property(path)`, `get_number_property(path)`,
    `get_list_property(path)`, etc.
  - **Dual-behavior objects**: The returned property stream objects implement
    both `__aiter__` and `__await__`.
  - Stream-based: `async for chunk in parser.get_string_property(path):`
  - Awaitable: `complete_string = await parser.get_string_property(path)`
  - Event callbacks: `.on_element()` for list items, `.on_value()` for property
    completion (essential for UI reactivity).

- **Streaming Object Type**: `AsyncIterable[str]`
  - Native to Python 3.6+ via the `typing` and `asyncio` modules.
  - Integrates seamlessly with streaming responses from `aiohttp`, `httpx`, or
    FastAPI.

- **Testing Package**: `pytest` + `pytest-asyncio`
  - Zero-boilerplate, function-based testing using standard `assert` statements.
  - Highly optimized for AI coding agents to generate instantly.

- **Dependencies**:
  - **Production**: Zero runtime dependencies (pure Python).
  - **Development**:
    - `pytest: ^8.0.0`, `pytest-asyncio: ^0.23.0` (Testing framework)
    - `mypy` (Strict static type checking)
    - `ruff` (Extremely fast linter and formatter that replaces flake8/black)

### C#

**Repository**: `LlmJsonStream.CSharp`

- **API**: Object-oriented, designed around modern .NET async patterns.
  - `new JsonStreamParser(IAsyncEnumerable<string>)` - main parser class.
  - `GetStringProperty(path)`, `GetNumberProperty(path)`,
    `GetArrayProperty(path)`, etc.
  - **Dual-behavior objects**: The property objects implement
    `IAsyncEnumerable<string>` and expose a custom awaiter.
  - Stream-based: `await foreach (var chunk in parser.GetStringProperty(path))`
  - Awaitable: `var completeString = await parser.GetStringProperty(path)`
    (achieved by implementing `GetAwaiter()` on the object).
  - Event callbacks: `.OnElement()` for list items, `.OnValue()` for property
    completion (essential for UI reactivity).
  - Strongly typed with .NET Generics for array/object mapping.

- **Streaming Object Type**: `IAsyncEnumerable<string>`
  - Introduced in C# 8.0, this is the native, standard interface for
    asynchronous streams in the .NET ecosystem.

- **Testing Package**: `xUnit`
  - The modern standard for open-source .NET projects.
  - Excellent parallel test execution and clean separation of context.

- **Dependencies**:
  - **Production**: Zero external NuGet dependencies. Relies purely on the
    built-in `System.Text.Json` where needed.
  - **Development**:
    - `xunit`, `xunit.runner.visualstudio` (Testing framework)
    - `Microsoft.NET.Test.Sdk` (Test execution)
    - `FluentAssertions` (Highly recommended for readable, agent-friendly test
      assertions)

### Kotlin

**Repository**: `llm-json-stream-kotlin`

- **API**: Object-oriented, fully integrated with Kotlin Coroutines.
  - `JsonStreamParser(Flow<String>)` - main parser class.
  - `getStringProperty(path)`, `getNumberProperty(path)`,
    `getListProperty(path)`, etc.
  - Stream-based: Exposes a Flow via `.flow` property (e.g.,
    `parser.getStringProperty(path).flow.collect { ... }`).
  - Suspend-based: `val completeString = parser.getStringProperty(path).await()`
    (using a custom `suspend fun`).
  - Event callbacks: `.onElement()` for list items, `.onValue()` for property
    completion (essential for UI reactivity).
  - Built with structured concurrency in mind (handles cancellation gracefully
    if the parent Job is cancelled).

- **Streaming Object Type**: `Flow<String>`
  - The native reactive stream implementation from `kotlinx.coroutines`. It
    handles backpressure natively and is the standard for Kotlin asynchronous
    streams.

- **Testing Package**: `kotlin("test")` + `app.cash.turbine:turbine`
  - `kotlin("test")` maps to JUnit 5 under the hood on JVM but prepares the
    package for Kotlin Multiplatform if needed later.
  - Turbine is strictly required for real-time, chunk-by-chunk stream validation
    (step-stepping through Flows).
  - Universally understood by AI coding assistants.

- **Dependencies**:
  - **Production**: `org.jetbrains.kotlinx:kotlinx-coroutines-core` (The
    standard library extension for Coroutines/Flows).
  - **Development**:
    - `kotlin("test")` (Testing framework)
    - `org.jetbrains.kotlinx:kotlinx-coroutines-test` (Async test execution)
    - `app.cash.turbine:turbine` (Required for chunk-by-chunk flow testing)
    - `ktlint` (Standardized, zero-config Kotlin linter)
