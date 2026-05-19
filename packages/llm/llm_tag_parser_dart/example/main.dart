import 'dart:async';
import 'dart:io';
import 'package:llm_tag_parser/llm_tag_parser.dart';

void main() async {
  // Rich ANSI colors for stunning terminal output
  const reset = '\x1B[0m';
  const cyan = '\x1B[36m';
  const green = '\x1B[32m';
  const yellow = '\x1B[33m';
  const magenta = '\x1B[35m';
  const gray = '\x1B[90m';
  const bold = '\x1B[1m';

  print('$bold$cyan=== LLM Tag Parser Streaming Demo ===$reset\n');
  print('Simulating a live LLM response stream token-by-token...\n');

  // 1. Define the simulated token-by-token LLM stream
  final chunks = [
    'Hello! Let ',
    'me think about ',
    'building a UI.\n\n',
    '<thinking>\n',
    'The user wants a dashboard interface.\n',
    'I should design a clean, responsive layout.\n',
    '</thinking>',
    '\nHere is the dashboard code for you:\n\n',
    '<interface id="dashboard-widget" theme="dark">\n',
    '{\n',
    '  "type": "column",\n',
    '  "children": ["header", "chart", "footer"]\n',
    '}\n',
    '</interface>',
    '\n\nLet me know if you need anything else!',
  ];

  // Create a stream that emits chunks with a realistic delay
  final controller = StreamController<String>();
  
  // 2. Initialize LlmTagParser with declared tags
  final parser = LlmTagParser(
    stream: controller.stream,
    tags: [
      LlmTag(open: '<thinking>', close: '</thinking>'),
      LlmTag(open: '<interface {attrs}>', close: '</interface>'),
    ],
  );

  // 3. Set up listeners to demonstrate reactively isolating different blocks!

  // Listen to inner content of <thinking>
  parser.within('<thinking>').stream.listen((chunk) {
    stdout.write('$cyan$chunk$reset');
  });

  // Listen to inner content of <interface>
  parser.within('<interface {attrs}>').stream.listen((chunk) {
    stdout.write('$green$chunk$reset');
  });

  // Listen to attributes of <interface> as soon as they are parsed
  parser.within('<interface {attrs}>').attributes.then((attrs) {
    print('\n\n$bold$magenta[Parsed UI Attributes]$reset $attrs');
  });

  // Listen to conversational text (everything outside thinking and interface)
  parser.outside('<thinking>').outside('<interface {attrs}>').stream.listen((chunk) {
    stdout.write(chunk);
  });

  // 4. Start feeding chunks into the controller to simulate the LLM stream
  for (final chunk in chunks) {
    await Future.delayed(const Duration(milliseconds: 150));
    controller.add(chunk);
  }
  
  await controller.close();

  // Await the full final accumulated values of each block
  final fullThought = await parser.within('<thinking>').future;
  final fullInterface = await parser.within('<interface {attrs}>').future;

  print('\n\n$bold$gray--- Demo Summary ---$reset');
  print('$bold$cyan* Total thinking text length:$reset ${fullThought.length} chars');
  print('$bold$green* Total interface JSON length:$reset ${fullInterface.length} chars');
  print('$bold$cyan=================================$reset\n');
}
