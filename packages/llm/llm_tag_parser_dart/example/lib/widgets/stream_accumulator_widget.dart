import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StreamAccumulatorWidget extends StatefulWidget {
  final String label;
  final Stream<String>? stream;
  final String placeholder;
  final bool isCode;

  const StreamAccumulatorWidget({
    super.key,
    required this.label,
    required this.stream,
    this.placeholder = 'Waiting for tokens...',
    this.isCode = false,
  });

  @override
  State<StreamAccumulatorWidget> createState() => _StreamAccumulatorWidgetState();
}

class _StreamAccumulatorWidgetState extends State<StreamAccumulatorWidget> {
  String _accumulated = '';
  StreamSubscription<String>? _sub;
  bool _isDone = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(StreamAccumulatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _unsubscribe();
      _subscribe();
    }
  }

  void _subscribe() {
    setState(() {
      _accumulated = '';
      _isDone = false;
    });
    if (widget.stream == null) return;
    _sub = widget.stream!.listen(
      (chunk) {
        if (mounted) {
          setState(() {
            _accumulated += chunk;
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isDone = true;
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _accumulated = 'Error: $err';
            _isDone = true;
          });
        }
      },
    );
  }

  void _unsubscribe() {
    _sub?.cancel();
    _sub = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStyle = widget.isCode
        ? GoogleFonts.robotoMono(
            fontSize: 13,
            color: isDark ? Colors.cyanAccent : Colors.teal[900],
          )
        : GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black87,
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary.withAlpha(200),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.black38 : Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withAlpha(20),
              ),
            ),
            child: _accumulated.isEmpty
                ? Text(
                    widget.placeholder,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
                    ),
                  )
                : RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(text: _accumulated, style: textStyle),
                        if (!_isDone && widget.stream != null)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: _BlinkingCursor(),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 6,
        height: 14,
        margin: const EdgeInsets.only(left: 2),
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
