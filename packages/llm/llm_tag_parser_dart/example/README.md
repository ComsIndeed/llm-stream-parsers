# LLM Tag Parser Example

A premium, interactive Flutter playground app demonstrating real-time token stream parsing using the `llm_tag_parser` package.

## Features

This application showcases the reactive stream parsing capabilities under realistic scenarios, split into two primary views:

### 1. Interactive Playground (Hero Demo)
* **Real-time Parsing:** Simulates an LLM token stream containing normal chat text, amber-tinted thought blocks (`<thinking>`), and custom visual interface components (`<interface>`).
* **Live Dynamic Controls:** Interactive sliders allow tuning the chunk character size (1 to 50 characters) and token dispatch speed/interval (10ms to 500ms) on the fly.
* **Stream Action Triggers:** Support for real-time pausing, resuming, and hard-stopping the token stream.
* **Side-by-Side Visualization:** Left column displays raw LLM output; right column splits the content into distinct, structured UI cards in real-time.

### 2. Readme Use Cases
* **Comprehensive Gallery:** Implements 8 key resilience test cases side-by-side (using a custom comparison view) showcasing how the parser handles real-world edge cases.
* **Demonstrated Resilience Scenarios:**
  1. Streaming Inner Content (`.within().stream`)
  2. Streaming Outer Content (`.outside().stream`)
  3. Hierarchical Nesting (chained `.within().within().stream`)
  4. XML-Style Attributes Extraction (async `.attributes` map resolution)
  5. Backtracking (false alarm tag starts like `x < y`)
  6. Ambiguity Resolution (longest prefix wins, e.g., `<think>` vs `<thinking>`)
  7. Self-Closing Tag Handling (e.g., `<divider />` closing immediately)
  8. Malformed Attributes Resiliency (unquoted, single quoted, or spaced values)
* **One-Click Execution:** Batch run all demo cards simultaneously or reset the playground state using floating controls.

---

## Running the Example

### Debugging with VS Code
A VS Code launch configuration has been added to the workspace root. 

To launch the example:
1. Open the workspace root directory in VS Code.
2. Select the **Run and Debug** tab (Ctrl+Shift+D).
3. Select the **Launch LLM Tag Parser Example** option from the dropdown menu.
4. Choose your target emulator, simulator, desktop, or web device.
5. Press **F5** to start debugging.

### Running from CLI
You can also launch the app from your terminal using the Flutter CLI:

```bash
cd packages/llm/llm_tag_parser_dart/example
flutter run
```
