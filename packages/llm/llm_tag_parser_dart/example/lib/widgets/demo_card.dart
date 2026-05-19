import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:llm_tag_parser/llm_tag_parser.dart';
import '../utils/stream_text_in_chunks.dart';

class DemoCard extends StatefulWidget {
  final String title;
  final String code;
  final String rawText;
  final List<LlmTag> tags;
  final Widget Function(BuildContext context, LlmTagParser parser) builder;
  final bool startImmediately;
  final int chunkSize;
  final Duration interval;

  const DemoCard({
    super.key,
    required this.title,
    required this.code,
    required this.rawText,
    required this.tags,
    required this.builder,
    this.startImmediately = false,
    this.chunkSize = 2,
    this.interval = const Duration(milliseconds: 30),
  });

  @override
  State<DemoCard> createState() => _DemoCardState();
}

class _DemoCardState extends State<DemoCard> {
  StreamController<String>? _controller;
  LlmTagParser? _parser;
  String _streamedText = '';
  bool _isStreaming = false;
  bool _isPaused = false;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    if (widget.startImmediately) {
      _startStream();
    }
  }

  @override
  void didUpdateWidget(DemoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startImmediately && !oldWidget.startImmediately && !_isStreaming) {
      _startStream();
    }
  }

  void _startStream() async {
    if (_isStreaming) return;

    await _cleanup();

    if (!mounted) return;
    setState(() {
      _controller = StreamController<String>.broadcast();
      _parser = LlmTagParser(stream: _controller!.stream, tags: widget.tags);
      _streamedText = '';
      _isStreaming = true;
      _isPaused = false;
      _isCancelled = false;
    });

    final textStream = streamTextInChunks(
      text: widget.rawText,
      chunkSize: widget.chunkSize,
      interval: widget.interval,
      isPaused: () => _isPaused,
      isCancelled: () => _isCancelled,
    );

    await for (final chunk in textStream) {
      if (!mounted || _isCancelled) break;
      setState(() {
        _streamedText += chunk;
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

  Future<void> _cleanup() async {
    _isCancelled = true;
    _isPaused = false;
    if (_controller != null && !_controller!.isClosed) {
      try {
        await _controller!.close();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withAlpha(50),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isStreaming) ...[
                      IconButton(
                        icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                        color: Theme.of(context).colorScheme.secondary,
                        onPressed: _togglePause,
                        tooltip: _isPaused ? 'Resume' : 'Pause',
                      ),
                      IconButton(
                        icon: const Icon(Icons.stop),
                        color: Theme.of(context).colorScheme.error,
                        onPressed: _stopStream,
                        tooltip: 'Stop',
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.play_circle_filled),
                      iconSize: 32,
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: _isStreaming ? null : _startStream,
                      tooltip: 'Run this demo',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Side-by-side or stacked layout based on size
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final leftPane = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Code Highlight
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: HighlightView(
                        widget.code.trim(),
                        language: 'dart',
                        theme: isDark ? draculaTheme : githubTheme,
                        padding: const EdgeInsets.all(12),
                        textStyle: GoogleFonts.robotoMono(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Source Stream
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withAlpha(30),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SOURCE TOKEN STREAM:',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(180),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildStreamView(isDark),
                        ],
                      ),
                    ),
                  ],
                );

                final rightPane = Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Theme.of(context).colorScheme.surfaceContainerHigh
                        : Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withAlpha(50),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PARSED LIVE RESULT:',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _parser != null
                          ? widget.builder(context, _parser!)
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24.0),
                                child: Text(
                                  'Press Play to Stream and Parse',
                                  style: GoogleFonts.inter(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(120),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 11, child: leftPane),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Theme.of(context).colorScheme.primary.withAlpha(120),
                          size: 32,
                        ),
                      ),
                      Expanded(flex: 9, child: rightPane),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      leftPane,
                      const SizedBox(height: 16),
                      Center(
                        child: RotatedBox(
                          quarterTurns: 1,
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: Theme.of(context).colorScheme.primary.withAlpha(120),
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      rightPane,
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamView(bool isDark) {
    final fullText = widget.rawText;
    final len = _streamedText.length;

    return RichText(
      text: TextSpan(
        children: [
          // Streamed part
          TextSpan(
            text: _streamedText,
            style: GoogleFonts.robotoMono(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          // Remaining part (ghosted)
          if (len < fullText.length)
            TextSpan(
              text: fullText.substring(len),
              style: GoogleFonts.robotoMono(
                fontSize: 13,
                color: isDark ? Colors.grey[750] : Colors.grey[400],
              ),
            ),
        ],
      ),
    );
  }
}
