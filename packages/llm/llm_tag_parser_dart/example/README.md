# LLM Tag Parser Example

A basic example demonstrating how to parse and isolate structured sections (like thought blocks and interface configurations) from a live LLM text stream in real-time.

## Running the Example

Make sure you are in the root directory of the package, and run:

```bash
dart run example/main.dart
```

This will run the simulator, emitting simulated chunks token-by-token with realistic delays, printing:
- **Default text** in normal formatting
- **`<thinking>` block content** in **Cyan**
- **`<interface>` block content** in **Green**
- **Parsed attributes** in **Magenta** as soon as they are resolved
