import { rcp } from '@kit.RemoteCommunicationKit';
import { util } from '@kit.ArkTS';
import { API_BASE, ApiError } from '../model/Contracts';
import { MAX_REPORT_PDF_BYTES, validateReportPdf } from '../model/GlobalHealthReports';

export interface SafeHttpResponse { result: string; responseCode: number; }
export interface SafeEcgResponse { bytes: Uint8Array; sha256: string; sampleRateHz: number; sampleCount: number; }
function receivedBytes(chunks: Uint8Array[], total: number, body: ArrayBuffer | undefined, limit: number, failure: string): Uint8Array {
  // API 17 returns response.body even when the streaming callback is configured.
  // Never accept a fallback larger than the endpoint's limit. RCP itself caps buffered downloads at 50 MB.
  if (!total && body) {
    if (body.byteLength > limit) throw new ApiError(failure);
    return new Uint8Array(body);
  }
  const bytes = new Uint8Array(total); let offset = 0;
  chunks.forEach((chunk: Uint8Array) => { bytes.set(chunk, offset); offset += chunk.length; });
  return bytes;
}
export async function safeEcgHttp(url: string, headers: Record<string, string>): Promise<SafeEcgResponse> {
  if (!url.startsWith(`${API_BASE}/global/api/saydian-app/v2/`) || !/\/(health\/records\/[^/?]+|care\/relationships\/[0-9a-f-]{36}\/health\/[^/?]+)\/ecg$/i.test(url) ||
    /[\\\x00-\x20]/.test(url) || url.includes('..')) throw new ApiError('波形暂不可用');
  const client = rcp.createSession({ requestConfiguration: { transfer: { autoRedirect: false,
    timeout: { connectMs: 15000, transferMs: 60000 } } } });
  const chunks: Uint8Array[] = []; let total = 0, tooLarge = false;
  const receive = (incoming: ArrayBuffer): void => {
    if (tooLarge) return;
    if (total + incoming.byteLength > 25 * 1024 * 1024) { tooLarge = true; client.cancel(request); return; }
    chunks.push(new Uint8Array(incoming).slice()); total += incoming.byteLength;
  };
  const request = new rcp.Request(url, 'GET', headers, undefined, undefined, undefined, {
    transfer: { autoRedirect: false, timeout: { connectMs: 15000, transferMs: 60000 } }, tracing: { httpEventsHandler: { onDataReceive: receive } }
  });
  try {
    const response = await client.fetch(request);
    if (tooLarge || response.statusCode < 200 || response.statusCode >= 300) throw new ApiError('波形加载失败，重试', response.statusCode);
    const bytes = receivedBytes(chunks, total, response.body, 25 * 1024 * 1024, '波形暂不可用');
    const fields: Record<string, string> = {};
    Object.keys(response.headers).forEach((key: string) => { const value = response.headers[key]; if (typeof value === 'string') fields[key.toLowerCase()] = value; });
    return { bytes, sha256: fields['x-content-sha256'] ?? '', sampleRateHz: Number(fields['x-ecg-sample-rate']), sampleCount: Number(fields['x-ecg-sample-count']) };
  } finally { client.close(); }
}

// PDF download stays binary and uses the same redirect protection on API 17+.
export async function safeReportPdfHttp(url: string, headers: Record<string, string>): Promise<ArrayBuffer> {
  if (!new RegExp(`^${API_BASE.replace(/\./g, '\\.')}\/global\/api\/saydian-app\/v2\/health\/reports\/[0-9a-f-]{36}\/export$`, 'i').test(url)) {
    throw new ApiError('reports_export_failed');
  }
  const client = rcp.createSession({ requestConfiguration: {
    transfer: { autoRedirect: false, timeout: { connectMs: 15000, transferMs: 60000 } }
  } });
  const chunks: Uint8Array[] = [];
  let total = 0, tooLarge = false;
  const receive = (incoming: ArrayBuffer): void => {
    if (tooLarge) return;
    if (total + incoming.byteLength > MAX_REPORT_PDF_BYTES) { tooLarge = true; client.cancel(request); return; }
    chunks.push(new Uint8Array(incoming).slice()); total += incoming.byteLength;
  };
  const request = new rcp.Request(url, 'GET', headers, undefined, undefined, undefined, {
    transfer: { autoRedirect: false, timeout: { connectMs: 15000, transferMs: 60000 } }, tracing: { httpEventsHandler: { onDataReceive: receive } }
  });
  try {
    const response = await client.fetch(request);
    if (tooLarge) throw new ApiError('reports_export_failed');
    if (response.statusCode < 200 || response.statusCode >= 300) throw new ApiError('reports_export_failed', response.statusCode);
    const bytes = receivedBytes(chunks, total, response.body, MAX_REPORT_PDF_BYTES, 'reports_export_failed');
    return validateReportPdf(bytes.buffer);
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError('reports_export_failed');
  } finally { client.close(); }
}

// NetworkKit.maxRedirects starts at API 23. RCP has supported autoRedirect=false
// since API 11. Use streaming where available and a size-checked response.body
// fallback on API 17 runtimes which ignore the callback.
export async function legacySafeHttp(url: string, method: 'GET' | 'POST' | 'PUT' | 'DELETE',
  headers: Record<string, string>, body: string | ArrayBuffer, readTimeout: number): Promise<SafeHttpResponse> {
  if (!url.startsWith(`${API_BASE}/global/api/saydian-app/v2/`)) throw new ApiError('请求地址不正确');
  const client = rcp.createSession({ requestConfiguration: {
    transfer: { autoRedirect: false, timeout: { connectMs: 15000, transferMs: readTimeout } }
  } });
  const chunks: Uint8Array[] = [];
  let total = 0;
  let tooLarge = false;
  const receive = (incoming: ArrayBuffer): void => {
    if (tooLarge) return;
    if (total + incoming.byteLength > 2 * 1024 * 1024) {
      tooLarge = true;
      client.cancel(request);
      return;
    }
    chunks.push(new Uint8Array(incoming).slice());
    total += incoming.byteLength;
  };
  const request = new rcp.Request(url, method, headers, body, undefined, undefined, {
    transfer: { autoRedirect: false, timeout: { connectMs: 15000, transferMs: readTimeout } }, tracing: { httpEventsHandler: { onDataReceive: receive } }
  });
  try {
    const response = await client.fetch(request);
    if (tooLarge) throw new ApiError('返回的数据过多，请稍后重试');
    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw new ApiError('服务地址暂不可用，请稍后重试');
    }
    const bytes = receivedBytes(chunks, total, response.body, 2 * 1024 * 1024, '返回的数据过多，请稍后重试');
    return { result: new util.TextDecoder().decodeToString(bytes), responseCode: response.statusCode };
  } catch (error) {
    if (tooLarge) throw new ApiError('返回的数据过多，请稍后重试');
    throw error as Error;
  } finally { client.close(); }
}
