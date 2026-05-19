Common:

```
<thinking>
The user is doing a simple greeting.
</thinking>
Hi what can I do for you?
```

```dart
final llmStream = ...; // stream of strings
final parser = LlmTagParser(
  stream: llmStream,
  tags: {
    '<thinking>': '</thinking>',
  }
);

parser.within('<thinking>').stream.listen((chunk) {
  print(chunk);
});
parser.outside('<thinking>').stream.listen((chunk) {
  print(chunk);
});

await parser.within('<thinking>').future;
```

Deep nesting:

```
<thinking>
  <tool_use>
    <step_1>
      
    </step_1>
  </tool_use>
</thinking>
```

```dart
final llmStream = ...; // stream of strings
final parser = LlmTagParser(
  stream: llmStream,
  tags: {
    '<thinking>': '</thinking>',
    '<tool_use>': '</tool_use>',
    '<step_1>': '</step_1>',
  }
);

parser.within('<thinking>').stream.listen((chunk) {
  print(chunk);
});
parser.outside('<thinking>').stream.listen((chunk) {
  print(chunk);
});

parser.within('<thinking>').within('<tool_use>').stream.listen((chunk) {
  print(chunk);
});
parser.outside('<thinking>').within('<tool_use>').stream.listen((chunk) {
  print(chunk);
});
```

Attributes (Flowserract use-case):

```
Here is your brutalism-inspired UI for the app:

<interface id="main-window">
{
    "title": "The Brutalist App",
    "body": {
        "name": "core:text",
        "value": "Hello World"
    }
}
</interface>

Let me know if there is anything else I can help you with.
```

```dart
final llmStream = ...; // stream of strings
final parser = LlmTagParser(
  stream: llmStream,
  tags: {
    '<interface>': '</interface>',
  }
);

// Show the text
chat.display(
    TextStream(parser.outside('<interface>').stream)
)

// Display the view in a different panel via attributes
final interfaceJsonStream = JsonStreamParser(parser.within('<interface>').stream); // (this is llm_json_stream now)
ui.displayJsonUi(interfaceJsonStream);
```
