import test from 'node:test';
import assert from 'node:assert/strict';
import {
  Eb1Frame, Eb1FrameBuffer, Eb1ResponseCollector, Eb1IndexedDay,
  eb1DailySnapshot, eb1BloodPressureSample, eb1PulseSample,
  eb1DynamicPressureSettings, eb1MatchMeasurementTimestamp,
  eb1Bcd, eb1EncodeBcd, urionAdvertMac,
} from '../entry/src/main/ets/model/UrionEb1Protocol.ts';

test('EB1 additive checksum matches the existing Android protocol vector', () => {
  const frame = Eb1Frame.request(0x16, [1]);
  assert.deepEqual(frame.bytes, [0x16, 1, ...Array(13).fill(0), 0x17]);
  assert.ok(Eb1Frame.parse(frame.bytes));
  assert.equal(Eb1Frame.parse([...frame.bytes.slice(0,15), 0x0a]), undefined);
  for (const payload of [[256], [-1], [1.5], Array(15).fill(1)]) assert.throws(() => Eb1Frame.request(3, payload));
});
test('fragmentation, coalescing and reset preserve notification boundaries', () => {
  const buffer = new Eb1FrameBuffer();
  const first = Eb1Frame.request(3, [82]).bytes;
  const second = Eb1Frame.request(0x73, [2]).bytes;
  assert.deepEqual(buffer.add(first.slice(0,7)), []);
  assert.deepEqual(buffer.add([...first.slice(7), ...second]).map(f => f.command), [3,0x73]);
  assert.deepEqual(buffer.add([...first.slice(0,15),0]), []);
  assert.equal(buffer.rejectedFrames, 1);
  buffer.add(first.slice(0,3)); buffer.reset();
  assert.equal(buffer.add(second)[0].command, 0x73);
});
test('daily pair keeps the watch date and all summary fields without accumulation', () => {
  const first = Eb1Frame.request(7, [0,0,0x25,1,0x21,0,0,0x59,0x0c,0x2b,3,0,0,0]);
  const second = Eb1Frame.request(7, [1,0,0x25,1,0x21,1,0xd5,0,0x6d,1,0x56,0,3,0]);
  const value = eb1DailySnapshot(first, second);
  assert.deepEqual(value, {localDate:'2025-01-21',daysAgo:0,steps:89,caloriesRaw:3115,standingHours:3,
    distanceMeters:0,sleepMinutes:469,deepMinutes:109,lightMinutes:342,exerciseMinutes:3});
  assert.deepEqual(eb1DailySnapshot(first,second), value);
  assert.throws(() => eb1DailySnapshot(first,first));
  const invalid = Eb1Frame.request(7,[1,0,0x25,2,0x31]);
  assert.throws(() => eb1DailySnapshot(first,invalid));
  assert.throws(() => eb1Bcd(0xfa)); assert.equal(eb1EncodeBcd(59),0x59);
});
test('blood pressure sentinel, scores and validation match Flutter vectors', () => {
  assert.equal(eb1BloodPressureSample(Eb1Frame.request(0x14,[255,255,255,255])),undefined);
  const sample=eb1BloodPressureSample(Eb1Frame.request(0x14,[0xf3,0xb5,0x8e,0x67,97,134,115]));
  assert.equal(sample.systolic,134); assert.equal(sample.diastolic,97); assert.equal(sample.pulse,115);
  assert.throws(()=>eb1BloodPressureSample(Eb1Frame.request(0x14,[1,0,0,0,130,120,65])));
  assert.equal(eb1PulseSample(Eb1Frame.request(0x34,[1,2,3,4,3,6,2])).qiBlood,6);
  assert.throws(()=>eb1PulseSample(Eb1Frame.request(0x34,[1,2,3,4,11,0,0])));
});
test('dynamic BP response is validated identically for reads and change notifications', () => {
  for(const command of [0x36,0x37]) assert.deepEqual(eb1DynamicPressureSettings(Eb1Frame.request(command,[1,8,60,90])),
    {enabled:true,startHour:8,dayIntervalMinutes:60,nightIntervalMinutes:90});
  for(const values of [[1,24,60,90],[1,8,0,90],[2,8,60,90]])
    assert.throws(()=>eb1DynamicPressureSettings(Eb1Frame.request(0x36,values)));
});
test('response collector waits for all packets, ignores identical repeats, rejects conflicts', () => {
  const collector=new Eb1ResponseCollector(0x2d);
  const header=Eb1Frame.request(0x2d,[0,4,60]);
  assert.equal(collector.add(header),undefined);
  assert.equal(collector.add(header),undefined);
  const first=Eb1Frame.request(0x2d,[1,1,2,3,4,...Array(9).fill(98)]);
  assert.equal(collector.add(first),undefined);
  assert.equal(collector.add(first),undefined);
  assert.throws(()=>collector.add(Eb1Frame.request(0x2d,[1,1,2,3,4,99])));
  assert.equal(collector.add(Eb1Frame.request(0x2d,[2,...Array(13).fill(98)])),undefined);
  const frames=collector.add(Eb1Frame.request(0x2d,[3,...Array(13).fill(98)]));
  assert.equal(frames.length,4);
  assert.deepEqual(new Eb1IndexedDay(0x2d,frames).decodeValues(60),Array(24).fill(98));
  assert.equal(collector.add(header),undefined);
  assert.throws(()=>new Eb1ResponseCollector(3,51));
});
test('five packet oxygen layout is quarantined instead of being interpreted as scalars', () => {
  const frames=[Eb1Frame.request(0x2d,[0,5,60]), ...[1,2,3,4].map(i=>Eb1Frame.request(0x2d,[i,...Array(13).fill(98)]))];
  assert.throws(()=>new Eb1IndexedDay(0x2d,frames).decodeValues(60));
});
test('BP sentinel ends short history; indexed missing packet cannot finish', () => {
  const collector=new Eb1ResponseCollector(0x14,50);
  assert.equal(collector.add(Eb1Frame.request(0x14,[1,2,3,4,80,120,65])),undefined);
  assert.equal(collector.add(Eb1Frame.request(0x14,[255,255,255,255])).length,1);
  const indexed=new Eb1ResponseCollector(0x15);
  indexed.add(Eb1Frame.request(0x15,[0,25,5]));
  assert.throws(()=>indexed.add(Eb1Frame.request(0x15,[2,65])));
});
test('BP clock is proven only inside a new measurement window in the current timezone', () => {
  const instant=new Date(2026,9,4,10,0,0).getTime();
  const localSeconds=Date.UTC(2026,9,4,10,0,0)/1000;
  assert.equal(eb1MatchMeasurementTimestamp(localSeconds,instant-1000,instant+1000)?.measuredAt,instant);
  assert.equal(eb1MatchMeasurementTimestamp(instant/1000,instant-1000,instant+1000)?.measuredAt,instant);
  assert.equal(eb1MatchMeasurementTimestamp(instant/1000-3600,instant-1000,instant+1000),undefined);
  assert.equal(eb1MatchMeasurementTimestamp(0,instant,instant+1000),undefined);
  assert.equal(eb1MatchMeasurementTimestamp(instant/1000,instant+1,instant-1),undefined);
});
test('Urion identification uses company and EB1 manufacturer bytes, never a name', () => {
  const adv=[2,1,6,11,255,0x34,0x12,0xfe,0xe7,7,0x43,0,0,0x34,0xbc];
  assert.equal(urionAdvertMac(adv),'07:43:00:00:34:BC');
  assert.equal(urionAdvertMac([8,9,...Array.from(Buffer.from('U19-ultra'))]),'');
  assert.equal(urionAdvertMac(adv.slice(0,-1)),'');
  const ring=adv.slice();ring[7]=0xff;assert.equal(urionAdvertMac(ring),'');
});
