import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { deviceInfo } from '@kit.BasicServicesKit';
import { sha256Bytes, sha256Text } from './NativeDataIntegrity';
import { gzip, Inflate } from 'pako';
import { GlobalEcgWaveform, validateGlobalEcg } from '../model/GlobalEcg';
import { HealthRecord } from '../model/WearableContracts';
import { ApiError, Envelope, Session, FormField, UploadFile, decodeEnvelope, buildMultipart } from '../model/Contracts';
import { AccountClient, ApiTransport } from './AccountClient';
import { SessionVault } from './SessionVault';
import { apiReadTimeout } from '../model/RequestPolicy';
import { internationalUrl } from '../model/GlobalConfiguration';
import { currentAppLocale } from '../model/GlobalLocale';

interface ImageKind { mime: string; extension: string; }
interface WaveInflater { err: number; onData: (chunk: Uint8Array) => void; push(data: Uint8Array, final: boolean): boolean; }

class NativeHttpTransport implements ApiTransport {
  async waveform(path: string, session: Session): Promise<GlobalEcgWaveform> {
    const safe = await import('./LegacySafeHttp');
    const response = await safe.safeEcgHttp(internationalUrl(path), { 'Accept': 'application/gzip',
      'Authorization': `Bearer ${session.accessToken}`, 'Accept-Language': currentAppLocale() });
    if (await sha256Bytes(response.bytes) !== response.sha256) throw new ApiError('波形校验失败，重试');
    const inflater: WaveInflater = new Inflate() as WaveInflater; const chunks: Uint8Array[] = []; let total = 0;
    inflater.onData = (chunk: Uint8Array): void => {
      total += chunk.length; if (total > 32 * 1024 * 1024) throw new ApiError('波形暂不可用');
      chunks.push(chunk.slice());
    };
    inflater.push(response.bytes, true);
    if (inflater.err) throw new ApiError('波形校验失败，重试');
    const plain = new Uint8Array(total); let offset = 0;
    chunks.forEach((chunk: Uint8Array) => { plain.set(chunk, offset); offset += chunk.length; });
    let decoded: Object;
    try { decoded = JSON.parse(new util.TextDecoder().decodeToString(plain)) as Object; }
    catch { throw new ApiError('波形校验失败，重试'); }
    return validateGlobalEcg(decoded, response.sampleRateHz, response.sampleCount, response.sha256);
  }
  async hash(text: string): Promise<string> { return sha256Text(text); }
  async prepareEcg(record: HealthRecord, session: Session): Promise<HealthRecord> {
    const rate = record.sampleFrequency;
    const preview = record.rawVersion === 1 && record.quality === 'suspect' && record.source === 'app_measurement';
    if (record.metric !== 'ecg' || (!preview && (record.rawVersion ?? 0) < 2) ||
      !Number.isInteger(rate) || rate < 50 || rate > 1000 || !record.samples.length || record.samples.length > 1000000 ||
      record.samples.some((sample: number) => !Number.isFinite(sample))) throw new ApiError('Waveform metadata incomplete');
    const bytes: Uint8Array = gzip(new util.TextEncoder().encodeInto(JSON.stringify(record.samples)));
    if (bytes.length > 25 * 1024 * 1024) throw new ApiError('Waveform too large');
    const sha256 = await sha256Bytes(bytes);
    const existing = record.ecgArtifact;
    if (existing && existing.sha256 === sha256 && existing.sampleRateHz === rate && existing.sampleCount === record.samples.length &&
      existing.byteSize === bytes.length && existing.encoding === 'gzip_json_v1' && existing.uploadObjectKey.startsWith('ecg/') &&
      !existing.uploadObjectKey.includes('..')) return record;
    const boundary = `----SaydianEcg${Date.now()}${Math.floor(Math.random() * 1000000)}`;
    const prefix = new util.TextEncoder().encodeInto(`--${boundary}\r\nContent-Disposition: form-data; name="sha256"\r\n\r\n${sha256}\r\n` +
      `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="ecg-samples.json.gz"\r\nContent-Type: application/gzip\r\n\r\n`);
    const suffix = new util.TextEncoder().encodeInto(`\r\n--${boundary}--\r\n`);
    const body = new Uint8Array(prefix.length + bytes.length + suffix.length);
    body.set(prefix); body.set(bytes, prefix.length); body.set(suffix, prefix.length + bytes.length);
    const safe = await import('./LegacySafeHttp');
    const response = await safe.legacySafeHttp(internationalUrl('/api/saydian-app/v2/files/ecg'), 'POST', {
      'Accept': 'application/json', 'Accept-Language': currentAppLocale(), 'Authorization': `Bearer ${session.accessToken}`,
      'Content-Type': `multipart/form-data; boundary=${boundary}`
    }, body.buffer, 60000);
    const envelope = decodeEnvelope(response.result, response.responseCode);
    const receipt = envelope.data as Record<string, Object> | undefined;
    const key = receipt?.['uploadObjectKey'];
    if (!receipt || receipt['sha256'] !== sha256 || receipt['byteSize'] !== bytes.length || typeof key !== 'string' ||
      !key.startsWith('ecg/') || key.includes('..')) throw new ApiError('Invalid waveform receipt');
    const prepared = JSON.parse(JSON.stringify(record)) as HealthRecord;
    prepared.ecgArtifact = { uploadObjectKey: key, sampleRateHz: rate, sampleCount: record.samples.length,
      sha256: sha256, byteSize: bytes.length, encoding: 'gzip_json_v1' };
    return prepared;
  }
  async download(path: string, session: Session): Promise<ArrayBuffer> {
    const legacy = await import('./LegacySafeHttp');
    return legacy.safeReportPdfHttp(internationalUrl(path), { 'Accept': 'application/pdf',
      'Accept-Language': currentAppLocale(), 'Authorization': `Bearer ${session.accessToken}` });
  }

