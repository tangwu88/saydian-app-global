import { ApiError } from './Contracts';
export interface GlobalEcgWaveform { samples: number[]; sampleRateHz: number; sampleCount: number; sha256: string; }
export function validateGlobalEcg(samples: Object, rate: number, count: number, sha256: string,
  expected?: { sampleRateHz: number; sampleCount: number; sha256: string; }): GlobalEcgWaveform {
  if (!Array.isArray(samples) || !Number.isInteger(rate) || rate < 50 || rate > 1000 ||
    !Number.isInteger(count) || count < 1 || count > 1000000 || samples.length !== count ||
    !/^[a-f0-9]{64}$/.test(sha256) || samples.some(value => typeof value !== 'number' || !Number.isFinite(value)) ||
    expected && (expected.sampleRateHz !== rate || expected.sampleCount !== count || expected.sha256 !== sha256)) throw new ApiError('波形校验失败，重试');
  return { samples: samples as number[], sampleRateHz: rate, sampleCount: count, sha256 };
}
