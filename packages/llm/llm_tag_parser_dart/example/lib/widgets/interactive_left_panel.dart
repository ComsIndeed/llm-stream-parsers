import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:google_fonts/google_fonts.dart';

class InteractiveLeftPanel extends StatelessWidget {
  final int chunkSize;
  final int intervalMs;
  final bool isStreaming;
  final bool isPaused;
  final String streamedRaw;
  final String sampleText;
  final VoidCallback onStartStream;
  final VoidCallback onTogglePause;
  final VoidCallback onStopStream;
  final ValueChanged<int> onChunkSizeChanged;
  final ValueChanged<int> onIntervalChanged;

  const InteractiveLeftPanel({
    super.key,
    required this.chunkSize,
    required this.intervalMs,
    required this.isStreaming,
    required this.isPaused,
    required this.streamedRaw,
    required this.sampleText,
    required this.onStartStream,
    required this.onTogglePause,
    required this.onStopStream,
    required this.onChunkSizeChanged,
    required this.onIntervalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withAlpha(40),
          width: 1,
        ),
      ),
      child: Padding(
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
                        onPressed: isStreaming ? null : onStartStream,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Stream'),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.filledTonal(
                            onPressed: isStreaming ? onTogglePause : null,
                            icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                            tooltip: isPaused ? 'Resume' : 'Pause',
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: isStreaming ? onStopStream : null,
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
                          value: chunkSize.toDouble(),
                          min: 1,
                          max: 50,
                          divisions: 49,
                          label: chunkSize.toString(),
                          onChanged: (val) => onChunkSizeChanged(val.toInt()),
                        ),
                      ),
                      Text('$chunkSize chars', style: GoogleFonts.robotoMono(fontSize: 12)),
                    ],
                  ),
                  // Speed
                  Row(
                    children: [
                      const Text('Speed (Interval):'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: intervalMs.toDouble(),
                          min: 10,
                          max: 500,
                          divisions: 49,
                          label: '${intervalMs}ms',
                          onChanged: (val) => onIntervalChanged(val.toInt()),
                        ),
                      ),
                      Text('${intervalMs}ms', style: GoogleFonts.robotoMono(fontSize: 12)),
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
                          text: streamedRaw,
                          style: GoogleFonts.robotoMono(
                            color: Colors.lightGreenAccent,
                            fontSize: 13,
                          ),
                        ),
                        // Ghosted text
                        if (isStreaming && streamedRaw.length < sampleText.length)
                          TextSpan(
                            text: sampleText.substring(streamedRaw.length),
                            style: GoogleFonts.robotoMono(
                              color: Colors.grey[800],
                              fontSize: 13,
                            ),
                          ),
                        // Placeholder if not started
                        if (streamedRaw.isEmpty)
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
      ),
    );
  }
}
