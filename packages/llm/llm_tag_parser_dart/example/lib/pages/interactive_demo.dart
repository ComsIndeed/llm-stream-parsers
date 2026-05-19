import 'dart:async';
import 'package:flutter/material.dart';
import 'package:llm_tag_parser/llm_tag_parser.dart';
import '../utils/stream_text_in_chunks.dart';
import '../widgets/interactive_left_panel.dart';
import '../widgets/interactive_right_panel.dart';

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
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          
          final leftCard = InteractiveLeftPanel(
            chunkSize: _chunkSize,
            intervalMs: _intervalMs,
            isStreaming: _isStreaming,
            isPaused: _isPaused,
            streamedRaw: _streamedRaw,
            sampleText: _sampleText,
            onStartStream: _startStream,
            onTogglePause: _togglePause,
            onStopStream: _stopStream,
            onChunkSizeChanged: (val) {
              setState(() {
                _chunkSize = val;
              });
            },
            onIntervalChanged: (val) {
              setState(() {
                _intervalMs = val;
              });
            },
          );

          final rightCard = InteractiveRightPanel(
            parser: _parser,
          );

          if (isWide) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 11, child: leftCard),
                  const SizedBox(width: 16),
                  Expanded(flex: 9, child: rightCard),
                ],
              ),
            );
          } else {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SizedBox(
                    height: 500,
                    child: leftCard,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 800,
                    child: rightCard,
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
