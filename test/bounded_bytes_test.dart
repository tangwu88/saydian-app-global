import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/bounded_bytes.dart';

void main() {
  test('AUD-06 exact byte limit succeeds without dropping content', () async {
    final bytes = await readBoundedBytes(
      Stream.fromIterable([
        [1, 2],
        [3],
      ]),
      maxBytes: 3,
    );
    expect(bytes, [1, 2, 3]);
  });

  test('AUD-06 oversized chunk cancels upstream before retaining it', () async {
    var cancelled = false;
    final stream = StreamController<List<int>>(
      onCancel: () => cancelled = true,
    );
    final read = readBoundedBytes(stream.stream, maxBytes: 3);
    final assertion = expectLater(read, throwsA(isA<ResourceLimitException>()));
    stream.add([1, 2]);
    stream.add([3, 4]);
    await assertion;
    expect(cancelled, isTrue);
    await stream.close();
  });

  test('AUD-06 silent body times out and cancels stream', () async {
    var cancelled = false;
    final stream = StreamController<List<int>>(
      onCancel: () => cancelled = true,
    );
    await expectLater(
      readBoundedBytes(
        stream.stream,
        maxBytes: 3,
        timeout: const Duration(milliseconds: 25),
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(cancelled, isTrue);
    await stream.close();
  });

  test(
    'AUD-06 continuously trickling body cannot reset total deadline',
    () async {
      final watch = Stopwatch()..start();
      await expectLater(
        readBoundedBytes(
          Stream.periodic(const Duration(milliseconds: 5), (_) => [1]),
          maxBytes: 10000,
          timeout: const Duration(milliseconds: 35),
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    },
  );

  test('AUD-06 bounded gzip preserves samples at exact output limit', () async {
    final source = utf8.encode('[0.1,0.2,0.3]');
    expect(
      await inflateBoundedGzip(gzip.encode(source), maxBytes: source.length),
      source,
    );
  });

  test('AUD-06 small compressed fixture cannot exceed inflate limit', () async {
    final source = List<int>.filled(100000, 32);
    await expectLater(
      inflateBoundedGzip(gzip.encode(source), maxBytes: 1000),
      throwsA(isA<ResourceLimitException>()),
    );
  });

  test('AUD-06 corrupted gzip fails closed', () async {
    await expectLater(
      inflateBoundedGzip([1, 2, 3], maxBytes: 1000),
      throwsA(isA<FormatException>()),
    );
  });
}
