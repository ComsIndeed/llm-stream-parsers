import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/demo_card.dart';
import '../widgets/stream_accumulator_widget.dart';
import 'package:llm_tag_parser/llm_tag_parser.dart';


class ReadmeDemosPage extends StatefulWidget {
  const ReadmeDemosPage({super.key});

  @override
  State<ReadmeDemosPage> createState() => _ReadmeDemosPageState();
}

class _ReadmeDemosPageState extends State<ReadmeDemosPage> {
  int _streamKey = 0;
  bool _startOnRebuild = false;

  void _runAll() {
    setState(() {
      _startOnRebuild = true;
      _streamKey++;
    });
  }

  void _resetAll() {
    setState(() {
      _startOnRebuild = false;
      _streamKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'run_all_tag',
            onPressed: _runAll,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Run All'),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'reset_all_tag',
            onPressed: _resetAll,
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset All'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // 1. Streaming Inner Content
          DemoCard(
            key: ValueKey('demo1_$_streamKey'),
            startImmediately: _startOnRebuild,
            title: '1. Streaming Inner Content (within)',
            rawText: 'Hello reader. <thinking>Analyze query: user wants custom viz</thinking> Let\'s build it!',
            tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
            code: '''
final parser = LlmTagParser(
  stream: tokenStream,
  tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
);

// Stream the inner thinking tokens as they arrive
parser.within('<thinking>').stream.listen((chunk) {
  print('Thought chunk: \$chunk');
});
''',
            builder: (context, parser) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamAccumulatorWidget(
                    label: 'THOUGHT STREAM (.within("<thinking>").stream):',
                    stream: parser.within('<thinking>').stream,
                  ),
                ],
              );
            },
          ),

