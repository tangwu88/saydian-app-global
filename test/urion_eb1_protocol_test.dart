import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/services/urion_eb1_protocol.dart';

void main() {
  test('short frame uses additive checksum, not sample annotation', () {
    final frame = Eb1Frame.request(0x16, [1]);
    expect(frame.bytes, [0x16, 1, ...List.filled(13, 0), 0x17]);
    expect(Eb1Frame.parse(frame.bytes), isNotNull);
    final wrong = [...frame.bytes]..[15] = 0x0a;
    expect(Eb1Frame.parse(wrong), isNull);
  });

  test('fragmented and joined notifications preserve 16-byte boundaries', () {
    final buffer = Eb1FrameBuffer();
    final first = Eb1Frame.request(0x03, [82]).bytes;
    final second = Eb1Frame.request(0x73, [2]).bytes;
    expect(buffer.add(first.sublist(0, 7)), isEmpty);
    expect(buffer.add([...first.sublist(7), ...second]).map((f) => f.command), [
      0x03,
      0x73,
    ]);
    final bad = [...first]..[15] = 0;
    expect(buffer.add(bad), isEmpty);
    expect(buffer.rejectedFrames, 1);
  });

  test('daily pair combines low/high calories and watch local date', () {
    final first = Eb1Frame.request(0x07, [
      0,
      0,
      0x25,
      0x01,
      0x21,
      0,
      0,
      0x59,
      0x0c,
      0x2b,
      0x03,
      0,
      0,
      0,
    ]);
    final second = Eb1Frame.request(0x07, [
      1,
      0,
      0x25,
      0x01,
      0x21,
      0x01,
      0xd5,
      0,
      0x6d,
      0x01,
      0x56,
      0,
      0x03,
      0,
    ]);
    final snapshot = Eb1DailySnapshot.parse(first, second);
    expect(snapshot.localDate, DateTime.utc(2025, 1, 21));
    expect(snapshot.steps, 89);
    expect(snapshot.sleepMinutes, 469);
    expect(snapshot.caloriesRaw, 3115);
    expect(snapshot.deepMinutes, 109);
    expect(snapshot.lightMinutes, 342);
    expect(snapshot.standingHours, 3);
  });

  test('blood pressure sentinel is not a zero-value measurement', () {
    final sentinel = Eb1Frame.request(0x14, [255, 255, 255, 255]);
    expect(Eb1BloodPressureSample.parse(sentinel), isNull);
    final sample = Eb1Frame.request(0x14, [
      0xf3,
      0xb5,
      0x8e,
      0x67,
      97,
      134,
      115,
    ]);
    expect(Eb1BloodPressureSample.parse(sample)?.systolic, 134);
    expect(Eb1BloodPressureSample.parse(sample)?.diastolic, 97);
  });

  test('five-packet oxygen layout cannot be decoded as hourly scalars', () {
    final frames = [
      Eb1Frame.request(0x2d, [0, 5, 60]),
      for (var index = 1; index < 5; index++)
        Eb1Frame.request(0x2d, [index, ...List.filled(13, 98)]),
    ];
    expect(
      () => Eb1IndexedDay(
        0x2d,
        frames,
      ).decodeHourlyOrFiveMinuteValues(expectedInterval: 60),
      throwsFormatException,
    );
  });
}
