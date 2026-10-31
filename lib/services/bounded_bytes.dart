import 'dart:async';
import 'dart:io' show gzip;
import 'dart:typed_data';

class ResourceLimitException implements Exception {
  const ResourceLimitException();
  @override
  String toString() => 'Resource exceeds its permitted size';
}

/// Limits retained bytes before copying a chunk and cancels on limit/error or
/// total deadline (including a stream that keeps producing small chunks).
Future<Uint8List> readBoundedBytes(
  Stream<List<int>> stream, {
  required int maxBytes,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final watch = Stopwatch()..start();
  final iterator = StreamIterator(stream);
  final bytes = BytesBuilder(copy: false);
  try {
    while (true) {
      final remaining = timeout - watch.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('Resource deadline');
      }
      if (!await iterator.moveNext().timeout(remaining)) break;
      final chunk = iterator.current;
      if (chunk.length > maxBytes - bytes.length) {
        throw const ResourceLimitException();
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  } finally {
    await iterator.cancel();
    watch.stop();
  }
}

/// Feed the inflater small compressed chunks so a highly compressed response
/// cannot inflate as one unbounded allocation before the output limit runs.
Future<Uint8List> inflateBoundedGzip(
  List<int> compressed, {
  required int maxBytes,
  Duration timeout = const Duration(seconds: 20),
}) {
  Stream<List<int>> chunks() async* {
    for (var offset = 0; offset < compressed.length; offset += 1024) {
      final end = offset + 1024 < compressed.length
          ? offset + 1024
          : compressed.length;
      yield compressed.sublist(offset, end);
    }
  }

  return readBoundedBytes(
    gzip.decoder.bind(chunks()),
    maxBytes: maxBytes,
    timeout: timeout,
  );
}