          // 2. Streaming Outer Content
          DemoCard(
            key: ValueKey('demo2_$_streamKey'),
            startImmediately: _startOnRebuild,
            title: '2. Streaming Outer Content (outside)',
            rawText: 'Conversational response... <thinking>internal logs</thinking> and more conversation!',
            tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
            code: '''
final parser = LlmTagParser(
  stream: tokenStream,
  tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
);

// Stream the main conversation, skipping internal thoughts entirely
parser.outside('<thinking>').stream.listen((chunk) {
  print('Chat chunk: \$chunk');
});
''',
            builder: (context, parser) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamAccumulatorWidget(
                    label: 'CONVERSATION STREAM (.outside("<thinking>").stream):',
                    stream: parser.outside('<thinking>').stream,
                  ),
                ],
              );
            },
          ),

          // 3. Hierarchical Nesting
          DemoCard(
            key: ValueKey('demo3_$_streamKey'),
            startImmediately: _startOnRebuild,
            title: '3. Hierarchical Nesting (Chained tags)',
            rawText: '<thinking>Wait... <tool_use>search_db(q="quantum")</tool_use> got data.</thinking> Complete.',
            tags: [
              LlmTag(open: '<thinking>', close: '</thinking>'),
              LlmTag(open: '<tool_use>', close: '</tool_use>'),
            ],
            code: '''
final parser = LlmTagParser(
  stream: tokenStream,
  tags: [
    LlmTag(open: '<thinking>', close: '</thinking>'),
    LlmTag(open: '<tool_use>', close: '</tool_use>'),
  ],
);

// Drill down inside nested levels in real-time!
parser.within('<thinking>').within('<tool_use>').stream.listen((chunk) {
  print('Nested tool chunk: \$chunk');
});
''',
            builder: (context, parser) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamAccumulatorWidget(
                    label: 'NESTED TOOL STREAM (.within("<thinking>").within("<tool_use>").stream):',
                    stream: parser.within('<thinking>').within('<tool_use>').stream,
                  ),
                  StreamAccumulatorWidget(
                    label: 'THINKING TEXT ALONE (.within("<thinking>").outside("<tool_use>").stream):',
                    stream: parser.within('<thinking>').outside('<tool_use>').stream,
                  ),
                ],
              );
            },
          ),

          // 4. Attribute Extraction
          DemoCard(
            key: ValueKey('demo4_$_streamKey'),
            startImmediately: _startOnRebuild,
            title: '4. XML-Style Attribute Parsing',
            rawText: '<interface id="panel-42" status="ready">Interface canvas loading...</interface>',
            tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
            code: '''
final parser = LlmTagParser(
  stream: tokenStream,
  tags: [LlmTag(open: '<interface {attrs}>', close: '</interface>')],
);

// Extract parsed key-value attributes Map!
final attrs = await parser.within('<interface {attrs}>').attributes;
print('ID: \${attrs["id"]}');
''',
            builder: (context, parser) {
              final content = parser.within('<interface {attrs}>');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamAccumulatorWidget(
                    label: 'INTERFACE CONTENT:',
                    stream: content.stream,
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<Map<String, String>>(
                    future: content.attributes,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.green.withAlpha(30),
                          child: Text(
                            'Parsed Attributes Map:\n${snapshot.data}',
                            style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        );
                      }
                      return const Text(
                        'Attributes loading...',
                        style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                      );
                    },
                  ),
                ],
              );
            },
          ),

          // 5. Backtracking
          DemoCard(
            key: ValueKey('demo5_$_streamKey'),
            startImmediately: _startOnRebuild,
            title: '5. Backtracking (No False Alarms)',
            rawText: 'If x < y and y > z, then... <thinking>This is a real thought</thinking>',
            tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
            code: '''
// The sequence 'x < y' looks like a tag opening but is NOT.
// The parser backtracks and restores the stream to conversational text!
final parser = LlmTagParser(
  stream: tokenStream,
  tags: [LlmTag(open: '<thinking>', close: '</thinking>')],
);
''',
            builder: (context, parser) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamAccumulatorWidget(
                    label: 'OUTSIDE CONTENT (Safely retains "x < y"):',
                    stream: parser.outside('<thinking>').stream,
                  ),
                  StreamAccumulatorWidget(
                    label: 'THINKING BLOCK STREAM:',
                    stream: parser.within('<thinking>').stream,
                  ),
                ],
              );
            },
          ),

          // 6. Ambiguity (Prefix Overlap)
          DemoCard(
            key: ValueKey('demo6_$_streamKey'),
            startImmediately: _startOnRebuild,
            title: '6. Ambiguity Prefix Resolution',
            rawText: '<think>brief</think> and <thinking>comprehensive reasoning</thinking>',
            tags: [
              LlmTag(open: '<think>', close: '</think>'),
              LlmTag(open: '<thinking>', close: '</thinking>'),
            ],
            code: '''
// '<think>' is a prefix of '<thinking>'.
// The parser resolves ambiguity using longest-prefix matching.
final parser = LlmTagParser(
  stream: tokenStream,
  tags: [
    LlmTag(open: '<think>', close: '</think>'),
    LlmTag(open: '<thinking>', close: '</thinking>'),
  ],
);
''',
            builder: (context, parser) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamAccumulatorWidget(
                    label: '<think> CONTENT:',
                    stream: parser.within('<think>').stream,
                  ),
                  StreamAccumulatorWidget(
                    label: '<thinking> CONTENT:',
                    stream: parser.within('<thinking>').stream,
                  ),
                ],
              );
            },
          ),

          // 7. Self-Closing Tags
          DemoCard(
            key: ValueKey('demo7_$_streamKey'),
            startImmediately: _startOnRebuild,
            title: '7. Self-Closing Tag Isolation',
            rawText: 'Item 1 <divider type="thin" /> Item 2',
            tags: [LlmTag(open: '<divider {attrs}>', close: '</divider>')],
            code: '''
// Self-closing tags (<divider />) trigger instant completion
// and attributes extraction without any block contents!
final parser = LlmTagParser(
  stream: tokenStream,
  tags: [LlmTag(open: '<divider {attrs}>', close: '</divider>')],
);
''',
            builder: (context, parser) {
              final divider = parser.within('<divider {attrs}>');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamAccumulatorWidget(
                    label: 'DIVIDER CONTENT STREAM (Immediately complete/empty):',
                    stream: divider.stream,
                    placeholder: 'Stream closed immediately.',
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<Map<String, String>>(
                    future: divider.attributes,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.purple.withAlpha(30),
                          child: Text(
                            'Self-Closed Attributes Map:\n${snapshot.data}',
                            style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        );
                      }
                      return const Text(
                        'Awaiting self-closed attributes...',
                        style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                      );
                    },
                  ),
                ],
              );
            },
          ),

          // 8. Malformed Attributes
          DemoCard(
            key: ValueKey('demo8_$_streamKey'),
            startImmediately: _startOnRebuild,
            title: '8. Malformed Attributes Resiliency',
            rawText: '<widget id=custom-btn border=\'none\' margin= 10px >Content</widget>',
            tags: [LlmTag(open: '<widget {attrs}>', close: '</widget>')],
            code: '''
// Gracefully extracts attributes without standard syntax.
// Handles missing quotes, single quotes, or extra spaces.
final parser = LlmTagParser(
  stream: tokenStream,
  tags: [LlmTag(open: '<widget {attrs}>', close: '</widget>')],
);
''',
            builder: (context, parser) {
              final widgetBlock = parser.within('<widget {attrs}>');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamAccumulatorWidget(
                    label: 'WIDGET CONTENT:',
                    stream: widgetBlock.stream,
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<Map<String, String>>(
                    future: widgetBlock.attributes,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.orange.withAlpha(30),
                          child: Text(
                            'Extracted Malformed Attributes:\n${snapshot.data}',
                            style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        );
                      }
                      return const Text(
                        'Awaiting malformed attributes...',
                        style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                      );
                    },
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
