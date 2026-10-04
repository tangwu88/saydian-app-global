import type { HealthRecord, EcgArtifact } from './WearableContracts';

export interface GlobalHealthSource {
  platform: 'harmony'; deviceId: string; model?: string; firmware?: string;
  origin: string; measurementSource: 'wearable'; rawVersion: number;
}
export interface GlobalHealthRow {
  id: string; metric: string; observedAt: string; timezoneOffsetMinutes: number;
  values: Record<string, number>; quality: string; source: GlobalHealthSource;
  aggregation?: { kind: 'daily_summary'; localDate: string; version: 1; };
  ecgArtifact?: EcgArtifact;
}
const METRICS: Record<string, string> = { activity: 'steps', sleep: 'sleep', heart: 'heart_rate',
  pressure: 'blood_pressure', oxygen: 'blood_oxygen', temperature: 'temperature', glucose: 'blood_glucose',
  hrv: 'hrv', ecg: 'ecg', bodyComposition: 'body_composition', bloodComponents: 'blood_composition' };
const VALUES: Record<string, string> = { '步数': 'steps', '热量': 'calories', '距离': 'distance',
  '总睡眠': 'totalMinutes', '深睡': 'deepMinutes', '浅睡': 'lightMinutes', '清醒': 'awakeMinutes',
  '心率': 'heartRate', '平均心率': 'heartRate', '收缩压': 'systolic', '舒张压': 'diastolic',
  '脉率': 'pulse', '血氧': 'oxygen', '血糖': 'glucose', '体温': 'temperature', 'HRV': 'hrv',
  'QT': 'qt', 'SDNN': 'sdnn', 'RMSSD': 'rmssd' };

export function globalHealthRow(record: HealthRecord, dailySupported: boolean): GlobalHealthRow | undefined {
  const offset = record.timezoneOffsetMinutes;
  if (record.measurementState === 'interrupted') return undefined;
  if (!record.id || record.id.length > 160 || !record.deviceKey || !METRICS[record.metric] ||
    !Number.isFinite(record.timestamp) || record.timestamp <= 0 || !Number.isInteger(offset) ||
    (offset as number) < -840 || (offset as number) > 840 || !Number.isInteger(record.rawVersion) ||
    (record.rawVersion as number) < 1 || !['unknown', 'valid', 'suspect', 'invalid'].includes(record.quality ?? '') ||
    !['watch_history', 'app_measurement'].includes(record.source) ||
    record.values.some((field) => !Number.isFinite(field.value))) return undefined;
  if (record.aggregation && (!dailySupported || record.aggregation.version !== 1 ||
    record.aggregation.kind !== 'daily_summary' || !/^\d{4}-\d{2}-\d{2}$/.test(record.aggregation.localDate) ||
    !Number.isFinite(Date.parse(`${record.aggregation.localDate}T00:00:00Z`)) ||
    new Date(`${record.aggregation.localDate}T00:00:00Z`).toISOString().slice(0, 10) !== record.aggregation.localDate)) return undefined;
  const values: Record<string, number> = {};
  record.values.forEach((field) => { values[VALUES[field.name] ?? field.name] = field.value; });
  if (record.samples.length) {
    const receipt = record.ecgArtifact;
    if (record.metric !== 'ecg' || !Number.isInteger(record.sampleFrequency) || record.sampleFrequency < 50 ||
      record.sampleFrequency > 1000 || record.samples.length > 1000000 || record.samples.some((sample) => !Number.isFinite(sample)) ||
      !receipt || receipt.sampleRateHz !== record.sampleFrequency || receipt.sampleCount !== record.samples.length ||
      !/^ecg\//.test(receipt.uploadObjectKey) || receipt.uploadObjectKey.includes('..') ||
      !/^[a-f0-9]{64}$/.test(receipt.sha256) || receipt.encoding !== 'gzip_json_v1' || receipt.byteSize <= 0) return undefined;
    values['sampleFrequency'] = record.sampleFrequency;
    values['sampleCount'] = record.samples.length;
  }
  if (!Object.keys(values).length) return undefined;
  return { id: record.id, metric: METRICS[record.metric], observedAt: new Date(record.timestamp).toISOString(),
    timezoneOffsetMinutes: offset as number, values: values, quality: record.quality as string,
    source: { platform: 'harmony', deviceId: record.deviceKey, model: record.model, firmware: record.firmware,
      origin: record.source, measurementSource: 'wearable', rawVersion: record.rawVersion as number },
    aggregation: record.aggregation, ecgArtifact: record.samples.length ? record.ecgArtifact : undefined };
}

// Missing, duplicate, foreign or contradictory ACKs never mark any local row synced.
export function globalHealthAccepted(data: Object | undefined, submitted: string[]): string[] {
  if (!data || typeof data !== 'object' || Array.isArray(data) || new Set(submitted).size !== submitted.length) {
    throw new Error('Invalid health ACK');
  }
  const raw = data as Record<string, Object>;
  if (!Array.isArray(raw['acceptedIds']) || !Array.isArray(raw['rejected']) ||
    (raw['nextCursor'] != null && typeof raw['nextCursor'] !== 'string')) throw new Error('Invalid health ACK');
  const accepted: string[] = []; const rejected: string[] = [];
  for (const id of raw['acceptedIds'] as Object[]) {
    if (typeof id !== 'string' || !submitted.includes(id) || accepted.includes(id)) throw new Error('Invalid health ACK');
    accepted.push(id);
  }
  for (const item of raw['rejected'] as Object[]) {
    if (!item || typeof item !== 'object' || Array.isArray(item)) throw new Error('Invalid health ACK');
    const id = (item as Record<string, Object>)['id'];
    if (typeof id !== 'string' || !submitted.includes(id) || accepted.includes(id) || rejected.includes(id)) {
      throw new Error('Invalid health ACK');
    }
    rejected.push(id);
  }
  return accepted;
}
