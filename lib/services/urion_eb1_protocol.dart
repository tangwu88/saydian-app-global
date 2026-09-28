import 'dart:typed_data';

/// The EB1 short packet is 15 data bytes followed by an additive check byte.
/// It is not a CRC, despite the name used in parts of the supplier document.
class Eb1Frame {
  Eb1Frame._(this.bytes);

  static const length = 16;
  final Uint8List bytes;

  int get command => bytes[0];
  int operator [](int index) => bytes[index];

  static Eb1Frame request(int command, [List<int> payload = const []]) {
    if (command < 0 ||
        command > 255 ||
        payload.length > 14 ||
        payload.any((value) => value < 0 || value > 255)) {
      throw RangeError('Invalid EB1 request');
    }
    final bytes = Uint8List(length)..[0] = command;
    for (var index = 0; index < payload.length; index++) {
      bytes[index + 1] = payload[index];
    }
    bytes[15] = checksum(bytes);
    return Eb1Frame._(bytes);
  }

  static Eb1Frame? parse(List<int> raw) {
    if (raw.length != length || raw.any((value) => value < 0 || value > 255)) {
      return null;
    }
    if (checksum(raw) != raw[15]) return null;
    return Eb1Frame._(Uint8List.fromList(raw));
  }

  static int checksum(List<int> bytes) {
    if (bytes.length != length) throw RangeError('Invalid EB1 frame length');
    var sum = 0;
    for (var index = 0; index < 15; index++) {
      sum = (sum + bytes[index]) & 0xff;
    }
    return sum;
  }

  bool get isError => command >= 0x80 && command != 0xff;
  bool get isUnsupported => isError && bytes[1] == 0xee;
}

/// Notifications usually contain one frame, but neither notification
/// fragmentation nor coalescing may change the command stream's boundaries.
class Eb1FrameBuffer {
  final List<int> _pending = [];
  int rejectedFrames = 0;

  List<Eb1Frame> add(List<int> bytes) {
    _pending.addAll(bytes);
    final frames = <Eb1Frame>[];
    while (_pending.length >= Eb1Frame.length) {
      final frame = Eb1Frame.parse(_pending.sublist(0, Eb1Frame.length));
      _pending.removeRange(0, Eb1Frame.length);
      if (frame == null) {
        rejectedFrames++;
      } else {
        frames.add(frame);
      }
    }
    return frames;
  }

  void reset() => _pending.clear();
}

int eb1UnsignedLittle(Eb1Frame frame, int start, int count) {
  var value = 0;
  for (var offset = 0; offset < count; offset++) {
    value |= frame[start + offset] << (offset * 8);
  }
  return value;
}

int eb1UnsignedBig(Eb1Frame frame, int start, int count) {
  var value = 0;
  for (var offset = 0; offset < count; offset++) {
    value = (value << 8) | frame[start + offset];
  }
  return value;
}

int eb1Bcd(int byte) {
  final high = byte >> 4;
  final low = byte & 0x0f;
  if (high > 9 || low > 9) throw const FormatException('Invalid EB1 date');
  return high * 10 + low;
}

int eb1EncodeBcd(int value) {
  if (value < 0 || value > 99) throw RangeError('Invalid EB1 BCD value');
  return ((value ~/ 10) << 4) | value % 10;
}

/// One complete pair of 0x07 packets.  The date belongs to the watch, not to
/// the phone time at which this pair happened to be read.
class Eb1DailySnapshot {
  const Eb1DailySnapshot({
    required this.localDate,
    required this.daysAgo,
    required this.steps,
    required this.caloriesRaw,
    required this.standingHours,
    required this.distanceMeters,
    required this.sleepMinutes,
    required this.deepMinutes,
    required this.lightMinutes,
    required this.exerciseMinutes,
  });

