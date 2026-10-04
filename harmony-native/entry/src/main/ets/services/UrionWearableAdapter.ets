import { BatteryState, HealthRecord, HealthValue, WearableDevice, WearableSnapshot, WearableMetricKey,
  emptyWearableSnapshot, emptyBattery } from '../model/WearableContracts';
import { Eb1Frame, Eb1IndexedDay, Eb1BloodPressureSample, Eb1DynamicPressureSettings, Eb1TimestampEncoding, Eb1PulseSample,
  eb1BloodPressureSample, eb1DailySnapshot, eb1PulseSample, eb1DynamicPressureSettings,
  eb1DecodeTimestamp, eb1MatchMeasurementTimestamp, eb1EncodeBcd } from '../model/UrionEb1Protocol';
import { UrionGattTransport } from './UrionGattTransport';
import { recordUuid } from './NativeDataIntegrity';

export class UrionWearableAdapter {
  private transport: UrionGattTransport;
  private snapshot: WearableSnapshot = emptyWearableSnapshot();
  private generation: number = 0;
  private noticeAt: number = 0;
  private timer: number = -1;
  private syncRunning: Promise<HealthRecord[]> | undefined = undefined;
  private knownPressure: Set<string> = new Set();
  private timeEncoding: Eb1TimestampEncoding | undefined = undefined;
  private checkedAt: number = 0;
  private startedAt: number = 0;
  private measurementPoll: number = -1;
  private measurementMetric: WearableMetricKey | undefined = undefined;
  private baselineValues: number[] = [];
  private records: Map<string, HealthRecord> = new Map();
  private dynamicPressure: Eb1DynamicPressureSettings | undefined = undefined;
  private onRecords: (records: HealthRecord[]) => void;
  constructor(onRecords: (records: HealthRecord[]) => void, onDisconnected: () => void) {
    this.onRecords = onRecords;
    this.transport = new UrionGattTransport((frame: Eb1Frame) => this.onFrame(frame), (): void => {
      this.retire(); onDisconnected();
    });
  }
  isReady(): boolean { return this.transport.isReady(); }
  measurementStartedAt(): number {
    return this.startedAt ? this.startedAt - (this.measurementMetric === 'heart' ? 300000 : this.measurementMetric === 'oxygen' ? 3600000 : 0) : Number.MAX_SAFE_INTEGER;
  }
  async startMeasurement(metric: WearableMetricKey): Promise<void> {
    if (this.startedAt || !['pressure', 'heart', 'oxygen'].includes(metric)) throw new Error('当前项目仅支持读取历史');
    const generation = this.generation;
    if (metric === 'pressure') (await this.pressure()).forEach((sample: Eb1BloodPressureSample) => this.knownPressure.add(sample.fingerprint));
    else this.baselineValues = (await this.indexed(metric)).decodeValues(metric === 'heart' ? 5 : 60);
    this.assertCurrent(generation); this.startedAt = Date.now(); this.measurementMetric = metric;
    try { await this.transport.exchange(metric === 'pressure' ? 0x32 : metric === 'heart' ? 0x38 : 0x39); }
    catch (error) { this.finishMeasurement(); throw error as Error; }
    this.measurementPoll = setInterval(() => {
      if (generation !== this.generation) return;
      if (Date.now() - this.startedAt > 180000) { this.finishMeasurement(); this.onRecords([]); return; }
      this.synchronize().then((records: HealthRecord[]) => {
        if (generation === this.generation) this.onRecords(records);
      }).catch(() => {});
    }, 3000);
  }
  finishMeasurement(): void {
    if (this.measurementPoll !== -1) clearInterval(this.measurementPoll);
    this.measurementPoll = -1; this.startedAt = 0; this.measurementMetric = undefined; this.baselineValues = [];
  }
  seedRecords(records: HealthRecord[]): void {
    records.filter((record: HealthRecord) => record.deviceKey === this.snapshot.deviceKey)
      .forEach((record: HealthRecord) => this.records.set(record.id, record));
  }
  currentSnapshot(): WearableSnapshot {
    const copy = JSON.parse(JSON.stringify(this.snapshot)) as WearableSnapshot;
    copy.records = Array.from(this.records.values()); return copy;
  }
  async connect(device: WearableDevice): Promise<WearableSnapshot> {
    this.disconnect();
    const generation = this.generation;
    const battery = await this.transport.connect(device.transportId);
    this.assertCurrent(generation);
    this.snapshot = emptyWearableSnapshot();
    this.snapshot.provider = 'Urion'; this.snapshot.deviceKey = device.key;
    this.snapshot.deviceName = device.name; this.snapshot.model = device.name;
    this.snapshot.mac = device.mac; this.snapshot.battery = this.battery(battery);
    this.snapshot.firmware = await this.transport.firmware();
    this.assertCurrent(generation);
    await this.syncTime();
    await this.probeCapabilities();
    this.assertCurrent(generation);
    this.snapshot.connected = true;
    return this.currentSnapshot();
  }
  async refreshBattery(): Promise<BatteryState> {
    const generation = this.generation;
    const frame = (await this.transport.exchange(3))[0];
    this.assertCurrent(generation);
    this.snapshot.battery = this.battery(frame.bytes[1]);
    return this.snapshot.battery;
  }
  async syncTime(): Promise<void> {
    const now = new Date();
    await this.transport.exchange(1, [eb1EncodeBcd(now.getFullYear() % 100), eb1EncodeBcd(now.getMonth() + 1),
      eb1EncodeBcd(now.getDate()), eb1EncodeBcd(now.getHours()), eb1EncodeBcd(now.getMinutes()), eb1EncodeBcd(now.getSeconds()), 1]);
  }
  private async probeCapabilities(): Promise<void> {
    const caps = this.snapshot.capabilities;
    await this.probe(async (): Promise<void> => {
      const samples = await this.pressure(1); samples.forEach((sample: Eb1BloodPressureSample) => this.knownPressure.add(sample.fingerprint));
      this.checkedAt = Date.now(); caps.pressure = true;
    });
    await this.probe(async (): Promise<void> => {
      const frames = await this.transport.exchange(7, [0], 2); eb1DailySnapshot(frames[0], frames[1]);
      caps.activity = true; caps.sleep = true;
    });
    for (const metric of ['heart', 'oxygen'] as WearableMetricKey[]) {
      await this.probe(async (): Promise<void> => {
        const day = await this.indexed(metric);
        day.decodeValues(metric === 'heart' ? 5 : 60);
        if (metric === 'heart') caps.heart = true; else caps.oxygen = true;
      });
    }
    await this.probe(async (): Promise<void> => {
      const frames = await this.transport.exchange(0x34, [0, 0, 0, 0, 0, 1]);
      if (frames.length) eb1PulseSample(frames[0]); caps.healthAssessment = true;
    });
    await this.probe(async (): Promise<void> => {
      this.dynamicPressure = eb1DynamicPressureSettings((await this.transport.exchange(0x36))[0]);
      caps.healthMonitoring = true;
    });
    // Find has no passive capability query. It opens only after an actual successful command response.
  }
  private async probe(operation: () => Promise<void>): Promise<void> {
    try { await operation(); }
    catch (error) {
      if (!this.isReady()) throw error as Error;
      // Explicit unsupported/undecodable responses withdraw just that capability.
    }
  }
  async find(): Promise<void> {
    await this.transport.exchange(0x50, [0x55, 0xaa]); this.snapshot.capabilities.findDevice = true;
  }
  async dynamicSettings(): Promise<Eb1DynamicPressureSettings> {
    this.dynamicPressure = eb1DynamicPressureSettings((await this.transport.exchange(0x36))[0]);
    return this.dynamicPressure;
  }
  async pulse(): Promise<Eb1PulseSample | undefined> {
    const generation = this.generation; const frames = await this.transport.exchange(0x34, [0, 0, 0, 0, 0, 1]);
    this.assertCurrent(generation); return frames.length ? eb1PulseSample(frames[0]) : undefined;
  }
  async startPulse(isCurrent: () => boolean = () => true): Promise<Eb1PulseSample> {
    const generation = this.generation; const previous = await this.pulse(); const startedAt = Date.now();
    if (!isCurrent()) throw new Error('Read cancelled');
    await this.transport.exchange(0x3a);
    while (Date.now() - startedAt < 180000) {
      await new Promise<void>((resolve) => setTimeout(resolve, 3000)); this.assertCurrent(generation);
      if (!isCurrent()) throw new Error('Read cancelled');
      const sample = await this.pulse();
      if (sample && sample.fingerprint !== previous?.fingerprint && eb1MatchMeasurementTimestamp(sample.rawTimestamp, startedAt, Date.now())) return sample;
    }
    throw new Error('未收到有效测量结果');
  }
  async saveDynamicSettings(settings: Eb1DynamicPressureSettings): Promise<void> {
    if (!Number.isInteger(settings.startHour) || settings.startHour < 0 || settings.startHour > 23 ||
      !Number.isInteger(settings.dayIntervalMinutes) || settings.dayIntervalMinutes < 1 || settings.dayIntervalMinutes > 255 ||
      !Number.isInteger(settings.nightIntervalMinutes) || settings.nightIntervalMinutes < 1 || settings.nightIntervalMinutes > 255) throw new Error('Invalid pressure settings');
    await this.transport.exchange(0x35, [settings.enabled ? 1 : 0, settings.startHour, settings.dayIntervalMinutes, settings.nightIntervalMinutes]);
    const saved = await this.dynamicSettings();
    if (JSON.stringify(saved) !== JSON.stringify(settings)) throw new Error('Pressure settings not confirmed');
  }
  synchronize(): Promise<HealthRecord[]> {
    if (this.syncRunning) return this.syncRunning;
    const running = this.readHealth();
    this.syncRunning = running;
    running.finally(() => { if (this.syncRunning === running) this.syncRunning = undefined; }).catch(() => {});
    return running;
  }
  private async readHealth(): Promise<HealthRecord[]> {
    const generation = this.generation; const result: HealthRecord[] = []; const now = Date.now();
    const caps = this.snapshot.capabilities;
    if (caps.activity || caps.sleep) {
      const frames = await this.transport.exchange(7, [0], 2);
      const day = eb1DailySnapshot(frames[0], frames[1]);
      const today = new Date(now);
      const todayDate = Date.UTC(today.getFullYear(), today.getMonth(), today.getDate());
      if (day.daysAgo !== 0 || Math.abs(todayDate - Date.parse(`${day.localDate}T00:00:00Z`)) > 86400000 ||
        Math.max(day.sleepMinutes, day.deepMinutes, day.lightMinutes) > 1440) throw new Error('Unverified Urion daily data');
      if (caps.activity) result.push(await this.makeRecord('activity', now, [
        { name: '步数', value: day.steps, unit: '步' }, { name: 'caloriesRaw', value: day.caloriesRaw, unit: 'raw' },
        { name: '距离', value: day.distanceMeters / 1000, unit: 'km' }], day.localDate));
      if (caps.sleep) result.push(await this.makeRecord('sleep', now, [
        { name: '总睡眠', value: day.sleepMinutes, unit: '分钟' }, { name: '深睡', value: day.deepMinutes, unit: '分钟' },
        { name: '浅睡', value: day.lightMinutes, unit: '分钟' }], day.localDate));
    }
    for (const metric of ['heart', 'oxygen'] as WearableMetricKey[]) {
      if (!(metric === 'heart' ? caps.heart : caps.oxygen)) continue;
      const history = await this.indexed(metric); const values = history.decodeValues(metric === 'heart' ? 5 : 60);
      if (history.hasNoData) continue;
      const rawTimestamp = history.rawTimestamp;
      const requestedDate = new Date(now).toDateString();
      if (!rawTimestamp || !(['utc', 'localWallClock'] as Eb1TimestampEncoding[]).some((encoding: Eb1TimestampEncoding) =>
        new Date(eb1DecodeTimestamp(rawTimestamp, encoding)).toDateString() === requestedDate)) throw new Error('Unverified Urion indexed date');
      // Indexed header time is not used as a substitute for a validated local day.
      const today = new Date(now); const interval = metric === 'heart' ? 5 : 60;
      for (let index = 0; index < values.length; index++) {
        const value = values[index];
        if (metric === 'heart' ? value < 20 || value > 300 : value < 2 || value > 100) continue;
        const timestamp = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 0, index * interval).getTime();
        if (timestamp > now) continue;
        // A manual result requires a changed slot in the current measurement window.
        if (this.measurementMetric === metric && (this.baselineValues[index] === value || timestamp < this.startedAt - interval * 60000)) continue;
        result.push(await this.makeRecord(metric, timestamp, [{ name: metric === 'heart' ? '心率' : '血氧', value: value, unit: metric === 'heart' ? 'BPM' : '%' }]));
      }
    }
    if (caps.pressure) {
      const samples = await this.pressure(); const unseen = samples.filter((sample: Eb1BloodPressureSample) => !this.knownPressure.has(sample.fingerprint));
      const notice = this.noticeAt;
      const windowStart = this.measurementMetric === 'pressure' ? this.startedAt : notice && now - notice <= 300000 ? notice - 300000 : 0;
      const proofs = windowStart ? unseen.map((sample: Eb1BloodPressureSample) =>
        eb1MatchMeasurementTimestamp(sample.rawTimestamp, windowStart, notice || now)) : [];
      const proofCount = proofs.filter((proof) => proof !== undefined).length;
      for (let index = 0; index < unseen.length; index++) {
        const sample = unseen[index]; const proof = proofCount === 1 ? proofs[index] : undefined;
        let timestamp = 0;
        if (proof) { timestamp = proof.measuredAt; this.timeEncoding = this.timeEncoding ?? proof.encoding; }
        else if (this.timeEncoding && this.checkedAt) {
          const instant = eb1DecodeTimestamp(sample.rawTimestamp, this.timeEncoding);
          if (instant >= this.checkedAt - 120000 && instant <= now) timestamp = instant;
        }
        if (!timestamp) continue;
        result.push(await this.makeRecord('pressure', timestamp, [
          { name: '收缩压', value: sample.systolic, unit: 'mmHg' }, { name: '舒张压', value: sample.diastolic, unit: 'mmHg' },
          { name: '脉率', value: sample.pulse, unit: 'BPM' }], '', sample.fingerprint));
      }
      samples.forEach((sample: Eb1BloodPressureSample) => this.knownPressure.add(sample.fingerprint));
      this.checkedAt = now; this.noticeAt = 0;
    }
    this.assertCurrent(generation);
    result.forEach((record: HealthRecord) => this.records.set(record.id, record));
    this.snapshot.syncedAt = now;
    return result;
  }
  private async makeRecord(metric: WearableMetricKey, timestamp: number, values: HealthValue[], localDate: string = '', fingerprint: string = ''): Promise<HealthRecord> {
    const content = localDate ? `${localDate}|${metric}|${JSON.stringify(values)}` : `${metric}|${fingerprint || timestamp}|${JSON.stringify(values)}`;
    const id = await recordUuid(`${this.snapshot.deviceKey}|${content}`);
    const previous = this.records.get(id);
    if (previous) return previous;
    return { id: id, deviceKey: this.snapshot.deviceKey, metric: metric, timestamp: timestamp, source: 'watch_history',
      values: values, samples: [], sampleFrequency: 0, quality: 'unknown', rawVersion: 1,
      model: this.snapshot.model, firmware: this.snapshot.firmware, timezoneOffsetMinutes: -new Date(timestamp).getTimezoneOffset(),
      aggregation: localDate ? { kind: 'daily_summary', localDate: localDate, version: 1 } : undefined };
  }
  private async indexed(metric: WearableMetricKey): Promise<Eb1IndexedDay> {
    const today = new Date(); const seconds = Math.floor(new Date(today.getFullYear(), today.getMonth(), today.getDate()).getTime() / 1000);
    const command = metric === 'heart' ? 0x15 : 0x2d;
    return new Eb1IndexedDay(command, await this.transport.exchange(command, [0, 1, 2, 3].map((index: number) => Math.floor(seconds / Math.pow(256, index)) & 255)));
  }
  private async pressure(count: number = 50): Promise<Eb1BloodPressureSample[]> {
    const frames = await this.transport.exchange(0x14, [0, 0, 0, 0, 0, count], count);
    const result: Eb1BloodPressureSample[] = [];
    frames.forEach((frame: Eb1Frame) => { const sample = eb1BloodPressureSample(frame); if (sample) result.push(sample); });
    return result;
  }
  private onFrame(frame: Eb1Frame): void {
    if (!this.isReady() || !this.snapshot.connected) return;
    if (frame.command === 0x37) {
      try { this.dynamicPressure = eb1DynamicPressureSettings(frame); } catch {}
      return;
    }
    if (frame.command !== 0x33 && frame.command !== 0x73) return;
    if (frame.command === 0x33 || frame.bytes[1] === 2) this.noticeAt = Date.now();
    if (frame.command === 0x73 && frame.bytes[1] === 0x0c) { this.refreshBattery().catch(() => {}); return; }
    if (this.timer !== -1) return;
    const generation = this.generation;
    this.timer = setTimeout(() => {
      this.timer = -1;
      if (generation !== this.generation) return;
      this.synchronize().then((records: HealthRecord[]) => {
        if (generation === this.generation) this.onRecords(records);
      }).catch(() => {});
    }, 500);
  }
  private battery(level: number): BatteryState {
    if (!Number.isInteger(level) || level < 0 || level > 100) throw new Error('Invalid Urion battery');
    const battery = emptyBattery();
    battery.available = true; battery.hasPercentage = true; battery.level = level;
    battery.chargingState = 'unknown'; battery.lowBattery = level <= 15; battery.updatedAt = Date.now();
    return battery;
  }
  private assertCurrent(generation: number): void {
    if (generation !== this.generation || !this.isReady()) throw new Error('Urion connection changed');
  }
  private retire(): void {
    this.finishMeasurement();
    ++this.generation;
    if (this.timer !== -1) clearTimeout(this.timer);
    this.timer = -1; this.snapshot = emptyWearableSnapshot(); this.noticeAt = 0;
    this.records.clear(); this.knownPressure.clear(); this.timeEncoding = undefined; this.checkedAt = 0;
  }
  disconnect(): void { this.transport.disconnect(false); this.retire(); }
}
