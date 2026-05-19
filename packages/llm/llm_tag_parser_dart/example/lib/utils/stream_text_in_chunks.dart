import 'dart:async';
import 'package:flutter/foundation.dart';

Stream<String> streamTextInChunks({
  required String text,
  required int chunkSize,
  required Duration interval,
  required ValueGetter<bool> isPaused,
  required ValueGetter<bool> isCancelled,
}) async* {
  int totalLength = text.length;
  int i = 0;
  while (i < totalLength) {
    if (isCancelled()) {
      break;
    }
    if (isPaused()) {
      await Future.delayed(const Duration(milliseconds: 50));
      continue;
    }
    
    int end = (i + chunkSize < totalLength) ? i + chunkSize : totalLength;
    yield text.substring(i, end);
    i = end;
    
    await Future.delayed(interval);
  }
}
