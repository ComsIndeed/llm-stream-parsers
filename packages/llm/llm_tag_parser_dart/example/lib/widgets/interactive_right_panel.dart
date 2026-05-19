import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:llm_tag_parser/llm_tag_parser.dart';
import 'stream_accumulator_widget.dart';

class InteractiveRightPanel extends StatelessWidget {
  final LlmTagParser? parser;

  const InteractiveRightPanel({
    super.key,
    required this.parser,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeParser = parser;

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
              child: activeParser == null
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
                          stream: activeParser.outside('<thinking>').outside('<interface {attrs}>').stream,
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
                                stream: activeParser.within('<thinking>').stream,
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
                                future: activeParser.within('<interface {attrs}>').attributes,
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
                                stream: activeParser.within('<interface {attrs}>').stream,
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
      ),
    );
  }
}
