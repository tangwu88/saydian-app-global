// Port of the verified Flutter EB1 parser. Urion is independent of W8/W9 SDKs.
export class Eb1Frame {
  readonly bytes: number[];
  constructor(bytes: number[]) { this.bytes = bytes.slice(); }
  get command(): number { return this.bytes[0]; }
  get isError(): boolean { return this.command >= 0x80 && this.command !== 0xff; }
  get isUnsupported(): boolean { return this.isError && this.bytes[1] === 0xee; }
  static checksum(bytes: number[]): number {
    if (bytes.length !== 16) throw new RangeError('Invalid EB1 frame length');
    return bytes.slice(0, 15).reduce((sum: number, byte: number) => (sum + byte) & 0xff, 0);
  }
  static request(command: number, payload: number[] = []): Eb1Frame {
    if (!byteValue(command) || payload.length > 14 || !payload.every(byteValue)) {
      throw new RangeError('Invalid EB1 request');
    }
    const bytes: number[] = [command, ...payload];
    while (bytes.length < 16) bytes.push(0);
    bytes[15] = Eb1Frame.checksum(bytes);
    return new Eb1Frame(bytes);
  }
  static parse(bytes: number[]): Eb1Frame | undefined {
    return bytes.length === 16 && bytes.every(byteValue) && Eb1Frame.checksum(bytes) === bytes[15]
      ? new Eb1Frame(bytes) : undefined;
  }
}
function byteValue(value: number): boolean { return Number.isInteger(value) && value >= 0 && value <= 255; }