  async request(path: string, fields?: FormField[], session?: Session, jsonBody?: string,
    method?: 'GET' | 'POST' | 'PUT' | 'DELETE', readTimeoutMs?: number, idempotencyKey?: string): Promise<Envelope> {
    // Fixed HTTPS origin; credentials never reach configurable hosts or redirects.
    if (!path.startsWith('/api/') || path.includes('://')) throw new ApiError('请求地址不正确');
    if (fields && jsonBody !== undefined) throw new ApiError('请求格式不正确');
    const requestMethod = method ?? (fields || jsonBody !== undefined ? 'POST' : 'GET');
    const timeoutMs = apiReadTimeout(readTimeoutMs);
    if ((requestMethod === 'GET' || requestMethod === 'DELETE') && (fields || jsonBody !== undefined)) {
      throw new ApiError('请求格式不正确');
    }
    const client = http.createHttp();
    const headers: Record<string, string> = { 'Accept': 'application/json', 'Accept-Language': currentAppLocale() };
    if (idempotencyKey !== undefined) {
      if (!/^global-health-[a-f0-9]{64}$/.test(idempotencyKey)) throw new ApiError('Invalid idempotency key');
      headers['Idempotency-Key'] = idempotencyKey;
    }
    if (session) {
      headers['Authorization'] = `Bearer ${session.accessToken}`;
    }
    const boundary = `----SaydianHarmony${Date.now()}${Math.floor(Math.random() * 1000000)}`;
    if (fields) headers['Content-Type'] = `multipart/form-data; boundary=${boundary}`;
    if (jsonBody !== undefined) headers['Content-Type'] = 'application/json';
    try {
      if (deviceInfo.sdkApiVersion < 23) {
        const legacy = await import('./LegacySafeHttp');
        const response = await legacy.legacySafeHttp(internationalUrl(path), requestMethod, headers,
          fields ? buildMultipart(fields, boundary) : jsonBody ?? '', timeoutMs);
        return decodeEnvelope(response.result, response.responseCode);
      }
      const response = await client.request(internationalUrl(path), {
        method: requestMethod === 'DELETE' ? http.RequestMethod.DELETE :
          requestMethod === 'PUT' ? http.RequestMethod.PUT :
          requestMethod === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
        header: headers,
        extraData: fields ? buildMultipart(fields, boundary) : jsonBody ?? '',
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: timeoutMs,
        maxRedirects: 0,
        maxLimit: 2 * 1024 * 1024,
        usingCache: false
      });
      return decodeEnvelope(response.result as string, response.responseCode);
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError('网络连接失败或超时，请检查网络后重试');
    } finally { client.destroy(); }
  }

