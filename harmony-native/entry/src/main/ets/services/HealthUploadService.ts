import type { HealthRecord } from '../model/WearableContracts';
import type { HealthOwnerSession, HealthSyncResult, HealthUploadRequest } from '../model/HealthUpload';
import { healthUploadRequests, sameHealthSession, validHealthOwner } from '../model/HealthUpload';

export interface HealthUploadStore {
  pending(ownerId: string, excludedIds?: string[]): Promise<HealthRecord[]>;
  markUploaded(ownerId: string, records: HealthRecord[], isCurrent: () => boolean): Promise<void>;
  pendingCount(ownerId: string): Promise<number>;
  savePreparedRecord?(ownerId: string, previous: HealthRecord, prepared: HealthRecord, isCurrent: () => boolean): Promise<void>;
}
export interface HealthUploadApi {
  healthSession(): HealthOwnerSession;
  uploadHealthRequest(request: HealthUploadRequest, session: HealthOwnerSession): Promise<void>;
  readonly globalHealthEnabled?: boolean;
  prepareGlobalHealthRecord?(record: HealthRecord, session: HealthOwnerSession): Promise<HealthRecord>;
  uploadGlobalHealthRecords?(records: HealthRecord[], session: HealthOwnerSession): Promise<string[]>;
}
export class HealthUploadService {
  private running: Promise<HealthSyncResult> | undefined = undefined;
  private store: HealthUploadStore;
  private api: HealthUploadApi;
  constructor(store: HealthUploadStore, api: HealthUploadApi) { this.store = store; this.api = api; }

  synchronize(isCurrent: () => boolean = () => true): Promise<HealthSyncResult> {
    if (this.running) return this.running;
    this.running = this.run(isCurrent).finally(() => { this.running = undefined; });
    return this.running;
  }
  private async run(isCurrent: () => boolean): Promise<HealthSyncResult> {
    const session = this.api.healthSession();
    const current = (): boolean => isCurrent() && sameHealthSession(session, this.api.healthSession());
    let uploaded = 0;
    const deferred: Set<string> = new Set();
    if (!validHealthOwner(session.ownerId)) return { state: 'signed_out', uploaded: 0, pending: 0, message: '' };
    try {
      while (current()) {
        const records = await this.store.pending(session.ownerId, Array.from(deferred));
        if (!current()) break;
        if (records.length === 0) {
          const pending = this.api.globalHealthEnabled ? await this.store.pendingCount(session.ownerId) : 0;
          if (!current()) break;
          return { state: pending ? 'retry' : 'complete', uploaded: uploaded, pending: pending, message: pending ? '待同步' : '' };
        }
        if (this.api.globalHealthEnabled) {
          if (records.every(record => deferred.has(record.id))) throw new Error('Unconfirmed health records');
          if (!this.api.uploadGlobalHealthRecords || !this.api.prepareGlobalHealthRecord || !this.store.savePreparedRecord) {
            throw new Error('Global health uploader unavailable');
          }
          const prepared: HealthRecord[] = [];
          for (const record of records) {
            if (!current()) break;
            try {
              const next = await this.api.prepareGlobalHealthRecord(record, session);
              if (!current()) break;
              // Persist the private-file receipt before sending its record. No account/connection crossing.
              if (JSON.stringify(next) !== JSON.stringify(record)) {
                await this.store.savePreparedRecord(session.ownerId, record, next, current);
              }
              prepared.push(next);
            } catch { /* Other pending records may still upload. The failed waveform stays pending. */ }
          }
          if (!current()) break;
          const ids = prepared.length ? await this.api.uploadGlobalHealthRecords(prepared, session) : [];
          if (!current()) break;
          const confirmed = prepared.filter((record: HealthRecord) => ids.includes(record.id));
          await this.store.markUploaded(session.ownerId, confirmed, current);
          if (!current()) break;
          uploaded += confirmed.length;
          records.filter(record => !ids.includes(record.id)).forEach(record => deferred.add(record.id));
          continue;
        }
        const requests = healthUploadRequests(records);
        if (!requests.length) throw new Error('部分记录暂不支持上传');
        for (const request of requests) {
          if (!current()) break;
          await this.api.uploadHealthRequest(request, session);
          if (!current()) break;
          await this.store.markUploaded(session.ownerId, records.filter((record: HealthRecord) => request.recordIds.includes(record.id)), current);
          if (!current()) break;
          uploaded += request.recordIds.length;
        }
      }
      return { state: 'cancelled', uploaded: uploaded, pending: 0, message: '' };
    } catch {
      if (!current()) return { state: 'cancelled', uploaded: uploaded, pending: 0, message: '' };
      return { state: 'retry', uploaded: uploaded, pending: await this.store.pendingCount(session.ownerId).catch(() => -1),
        message: '同步失败，重试' };
    }
  }
}
