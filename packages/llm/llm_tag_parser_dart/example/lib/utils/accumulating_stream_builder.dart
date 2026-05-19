import 'dart:async';
import 'package:flutter/material.dart';

class AccumulatingStreamBuilder extends StatefulWidget {
  const AccumulatingStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.initialData = '',
  });

  final Stream<String>? stream;
  final String initialData;
  final Widget Function(BuildContext context, AsyncSnapshot<String> snapshot) builder;

  @override
  State<AccumulatingStreamBuilder> createState() => _AccumulatingStreamBuilderState();
}

class _AccumulatingStreamBuilderState extends State<AccumulatingStreamBuilder> {
  String _accumulated = '';
  StreamSubscription<String>? _subscription;
  bool _hasError = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _accumulated = widget.initialData;
    _subscribe();
  }

  @override
  void didUpdateWidget(AccumulatingStreamBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _subscription?.cancel();
      _accumulated = widget.initialData;
      _hasError = false;
      _error = null;
      _subscribe();
    }
  }

  void _subscribe() {
    final stream = widget.stream;
    if (stream == null) return;

    _subscription = stream.listen(
      (chunk) {
        if (mounted) {
          setState(() {
            _accumulated += chunk;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _error = error;
          });
        }
      },
      onDone: () {},
      cancelOnError: false,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncSnapshot<String> snapshot;
    if (_hasError) {
      snapshot = AsyncSnapshot<String>.withError(
        ConnectionState.active,
        _error!,
      );
    } else {
      snapshot = AsyncSnapshot<String>.withData(
        ConnectionState.active,
        _accumulated,
      );
    }
    return widget.builder(context, snapshot);
  }
}