  final DateTime localDate;
  final int daysAgo;
  final int steps;
  final int caloriesRaw;
  final int standingHours;
  final int distanceMeters;
  final int sleepMinutes;
  final int deepMinutes;
  final int lightMinutes;
  final int exerciseMinutes;

  static Eb1DailySnapshot parse(Eb1Frame first, Eb1Frame second) {
    if (first.command != 0x07 ||
        second.command != 0x07 ||
        first[1] != 0 ||
        second[1] != 1 ||
        first[2] != second[2] ||
        first[3] != second[3] ||
        first[4] != second[4] ||
        first[5] != second[5]) {
      throw const FormatException('Incomplete EB1 daily pair');
    }
    final year = 2000 + eb1Bcd(first[3]);
    final month = eb1Bcd(first[4]);
    final day = eb1Bcd(first[5]);
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw const FormatException('Invalid EB1 daily date');
    }
    return Eb1DailySnapshot(
      localDate: date,
      daysAgo: first[2],
      steps: eb1UnsignedBig(first, 6, 3),
      caloriesRaw: (second[14] << 16) | eb1UnsignedBig(first, 9, 2),
      standingHours: first[11],
      distanceMeters: eb1UnsignedBig(first, 12, 3),
      sleepMinutes: eb1UnsignedBig(second, 6, 2),
      deepMinutes: eb1UnsignedBig(second, 8, 2),
      lightMinutes: eb1UnsignedBig(second, 10, 2),
      exerciseMinutes: eb1UnsignedBig(second, 12, 2),
    );
  }
}

class Eb1BloodPressureSample {
  const Eb1BloodPressureSample({
    required this.rawTimestamp,
    required this.systolic,
    required this.diastolic,
    required this.pulse,
  });

  final int rawTimestamp;
  final int systolic;
  final int diastolic;
  final int pulse;

  static Eb1BloodPressureSample? parse(Eb1Frame frame) {
    if (frame.command != 0x14) {
      throw const FormatException('Not an EB1 blood pressure packet');
    }
    final timestamp = eb1UnsignedLittle(frame, 1, 4);
    if (timestamp == 0xffffffff) return null;
    final diastolic = frame[5];
    final systolic = frame[6];
    final pulse = frame[7];
    if (timestamp == 0 ||
        diastolic == 0 ||
        systolic == 0 ||
        diastolic >= systolic ||
        pulse == 0) {
      throw const FormatException('Invalid EB1 blood pressure values');
    }
    return Eb1BloodPressureSample(
      rawTimestamp: timestamp,
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse,
    );
  }
}

class Eb1IndexedDay {
  Eb1IndexedDay(this.command, this.frames);

  final int command;
  final List<Eb1Frame> frames;

  List<int> decodeHourlyOrFiveMinuteValues({required int expectedInterval}) {
    if (frames.isEmpty ||
        frames.first.command != command ||
        frames.first[1] != 0 ||
        frames.first[3] != expectedInterval) {
      throw const FormatException('Invalid EB1 indexed header');
    }
    final total = frames.first[2];
    if (total < 2 || total > 32 || frames.length != total) {
      throw const FormatException('Incomplete EB1 indexed day');
    }
    // A second five-packet oxygen layout is documented with different values.
    // Do not silently treat those min/max pairs as the hourly scalar layout.
    if (command == 0x2d && (expectedInterval != 60 || total != 4)) {
      throw const FormatException('Unverified EB1 oxygen layout');
    }
    final values = <int>[];
    for (var index = 1; index < total; index++) {
      final frame = frames[index];
      if (frame.command != command || frame[1] != index) {
        throw const FormatException('Out-of-order EB1 indexed packet');
      }
      values.addAll(frame.bytes.sublist(index == 1 ? 6 : 2, 15));
    }
    final expectedSlots = 1440 ~/ expectedInterval;
    if (values.length < expectedSlots) {
      throw const FormatException('Short EB1 indexed day');
    }
    return values.take(expectedSlots).toList(growable: false);
  }
}
