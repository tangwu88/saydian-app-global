import { ApiError } from './Contracts';
import type { Article } from './Contracts';
import type { ArticleCategory } from './AccountPageContracts';
import type { HealthRecord, HealthValue, WearableMetricKey } from './WearableContracts';

export interface GlobalCareMember { id: string; name: string; direction: string; status: string; metrics: string[]; }
export interface GlobalCareOverview { metrics: string[]; records: HealthRecord[]; }
export interface GlobalCareWrite { accepted?: boolean; metrics?: string[]; }
export const GLOBAL_METRIC_TITLES: Record<string, string> = { heart_rate: '心率', blood_pressure: '血压', blood_oxygen: '血氧', sleep: '睡眠', steps: '步数',
  distance: '距离', calories: '热量', hrv: 'HRV', ecg: '心电', temperature: '体温', blood_glucose: '血糖', body_composition: '身体成分', blood_composition: '血液成分' };
export const GLOBAL_VIEW_METRICS: Record<string, WearableMetricKey> = {
  heart_rate: 'heart', blood_pressure: 'pressure', blood_oxygen: 'oxygen', sleep: 'sleep', steps: 'activity', distance: 'activity', calories: 'activity',
  hrv: 'hrv', ecg: 'ecg', temperature: 'temperature', blood_glucose: 'glucose',
  body_composition: 'bodyComposition', blood_composition: 'bloodComponents'
};
export const GLOBAL_FIELD_LABELS: Record<string, string> = {
  bpm: '心率', heartRate: '心率', oxygen: '血氧', systolic: '收缩压', diastolic: '舒张压', pulse: '脉率', percent: '血氧',
  steps: '步数', totalMinutes: '总睡眠', deepMinutes: '深睡', lightMinutes: '浅睡', awakeMinutes: '清醒',
  totalHours: '总睡眠', deepHours: '深睡', lightHours: '浅睡', remHours: '快速眼动', remMinutes: '快速眼动',
  celsius: '体温', temperature: '体温', glucose: '血糖', hrv: 'HRV', distance: '距离', calories: '热量', mmolL: '血糖', sdnn: 'SDNN', rmssd: 'RMSSD'
};
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function globalViewId(id: string): string {
  if (!uuidPattern.test(id)) throw new ApiError('记录暂不可用');
  return id;
}
export function viewObject(data: Object | undefined): Record<string, Object> {
  if (!data || typeof data !== 'object' || Array.isArray(data)) throw new ApiError('加载失败，重试');
  return data as Record<string, Object>;
}
export function viewList(data: Object | undefined): Record<string, Object>[] {
  const list = Array.isArray(data) ? data : viewObject(data)['items'];
  if (!Array.isArray(list)) throw new ApiError('加载失败，重试');
  return list.map(viewObject);
}
export function globalCategories(data: Object | undefined): ArticleCategory[] {
  return viewList(data).map(row => ({ id: globalViewId(String(row['id'])), title: String(row['name'] ?? row['title'] ?? '').slice(0, 80) }));
}
export function globalArticles(data: Object | undefined): Article[] {
  return viewList(data).map(row => ({ id: globalViewId(String(row['id'])), title: String(row['title'] ?? '').slice(0, 240) }));
}
export function globalArticle(data: Object | undefined): Article {
  const row = viewObject(data);
  return { id: globalViewId(String(row['id'])), title: String(row['title'] ?? ''), content: String(row['contentHtml'] ?? '') };
}
export function globalCareMembers(data: Object | undefined): GlobalCareMember[] {
  return viewList(data).map(row => {
    const direction = String(row['direction']); const person = viewObject(row[direction === 'sent' ? 'recipient' : 'inviter']);
    return { id: globalViewId(String(row['id'])), direction, status: String(row['status']),
      name: String(person['nickname'] || '成员'), metrics: Array.isArray(row['metrics']) ? row['metrics'].filter(x => typeof x === 'string') as string[] : [] };
  });
}
export function globalViewRecords(data: Object | undefined, scope: string): HealthRecord[] {
  return viewList(data).map(row => {
    const metric = GLOBAL_VIEW_METRICS[String(row['metric'])]; const timestamp = Date.parse(String(row['observedAt']));
    const id = String(row['id']);
    if (!metric || !id || id.length > 160 || !Number.isFinite(timestamp)) throw new ApiError('记录暂不可用');
    const rawValues = viewObject(row['values']); const values: HealthValue[] = [];
    Object.keys(rawValues).forEach(name => {
      const value = rawValues[name]; if (typeof value === 'number' && Number.isFinite(value)) {
        values.push({ name: name === 'value' ? GLOBAL_METRIC_TITLES[String(row['metric'])] : GLOBAL_FIELD_LABELS[name] ?? name, value, unit: ['systolic', 'diastolic'].includes(name) ? 'mmHg' :
          ['bpm', 'heartRate', 'pulse'].includes(name) ? 'BPM' : ['percent', 'oxygen'].includes(name) ? '%' : name.endsWith('Minutes') ? '分钟' : name.endsWith('Hours') ? 'h' : name === 'steps' ? '步' :
          ['temperature', 'celsius'].includes(name) ? '°C' : ['glucose', 'mmolL'].includes(name) ? 'mmol/L' : ['hrv', 'sdnn', 'rmssd'].includes(name) ? 'ms' : name === 'distance' ? 'km' : name === 'calories' ? 'kcal' : String(row['unit'] ?? '') });
      }
    });
    const artifact = row['ecgArtifact'] ? viewObject(row['ecgArtifact']) : undefined;
    const aggregation = row['aggregation'] ? viewObject(row['aggregation']) : undefined;
    return { id, deviceKey: scope, metric, serverMetric: String(row['metric']), timestamp, source: 'watch_history', values, samples: [],
      sampleFrequency: artifact ? Number(artifact['sampleRateHz']) : 0,
      waveformReference: artifact ? { sampleRateHz: Number(artifact['sampleRateHz']), sampleCount: Number(artifact['sampleCount']), sha256: String(artifact['sha256']) } : undefined,
      aggregation: aggregation ? { kind: 'daily_summary', localDate: String(aggregation['localDate']), version: 1 } : undefined };
  });
}
