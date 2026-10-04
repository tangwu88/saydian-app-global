import { common } from '@kit.AbilityKit';
import { HealthRecord, MeasurementState, SportSessionState, WearableConnectionPhase, WearableDevice,
  WearableMetricKey, WearableSnapshot, WearableSportMode, emptyWearableSnapshot, emptyMeasurement, emptySportSession } from '../model/WearableContracts';
import { HealthSyncResult } from '../model/HealthUpload';
import { Eb1DynamicPressureSettings, Eb1PulseSample } from '../model/UrionEb1Protocol';
import { wearableHealthStore } from './WearableHealthStore';
import { saydianApi } from './SaydianApi';
import { HealthUploadService } from './HealthUploadService';
export interface WearableServiceListener {
  onDevices?: (devices: WearableDevice[]) => void;
  onPhase?: (phase: WearableConnectionPhase, message: string) => void;
  onSnapshot?: (snapshot: WearableSnapshot) => void;
  onMeasurement?: (measurement: MeasurementState) => void;
  onSportSession?: (session: SportSessionState) => void;
  onCloudSync?: (result: HealthSyncResult) => void;
}
// Emulator-only facade: no native wearables, synthetic measurements or successful hardware ACKs.
export class VepWearableService {
  private listener: WearableServiceListener | undefined = undefined;
  setDevicePageVisible(visible: boolean): void {}
  attachContext(context: common.UIAbilityContext): void { wearableHealthStore.open(context).catch(() => {}); }
  setListener(listener: WearableServiceListener): void {
    this.listener = listener; listener.onDevices?.([]); listener.onSnapshot?.(emptyWearableSnapshot());
    listener.onMeasurement?.(emptyMeasurement()); listener.onSportSession?.(emptySportSession());
  }
  clearListener(): void { this.listener = undefined; }
  isScanning(): boolean { return false; }
  isConnected(): boolean { return false; }
  currentSnapshot(): WearableSnapshot { return emptyWearableSnapshot(); }
  currentMeasurement(): MeasurementState { return emptyMeasurement(); }
  currentSportSession(): SportSessionState { return emptySportSession(); }
  async startScan(): Promise<boolean> { this.listener?.onPhase?.('idle', '模拟器不连接手表'); return false; }
  stopScan(message: string = ''): void {}
  async connect(deviceKey: string, isRetry: boolean = false): Promise<boolean> { throw new Error('模拟器不连接手表'); }
  async disconnect(): Promise<void> {}
  async refresh(): Promise<boolean> { return false; }
  async syncHistory(): Promise<boolean> { return false; }
  async findDevice(): Promise<boolean> { return false; }
  async syncTime(): Promise<boolean> { return false; }
  async readDeviceConfiguration(): Promise<boolean> { return false; }
  async readDials(): Promise<boolean> { return false; }
  async setExistingDial(dialKey: string): Promise<boolean> { return false; }
  async restoreOriginalDial(): Promise<boolean> { return false; }
  async startMeasurement(metric: WearableMetricKey): Promise<boolean> { throw new Error('模拟器不测量'); }
  async stopMeasurement(): Promise<void> {}
  async startSport(mode: WearableSportMode): Promise<boolean> { throw new Error('模拟器不测量'); }
  async pauseSport(): Promise<boolean> { return false; }
  async resumeSport(): Promise<boolean> { return false; }
  async stopSport(): Promise<boolean> { return false; }
  async readUrionPressureSettings(): Promise<Eb1DynamicPressureSettings> { throw new Error('模拟器不连接手表'); }
  async saveUrionPressureSettings(settings: Eb1DynamicPressureSettings): Promise<void> { throw new Error('模拟器不连接手表'); }
  async readUrionPulse(start: boolean = false, isCurrent: () => boolean = () => true): Promise<Eb1PulseSample | undefined> { throw new Error('模拟器不测量'); }
  async runDeviceCommand<T>(name: string, action: (current: () => void) => Promise<T>): Promise<T> { throw new Error('模拟器不连接手表'); }
  async savedSportRecords(): Promise<HealthRecord[]> { return wearableHealthStore.loadSportRecords(saydianApi.healthSession().ownerId); }
  async healthRange(deviceKey: string, metric: WearableMetricKey, start: number, end: number): Promise<HealthRecord[]> {
    return wearableHealthStore.loadRange(saydianApi.healthSession().ownerId, deviceKey, metric, start, end - 1);
  }
  async synchronizeCloud(): Promise<HealthSyncResult> {
    return new HealthUploadService(wearableHealthStore, saydianApi).synchronize(() => true);
  }
  shutdown(): void { this.clearListener(); }
}
export const vepWearable: VepWearableService = new VepWearableService();
