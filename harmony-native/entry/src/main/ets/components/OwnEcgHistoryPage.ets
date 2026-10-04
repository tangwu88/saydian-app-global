import { saydianApi } from '../services/SaydianApi';
import { wearableHealthStore } from '../services/WearableHealthStore';
import { HealthRecord } from '../model/WearableContracts';
import { appText } from '../model/GlobalLocale';
import { EcgWaveformView } from './EcgWaveformView';
@Component
export struct OwnEcgHistoryPage {
  @Prop locale: string = 'en';
  onLogin: () => void = (): void => {};
  private tr(text: string): string { return appText(text, this.locale); }
  @State private records: HealthRecord[] = [];
  @State private record: HealthRecord | undefined = undefined;
  @State private loading: boolean = false;
  @State private message: string = '';
  @State private cursor: string = '';
  @State private synchronized: string[] = [];
  @State private authenticated: boolean = false;
  private sessionOwner: string = '';
  private sessionEpoch: number = -1;
  private generation: number = 0;
  private release: (() => void) | undefined = undefined;
  aboutToAppear(): void {
    this.release = saydianApi.observeSession(() => this.sessionChanged());
  }
  aboutToDisappear(): void { ++this.generation; this.release?.(); this.records = []; this.record = undefined; }
  private sessionChanged(): void {
    const session = saydianApi.healthSession();
    if (session.ownerId === this.sessionOwner && session.generation === this.sessionEpoch) return;
    this.sessionOwner = session.ownerId; this.sessionEpoch = session.generation;
    ++this.generation; this.records = []; this.record = undefined; this.cursor = ''; this.synchronized = []; this.loading = false; this.message = '';
    this.authenticated = !!session.ownerId;
    if (this.authenticated) this.load();
  }
  private async load(more: boolean = false): Promise<void> {
    if (this.loading || !this.authenticated) return; const epoch = ++this.generation; this.loading = true; this.message = '';
    try {
      if (!more) {
        const owner = saydianApi.healthSession().ownerId;
        const local = await wearableHealthStore.loadRecent(owner);
        const synchronized = await wearableHealthStore.synchronizedIds(owner);
        if (epoch !== this.generation) return; this.synchronized = synchronized;
        this.records = local.filter(record => record.metric === 'ecg');
      }
      const page = await saydianApi.globalEcgHistory(more ? this.cursor : ''); if (epoch !== this.generation) return;
      const existing = new Map<string, HealthRecord>(); this.records.forEach(record => existing.set(record.id, record));
      page.records.forEach(record => {
        const saved = existing.get(record.id);
        if (!saved) existing.set(record.id, record);
        else if (record.waveformReference) saved.waveformReference = record.waveformReference;
      });
      this.records = Array.from(existing.values()).sort((a, b) => b.timestamp - a.timestamp); this.cursor = page.nextCursor;
    } catch { if (epoch === this.generation) this.message = this.tr('加载失败，重试'); }
    finally { if (epoch === this.generation) this.loading = false; }
  }
  build() {
    Column({ space: 14 }) {
      if (!this.authenticated) {
        Text(this.tr('请先登录')).fontColor('#716860')
        Button(this.tr('前往登录')).onClick(() => this.onLogin())
      } else if (this.record) {
        Button(this.tr('返回')).onClick(() => this.record = undefined)
        Text(new Date(this.record.timestamp).toLocaleString()).fontSize(16)
        EcgWaveformView({ record: this.record, locale: this.locale })
      } else {
        if (this.loading) { LoadingProgress().width(36).height(36) }
        if (this.message) { Text(this.message).fontColor('#716860'); Button(this.tr('重试')).onClick(() => this.load()) }
        ForEach(this.records, (record: HealthRecord) => {
          Column({ space: 8 }) {
            Text(new Date(record.timestamp).toLocaleString()).fontSize(16).width('100%')
            Text(this.tr(record.measurementState === 'interrupted' ? '测量中断' : !record.waveformReference && !this.synchronized.includes(record.id) ? '待同步' : '查看波形')).fontSize(14).fontColor('#716860')
          }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18).onClick(() => this.record = record)
        }, (record: HealthRecord) => record.id)
        if (!this.loading && !this.records.length) { Text(this.tr('暂无记录')) }
        if (this.cursor) { Button(this.tr('更多')).enabled(!this.loading).onClick(() => this.load(true)) }
      }
    }.width('100%')
  }
}