  async upload(path: string, file: UploadFile, session: Session): Promise<Envelope> {
    if (path !== '/api/v1/file/images' || !file.uri.trim()) throw new ApiError('请求地址不正确');
    const opened = fileIo.openSync(file.uri, fileIo.OpenMode.READ_ONLY);
    let bytes: Uint8Array;
    try {
      const size = fileIo.statSync(opened.fd).size;
      if (!Number.isSafeInteger(size) || size <= 0) throw new ApiError('所选图片不可用');
      if (size > file.maxBytes) throw new ApiError('图片过大，请选择 6 MB 以内的照片');
      bytes = new Uint8Array(size);
      let offset = 0;
      while (offset < size) {
        const count = fileIo.readSync(opened.fd, bytes.buffer, { offset: offset, length: size - offset });
        if (count <= 0) break;
        offset += count;
      }
      if (offset !== size) throw new ApiError('照片读取不完整，请重新选择');
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError('无法读取照片，请重新选择');
    } finally { fileIo.closeSync(opened); }

    const kind = this.imageKind(bytes);
    if (!kind.mime) throw new ApiError('请选择 JPG、PNG、WebP 或 HEIC 图片');
    const boundary = `----SaydianHarmonyImage${Date.now()}${Math.floor(Math.random() * 1000000)}`;
    const safeStem = file.fileName.replace(/[^A-Za-z0-9_-]/g, '').slice(0, 40) || 'avatar';
    const prefix = new util.TextEncoder().encodeInto(`--${boundary}\r\n` +
      `Content-Disposition: form-data; name="file"; filename="${safeStem}.${kind.extension}"\r\n` +
      `Content-Type: ${kind.mime}\r\n\r\n`);
    const suffix = new util.TextEncoder().encodeInto(`\r\n--${boundary}--\r\n`);
    const body = new Uint8Array(prefix.length + bytes.length + suffix.length);
    body.set(prefix, 0); body.set(bytes, prefix.length); body.set(suffix, prefix.length + bytes.length);
    const client = http.createHttp();
    try {
      if (deviceInfo.sdkApiVersion < 23) {
        const legacy = await import('./LegacySafeHttp');
        const response = await legacy.legacySafeHttp(internationalUrl(path), 'POST', {
          'Accept': 'application/json', 'Accept-Language': currentAppLocale(), 'Authorization': `Bearer ${session.accessToken}`,
          'Content-Type': `multipart/form-data; boundary=${boundary}`
        }, body.buffer, 30000);
        return decodeEnvelope(response.result, response.responseCode);
      }
      const response = await client.request(internationalUrl(path), {
        method: http.RequestMethod.POST,
        header: { 'Accept': 'application/json', 'Accept-Language': currentAppLocale(), 'Authorization': `Bearer ${session.accessToken}`,
          'Content-Type': `multipart/form-data; boundary=${boundary}` },
        extraData: body.buffer,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000,
        maxRedirects: 0,
        maxLimit: 2 * 1024 * 1024,
        usingCache: false
      });
      return decodeEnvelope(response.result as string, response.responseCode);
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError('头像上传失败，请检查网络后重试');
    } finally { client.destroy(); }
  }

  private imageKind(bytes: Uint8Array): ImageKind {
    if (bytes.length >= 3 && bytes[0] === 0xFF && bytes[1] === 0xD8 && bytes[2] === 0xFF) {
      return { mime: 'image/jpeg', extension: 'jpg' };
    }
    if (bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4E && bytes[3] === 0x47) {
      return { mime: 'image/png', extension: 'png' };
    }
    if (bytes.length >= 12 && bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 &&
      bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50) {
      return { mime: 'image/webp', extension: 'webp' };
    }
    if (bytes.length >= 12 && bytes[4] === 0x66 && bytes[5] === 0x74 && bytes[6] === 0x79 && bytes[7] === 0x70) {
      return { mime: 'image/heic', extension: 'heic' };
    }
    return { mime: '', extension: '' };
  }
}

export const saydianApi: AccountClient = new AccountClient(new NativeHttpTransport(), new SessionVault(), () => Date.now(), true);