export class Eb1FrameBuffer {
  private pending: number[] = [];
  rejectedFrames: number = 0;
  add(bytes: number[]): Eb1Frame[] {
    this.pending.push(...bytes);
    const frames: Eb1Frame[] = [];
    while (this.pending.length >= 16) {
      const frame = Eb1Frame.parse(this.pending.splice(0, 16));
      if (frame) frames.push(frame); else this.rejectedFrames++;
    }
    return frames;
  }
  reset(): void { this.pending = []; }
}
export function eb1UnsignedLittle(frame: Eb1Frame, start: number, count: number): number {
  let value = 0;
  for (let offset = 0; offset < count; offset++) value += frame.bytes[start + offset] * Math.pow(256, offset);
  return value;
}
export function eb1UnsignedBig(frame: Eb1Frame, start: number, count: number): number {
  let value = 0;
  for (let offset = 0; offset < count; offset++) value = value * 256 + frame.bytes[start + offset];
  return value;
}
export function eb1Bcd(byte: number): number {
  if (!byteValue(byte) || (byte >> 4) > 9 || (byte & 15) > 9) throw new Error('Invalid EB1 date');
  return (byte >> 4) * 10 + (byte & 15);
}
export function eb1EncodeBcd(value: number): number {
  if (!Number.isInteger(value) || value < 0 || value > 99) throw new RangeError('Invalid EB1 BCD value');
  return (Math.floor(value / 10) << 4) | value % 10;
}
export interface Eb1DailySnapshot {
  localDate: string; daysAgo: number; steps: number; caloriesRaw: number;
  standingHours: number; distanceMeters: number; sleepMinutes: number;
  deepMinutes: number; lightMinutes: number; exerciseMinutes: number;
}
export function eb1DailySnapshot(first: Eb1Frame, second: Eb1Frame): Eb1DailySnapshot {
  if (first.command !== 7 || second.command !== 7 || first.bytes[1] !== 0 || second.bytes[1] !== 1 ||
    [2, 3, 4, 5].some((index: number) => first.bytes[index] !== second.bytes[index])) {
    throw new Error('Incomplete EB1 daily pair');
  }
  const year = 2000 + eb1Bcd(first.bytes[3]);
  const month = eb1Bcd(first.bytes[4]); const day = eb1Bcd(first.bytes[5]);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) {
    throw new Error('Invalid EB1 daily date');
  }
  return { localDate: date.toISOString().slice(0, 10), daysAgo: first.bytes[2],
    steps: eb1UnsignedBig(first, 6, 3),
    caloriesRaw: second.bytes[14] * 65536 + eb1UnsignedBig(first, 9, 2),
    standingHours: first.bytes[11], distanceMeters: eb1UnsignedBig(first, 12, 3),
    sleepMinutes: eb1UnsignedBig(second, 6, 2), deepMinutes: eb1UnsignedBig(second, 8, 2),
    lightMinutes: eb1UnsignedBig(second, 10, 2), exerciseMinutes: eb1UnsignedBig(second, 12, 2) };
}
export interface Eb1BloodPressureSample {
  rawTimestamp: number; systolic: number; diastolic: number; pulse: number; fingerprint: string;
}
export function eb1BloodPressureSample(frame: Eb1Frame): Eb1BloodPressureSample | undefined {
  if (frame.command !== 0x14) throw new Error('Not an EB1 blood pressure packet');
  const timestamp = eb1UnsignedLittle(frame, 1, 4);
  if (timestamp === 0xffffffff) return undefined;
  const diastolic = frame.bytes[5]; const systolic = frame.bytes[6]; const pulse = frame.bytes[7];
  if (timestamp === 0 || diastolic === 0 || systolic === 0 || diastolic >= systolic || pulse === 0) {
    throw new Error('Invalid EB1 blood pressure values');
  }
  return { rawTimestamp: timestamp, systolic: systolic, diastolic: diastolic, pulse: pulse,
    fingerprint: `${timestamp}|${systolic}|${diastolic}|${pulse}` };
}
export interface Eb1PulseSample {
  rawTimestamp: number; bloodStasis: number; qiBlood: number; dampness: number; fingerprint: string;
}
export function eb1PulseSample(frame: Eb1Frame): Eb1PulseSample | undefined {
  if (frame.command !== 0x34) throw new Error('Not an EB1 pulse packet');
  const timestamp = eb1UnsignedLittle(frame, 1, 4);
  if (timestamp === 0xffffffff) return undefined;
  if (timestamp === 0 || frame.bytes.slice(5, 8).some((value: number) => value > 10)) {
    throw new Error('Invalid EB1 pulse values');
  }
  return { rawTimestamp: timestamp, bloodStasis: frame.bytes[5], qiBlood: frame.bytes[6],
    dampness: frame.bytes[7], fingerprint: `${timestamp}|${frame.bytes[5]}|${frame.bytes[6]}|${frame.bytes[7]}` };
}
export interface Eb1DynamicPressureSettings {
  enabled: boolean; startHour: number; dayIntervalMinutes: number; nightIntervalMinutes: number;
}
export function eb1DynamicPressureSettings(frame: Eb1Frame): Eb1DynamicPressureSettings {
  if (![0x36, 0x37].includes(frame.command) || frame.bytes[1] > 1 || frame.bytes[2] > 23 ||
    (frame.bytes[1] === 1 && (frame.bytes[3] === 0 || frame.bytes[4] === 0))) {
    throw new Error('Invalid EB1 dynamic pressure settings');
  }
  return { enabled: frame.bytes[1] === 1, startHour: frame.bytes[2],
    dayIntervalMinutes: frame.bytes[3], nightIntervalMinutes: frame.bytes[4] };
}
export class Eb1IndexedDay {
  command: number; frames: Eb1Frame[];
  constructor(command: number, frames: Eb1Frame[]) { this.command = command; this.frames = frames; }
  get hasNoData(): boolean { return this.frames.length === 1 && this.frames[0].command === this.command && this.frames[0].bytes[1] === 255; }
  get rawTimestamp(): number | undefined { return this.hasNoData || this.frames.length < 2 ? undefined : eb1UnsignedLittle(this.frames[1], 2, 4); }
  decodeValues(expectedInterval: number): number[] {
    if (this.hasNoData) return [];
    const frames = this.frames;
    if (!frames.length || frames[0].command !== this.command || frames[0].bytes[1] !== 0 ||
      frames[0].bytes[3] !== expectedInterval || ![5, 60].includes(expectedInterval)) throw new Error('Invalid EB1 indexed header');
    const total = frames[0].bytes[2];
    if (total < 2 || total > 32 || frames.length !== total) throw new Error('Incomplete EB1 indexed day');
    if (this.command === 0x2d && (expectedInterval !== 60 || total !== 4)) throw new Error('Unverified EB1 oxygen layout');
    const values: number[] = [];
    for (let index = 1; index < total; index++) {
      if (frames[index].command !== this.command || frames[index].bytes[1] !== index) throw new Error('Out-of-order EB1 indexed packet');
      values.push(...frames[index].bytes.slice(index === 1 ? 6 : 2, 15));
    }
    if (values.length < 1440 / expectedInterval) throw new Error('Short EB1 indexed day');
    return values.slice(0, 1440 / expectedInterval);
  }
}
export class Eb1ResponseCollector {
  private command: number; private count: number; private frames: Eb1Frame[] = [];
  private indexedTotal: number = 0; private complete: boolean = false;
  constructor(command: number, count: number = 1) {
    if (!Number.isInteger(count) || count < 1 || count > 50) throw new RangeError('Invalid EB1 response count');
    this.command = command; this.count = count;
  }
  add(frame: Eb1Frame): Eb1Frame[] | undefined {
    if (this.complete) return undefined;
    if (frame.command !== this.command) throw new Error('Wrong EB1 response');
    if (this.command === 0x14 || this.command === 0x34) {
      const empty = this.command === 0x14 ? !eb1BloodPressureSample(frame) : !eb1PulseSample(frame);
      if (empty) return this.finish();
      this.frames.push(frame);
      return this.frames.length === this.count ? this.finish() : undefined;
    }
    const indexed = [0x15, 0x2d].includes(this.command);
    if (indexed && !this.frames.length) {
      if (frame.bytes[1] === 255) { this.frames.push(frame); return this.finish(); }
      if (frame.bytes[1] !== 0 || frame.bytes[2] < 2 || frame.bytes[2] > 32) throw new Error('Invalid EB1 response header');
      this.indexedTotal = frame.bytes[2];
    }
    if (indexed || this.count > 1) {
      const index = frame.bytes[1];
      if (index < this.frames.length) {
        if (this.frames[index].bytes.every((byte: number, i: number) => byte === frame.bytes[i])) return undefined;
        throw new Error('Conflicting EB1 repeated packet');
      }
      if (index !== this.frames.length) throw new Error('Missing EB1 response packet');
    }
    this.frames.push(frame);
    return this.frames.length === (this.indexedTotal || this.count) ? this.finish() : undefined;
  }
  private finish(): Eb1Frame[] { this.complete = true; return this.frames.slice(); }
}
export type Eb1TimestampEncoding = 'utc' | 'localWallClock';
export interface Eb1TimestampMatch { measuredAt: number; encoding?: Eb1TimestampEncoding; }
export function eb1DecodeTimestamp(seconds: number, encoding: Eb1TimestampEncoding): number {
  const raw = new Date(seconds * 1000);
  return encoding === 'utc' ? raw.getTime() : new Date(raw.getUTCFullYear(), raw.getUTCMonth(), raw.getUTCDate(),
    raw.getUTCHours(), raw.getUTCMinutes(), raw.getUTCSeconds()).getTime();
}
// Only a new measurement window proves a clock interpretation. Old history never does.
export function eb1MatchMeasurementTimestamp(seconds: number, startedAt: number, endedAt: number): Eb1TimestampMatch | undefined {
  if (!Number.isInteger(seconds) || seconds <= 0 || endedAt < startedAt) return undefined;
  const firstSecond = Math.floor(startedAt / 1000) * 1000;
  const encodings: Eb1TimestampEncoding[] = ['utc', 'localWallClock'];
  const matches = encodings.filter((encoding: Eb1TimestampEncoding) => {
    const instant = eb1DecodeTimestamp(seconds, encoding);
    return instant >= firstSecond && instant <= endedAt;
  });
  if (!matches.length) return undefined;
  const measuredAt = eb1DecodeTimestamp(seconds, matches[0]);
  if (matches.some((encoding: Eb1TimestampEncoding) => eb1DecodeTimestamp(seconds, encoding) !== measuredAt)) return undefined;
  return { measuredAt: measuredAt, encoding: matches.length === 1 ? matches[0] : undefined };
}

export const URION_SERVICE_UUID = '6e40fff0-b5a3-f393-e0a9-e50e24dcca9e';
export const URION_WRITE_UUID = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
export const URION_NOTIFY_UUID = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
// Parse raw BLE AD structures; names are never used as protocol evidence.
export function urionAdvertMac(advertisement: number[]): string {
  let offset = 0;
  while (offset < advertisement.length) {
    const length = advertisement[offset];
    if (!length || offset + length >= advertisement.length) break;
    const type = advertisement[offset + 1];
    const data = advertisement.slice(offset + 2, offset + length + 1);
    if (type === 0xff && data.length >= 10 && data[0] === 0x34 && data[1] === 0x12 &&
      data[2] === 0xfe && data[3] === 0xe7) {
      return data.slice(4, 10).map((byte: number) => byte.toString(16).padStart(2, '0').toUpperCase()).join(':');
    }
    offset += length + 1;
  }
  return '';
}
