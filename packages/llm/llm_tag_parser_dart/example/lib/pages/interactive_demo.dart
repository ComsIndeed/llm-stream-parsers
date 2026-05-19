import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:llm_tag_parser/llm_tag_parser.dart';
import '../utils/stream_text_in_chunks.dart';
import '../widgets/stream_accumulator_widget.dart';

class InteractiveDemoPage extends StatefulWidget {
  const InteractiveDemoPage({super.key});

  @override
  State<InteractiveDemoPage> createState() => _InteractiveDemoPageState();
}

class _InteractiveDemoPageState extends State<InteractiveDemoPage> {
  // Config
  int _chunkSize = 3;
  int _intervalMs = 40;
  
  // Streaming state
  StreamController<String>? _controller;
  LlmTagParser? _parser;
  String _streamedRaw = '';
  bool _isStreaming = false;
  bool _isPaused = false;
  bool _isCancelled = false;

  final String _sampleText = 
      "Hello! I can definitely help you visualize quantum computing.\n"
      "<thinking>\n"
      "The user wants to see an interactive dashboard of quantum qubits.\n"
      "I should explain the basic concepts of superpositions.\n"
      "I'll stream conversational explanations, and enclose the dashboard in an interactive block.\n"
      "Let's set: id=\"quantum-dashboard\", layout=\"grid\", theme=\"dark\".\n"
      "</thinking>\n"
      "Quantum computing uses qubits instead of classical bits. While a classical bit is strictly 0 or 1, a qubit can exist in a superposition of both states until it is measured. Here is a live simulation:\n\n"
      "<interface id=\"quantum-dashboard\" layout=\"grid\" theme=\"dark\">\n"
      "Qubit #1: Superposition |ψ⟩ = 1/√2(|0⟩ + |1⟩)\n"
      "Probability State |0⟩: 50.0%\n"
      "Probability State |1⟩: 50.0%\n"
      "Coherence: 99.8%\n"
      "Entanglement Pair: Qubit #2\n"
      "</interface>\n\n"
      "As you can see from the interactive widget above, the probability states are equally distributed before collapse. Let me know if you would like to run another measurement operation!";

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  Future<void> _cleanup() async {
    _isCancelled = true;
    _isPaused = false;
    if (_controller != null && !_controller!.isClosed) {
      try {
        await _controller!.close();
      } catch (_) {}
    }
  }

