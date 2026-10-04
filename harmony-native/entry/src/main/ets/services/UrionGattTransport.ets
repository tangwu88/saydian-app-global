import { ble, constant } from '@kit.ConnectivityKit';
import { util } from '@kit.ArkTS';
import { Eb1Frame, URION_SERVICE_UUID, URION_WRITE_UUID, URION_NOTIFY_UUID } from '../model/UrionEb1Protocol';
import { UrionCommandChannel } from './UrionCommandChannel';

export class UrionGattTransport {
  private client: ble.GattClientDevice | undefined = undefined;
  private writeCharacteristic: ble.BLECharacteristic | undefined = undefined;
  private generation: number = 0;
  private ready: boolean = false;
  private channel: UrionCommandChannel;
  private stateCallback: ((state: ble.BLEConnectionChangeState) => void) | undefined = undefined;
  private valueCallback: ((value: ble.BLECharacteristic) => void) | undefined = undefined;
  private connectingReject: ((error: Error) => void) | undefined = undefined;
  private onDisconnected: () => void;
  constructor(onFrame: (frame: Eb1Frame) => void, onDisconnected: () => void) {
    this.onDisconnected = onDisconnected;
    this.channel = new UrionCommandChannel((bytes: number[]) => this.write(bytes),
      () => this.disconnect(true), onFrame);
  }
  isReady(): boolean { return this.ready; }
  async connect(deviceId: string): Promise<number> {
    this.disconnect(false);
    const generation = this.generation;
    const channelGeneration = this.channel.session();
    const client = ble.createGattClientDevice(deviceId);
    this.client = client;
    let timer = -1;
    const connected = new Promise<void>((resolve, reject) => {
      this.connectingReject = reject;
      timer = setTimeout(() => reject(new Error('Urion connection timeout')), 30000);
      this.stateCallback = (state: ble.BLEConnectionChangeState): void => {
        if (generation !== this.generation || this.client !== client || state.deviceId !== deviceId) return;
        if (state.state === constant.ProfileConnectionState.STATE_CONNECTED) resolve();
        else if (state.state === constant.ProfileConnectionState.STATE_DISCONNECTED) this.disconnect(true);
      };
      this.valueCallback = (value: ble.BLECharacteristic): void => {
        if (generation !== this.generation || this.client !== client || value.serviceUuid.toLowerCase() !== URION_SERVICE_UUID ||
          value.characteristicUuid.toLowerCase() !== URION_NOTIFY_UUID) return;
        this.channel.receive(Array.from(new Uint8Array(value.characteristicValue)), channelGeneration);
      };
      client.on('BLEConnectionStateChange', this.stateCallback);
      client.on('BLECharacteristicChange', this.valueCallback);
      client.connect();
    });
    try {
      await connected;
      const services = await this.bounded(client.getServices(), generation);
      this.assertCurrent(generation, client);
      const service = services.find((value: ble.GattService) => value.serviceUuid.toLowerCase() === URION_SERVICE_UUID);
      const write = service?.characteristics.find((value: ble.BLECharacteristic) => value.characteristicUuid.toLowerCase() === URION_WRITE_UUID);
      const notify = service?.characteristics.find((value: ble.BLECharacteristic) => value.characteristicUuid.toLowerCase() === URION_NOTIFY_UUID);
      if (!write || !notify || (!write.properties?.write && !write.properties?.writeNoResponse) ||
        (!notify.properties?.notify && !notify.properties?.indicate)) throw new Error('Urion EB1 service unavailable');
      this.writeCharacteristic = write;
      await this.bounded(client.setCharacteristicChangeNotification(notify, true), generation);
      this.assertCurrent(generation, client);
      // The subscription ACK and a validated EB1 battery response must precede the connected UI state.
      const battery = (await this.channel.exchange(3))[0].bytes[1];
      if (battery > 100) throw new Error('Invalid Urion handshake');
      this.assertCurrent(generation, client);
      this.ready = true;
      return battery;
    } catch (error) {
      if (generation === this.generation) this.disconnect(false);
      throw error as Error;
    } finally {
      clearTimeout(timer);
      if (generation === this.generation) this.connectingReject = undefined;
    }
  }
  async exchange(command: number, payload: number[] = [], count: number = 1): Promise<Eb1Frame[]> {
    if (!this.ready) throw new Error('Urion disconnected');
    return this.channel.exchange(command, payload, count);
  }
  async firmware(): Promise<string> {
    const client = this.client; const generation = this.generation;
    if (!client || !this.ready) return '';
    try {
      const services = await this.bounded(client.getServices(), generation);
      const service = services.find((value: ble.GattService) => uuid16(value.serviceUuid) === '180a');
      const firmware = service?.characteristics.find((value: ble.BLECharacteristic) => uuid16(value.characteristicUuid) === '2a26');
      if (!firmware) return '';
      const result = await this.bounded(client.readCharacteristicValue(firmware), generation);
      this.assertCurrent(generation, client);
      return new util.TextDecoder().decodeToString(new Uint8Array(result.characteristicValue))
        .replace(/[\u0000-\u001f\u007f]/g, '').trim();
    } catch { return ''; }
  }
  disconnect(notify: boolean = false): void {
    const wasReady = this.ready;
    ++this.generation; this.ready = false;
    const reject = this.connectingReject; this.connectingReject = undefined;
    reject?.(new Error('Urion disconnected'));
    this.channel.retire();
    const client = this.client; this.client = undefined; this.writeCharacteristic = undefined;
    if (client) {
      try { if (this.stateCallback) client.off('BLEConnectionStateChange', this.stateCallback); } catch {}
      try { if (this.valueCallback) client.off('BLECharacteristicChange', this.valueCallback); } catch {}
      try { client.disconnect(); } catch {}
      try { client.close(); } catch {}
    }
    this.stateCallback = undefined; this.valueCallback = undefined;
    if (notify && wasReady) this.onDisconnected();
  }
  private async write(bytes: number[]): Promise<void> {
    const client = this.client; const characteristic = this.writeCharacteristic;
    if (!client || !characteristic) throw new Error('Urion channel unavailable');
    const value: ble.BLECharacteristic = { serviceUuid: characteristic.serviceUuid,
      characteristicUuid: characteristic.characteristicUuid, characteristicValue: new Uint8Array(bytes).buffer,
      descriptors: characteristic.descriptors };
    await client.writeCharacteristicValue(value, characteristic.properties?.write ? ble.GattWriteType.WRITE : ble.GattWriteType.WRITE_NO_RESPONSE);
  }
  private assertCurrent(generation: number, client: ble.GattClientDevice): void {
    if (generation !== this.generation || this.client !== client) throw new Error('Urion connection changed');
  }
  private async bounded<T>(operation: Promise<T>, generation: number): Promise<T> {
    let timer = -1;
    const timeout = new Promise<T>((resolve, reject) => {
      timer = setTimeout(() => reject(new Error('Urion GATT timeout')), 8000);
    });
    try {
      const result = await Promise.race([operation, timeout]);
      if (generation !== this.generation) throw new Error('Urion connection changed');
      return result;
    } finally { clearTimeout(timer); }
  }
}
function uuid16(uuid: string): string {
  const value = uuid.toLowerCase();
  return value.length === 4 ? value : /^0000[0-9a-f]{4}-0000-1000-8000-00805f9b34fb$/.test(value) ? value.slice(4, 8) : '';
}