  void _startStream() async {
    if (_isStreaming) return;

    await _cleanup();

    setState(() {
      _controller = StreamController<String>.broadcast();
      _parser = LlmTagParser(
        stream: _controller!.stream,
        tags: [
          LlmTag(open: '<thinking>', close: '</thinking>'),
          LlmTag(open: '<interface {attrs}>', close: '</interface>'),
        ],
      );
      _streamedRaw = '';
      _isStreaming = true;
      _isPaused = false;
      _isCancelled = false;
    });

    final textStream = streamTextInChunks(
      text: _sampleText,
      chunkSize: _chunkSize,
      interval: Duration(milliseconds: _intervalMs),
      isPaused: () => _isPaused,
      isCancelled: () => _isCancelled,
    );

    await for (final chunk in textStream) {
      if (!mounted || _isCancelled) break;
      setState(() {
        _streamedRaw += chunk;
      });
      _controller?.add(chunk);
    }

    if (mounted) {
      setState(() {
        _isStreaming = false;
      });
    }

    if (_controller != null && !_controller!.isClosed) {
      await _controller!.close();
    }
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _stopStream() {
    setState(() {
      _isCancelled = true;
      _isStreaming = false;
      _isPaused = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          final leftPane = _buildLeftPanel(context, isDark);
          final rightPane = _buildRightPanel(context, isDark);

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 11, child: leftPane),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(context).colorScheme.outline.withAlpha(40),
                ),
                Expanded(flex: 9, child: rightPane),
              ],
            );
          } else {
            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: 500,
                    child: leftPane,
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outline.withAlpha(40),
                  ),
                  SizedBox(
                    height: 800,
                    child: rightPane,
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildLeftPanel(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? Colors.grey[950] : Colors.grey[50],
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LLM SOURCE CHUNKS STREAM',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),

          // Controls Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withAlpha(30),
              ),
            ),
            child: Column(
              children: [
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FilledButton.icon(
                      onPressed: _isStreaming ? null : _startStream,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Stream'),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton.filledTonal(
                          onPressed: _isStreaming ? _togglePause : null,
                          icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                          tooltip: _isPaused ? 'Resume' : 'Pause',
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _isStreaming ? _stopStream : null,
                          icon: const Icon(Icons.stop),
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                            foregroundColor: Theme.of(context).colorScheme.onError,
                          ),
                          tooltip: 'Stop Stream',
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),
                // Chunk Size
                Row(
                  children: [
                    const Text('Chunk Size:'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: _chunkSize.toDouble(),
                        min: 1,
                        max: 50,
                        divisions: 49,
                        label: _chunkSize.toString(),
                        onChanged: (val) {
                          setState(() {
                            _chunkSize = val.toInt();
                          });
                        },
                      ),
                    ),
                    Text('$_chunkSize chars', style: GoogleFonts.robotoMono(fontSize: 12)),
                  ],

                ),
                // Speed
                Row(
                  children: [
                    const Text('Speed (Interval):'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: _intervalMs.toDouble(),
                        min: 10,
                        max: 500,
                        divisions: 49,
                        label: '${_intervalMs}ms',
                        onChanged: (val) {
                          setState(() {
                            _intervalMs = val.toInt();
                          });
                        },
                      ),
                    ),
                    Text('${_intervalMs}ms', style: GoogleFonts.robotoMono(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Raw output terminal box
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: SingleChildScrollView(
                child: RichText(
                  text: TextSpan(
                    children: [
                      // Emitted text
                      TextSpan(
                        text: _streamedRaw,
                        style: GoogleFonts.robotoMono(
                          color: Colors.lightGreenAccent,
                          fontSize: 13,
                        ),
                      ),
                      // Ghosted text
                      if (_isStreaming && _streamedRaw.length < _sampleText.length)
                        TextSpan(
                          text: _sampleText.substring(_streamedRaw.length),
                          style: GoogleFonts.robotoMono(
                            color: Colors.grey[800],
                            fontSize: 13,
                          ),
                        ),
                      // Placeholder if not started
                      if (_streamedRaw.isEmpty)
                        TextSpan(
                          text: 'Press "Start Stream" to run raw LLM token generation...',
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Core Code Reference
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: HighlightView(
              '''
final parser = LlmTagParser(
  stream: llmStream,
  tags: [
    LlmTag(open: '<thinking>', close: '</thinking>'),
    LlmTag(open: '<interface {attrs}>', close: '</interface>'),
  ],
);''',
              language: 'dart',
              theme: isDark ? draculaTheme : githubTheme,
              padding: const EdgeInsets.all(12),
              textStyle: GoogleFonts.robotoMono(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel(BuildContext context, bool isDark) {
    final parser = _parser;

    return Container(
      color: isDark ? Theme.of(context).colorScheme.surfaceContainer : Colors.white,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PARSED STRUCTURAL VIEWS',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: parser == null
                ? Center(
                    child: Text(
                      'Play the raw stream on the left to see reactive parsing.',
                      style: GoogleFonts.inter(
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      // 1. Conversation Panel (outside tags)
                      StreamAccumulatorWidget(
                        label: 'CONVERSATIONAL CHAT STREAM (.outside("<thinking>").outside("<interface {attrs}>"))',
                        stream: parser.outside('<thinking>').outside('<interface {attrs}>').stream,
                        placeholder: 'Awaiting primary chat response...',
                      ),
                      const SizedBox(height: 16),

                      // 2. Thought Panel
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.blueGrey[900] : Colors.blue[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.blueGrey[750]! : Colors.blue[100]!,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.psychology, color: Colors.blue[400], size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  'LLM CHAIN OF THOUGHT (.within("<thinking>"))',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Colors.blue[300],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            StreamAccumulatorWidget(
                              label: 'THINKING STREAM:',
                              stream: parser.within('<thinking>').stream,
                              placeholder: 'Awaiting internal chain of thought...',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. UI/Interface Panel
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.purple[950]?.withAlpha(100) : Colors.purple[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.purple[800]! : Colors.purple[100]!,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.dashboard_customize, color: Colors.purple[400], size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  'INTERACTIVE CANVAS CODE (.within("<interface {attrs}>"))',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Colors.purple[300],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Attributes View
                            FutureBuilder<Map<String, String>>(
                              future: parser.within('<interface {attrs}>').attributes,
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                  final attrs = snapshot.data!;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.purple[900] : Colors.purple[100],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Parsed Attributes:\n'
                                      '• ID: ${attrs['id']}\n'
                                      '• Layout: ${attrs['layout']}\n'
                                      '• Theme: ${attrs['theme']}',
                                      style: GoogleFonts.robotoMono(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  );
                                }
                                return Text(
                                  'Awaiting interface attributes...',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.purple[300],
                                  ),
                                );
                              },
                            ),
                            StreamAccumulatorWidget(
                              label: 'CANVAS STREAM:',
                              stream: parser.within('<interface {attrs}>').stream,
                              placeholder: 'Awaiting interface definition text...',
                              isCode: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
