import { HealthRecord } from '../model/WearableContracts';
import { appText } from '../model/GlobalLocale';
import { waveformPoints } from '../model/HealthTrend';
import { waveformPageLabel } from '../model/PagePresentation';
import { saydianApi } from '../services/SaydianApi';

@Component
export struct EcgWaveformView {
  @Prop locale: string = 'en';
  private tr(text: string): string { return appText(text, this.locale); }
  @Prop record: HealthRecord;
  @Prop relationshipId: string = '';
  @State private samples: number[] = [];
  @State private rate: number = 0;
  @State private segment: number = 0;
  @State private chartWidth: number = 320;
  @State private loading: boolean = false;
  @State private message: string = '';
  private generation: number = 0;
  private release: (() => void) | undefined = undefined;
  aboutToAppear(): void {
    this.samples = this.record.samples.slice(); this.rate = this.record.sampleFrequency;
    this.release = saydianApi.observeSession(() => { ++this.generation; this.samples = []; this.message = ''; });
    // observeSession sends the current owner immediately; initialize after that callback.
    this.samples = this.record.samples.slice();
    if (!this.samples.length && this.record.waveformReference) this.load();
  }
  aboutToDisappear(): void { ++this.generation; this.release?.(); this.samples = []; }
  private async load(): Promise<void> {
    const generation = ++this.generation; this.loading = true; this.message = ''; this.samples = [];
    try {
      const wave = await saydianApi.globalEcg(this.record, this.relationshipId || undefined);
      if (generation !== this.generation) return;
      this.samples = wave.samples; this.rate = wave.sampleRateHz; this.segment = 0;
    } catch { if (generation === this.generation) this.message = this.tr('波形加载失败，重试'); }
    finally { if (generation === this.generation) this.loading = false; }
  }
  build() {
    Column({ space: 10 }) {
      if (this.record.measurementState === 'interrupted') { Text(this.tr('测量中断')).fontColor('#A04F28').fontSize(14) }
      if (this.record.quality === 'suspect') { Text(this.tr('波形预览')).fontColor('#716860').fontSize(14) }
      if (!this.rate && this.samples.length) { Text(this.tr('采样信息待同步')).fontColor('#716860').fontSize(14) }
      if (this.loading) { LoadingProgress().width(36).height(36) }
      if (this.samples.length > 1) {
        Polyline({ width: this.chartWidth, height: 160 }).points(waveformPoints(this.samples.slice(this.segment * 1000, (this.segment + 1) * 1000), this.chartWidth))
          .fillOpacity(0).stroke('#B84C4B').strokeWidth(1.5).width('100%').height(160)
          .onAreaChange((oldArea: Area, area: Area) => { this.chartWidth = Number(area.width); })
        Text(waveformPageLabel(this.samples.length, this.segment, this.rate)).fontSize(13).fontColor('#716860')
        if (this.samples.length > 1000) {
          Row({ space: 8 }) {
            Button(this.tr('上一段')).layoutWeight(1).enabled(this.segment > 0).onClick(() => this.segment--)
            Text(`${this.segment + 1}/${Math.ceil(this.samples.length / 1000)}`).fontSize(13)
            Button(this.tr('下一段')).layoutWeight(1).enabled((this.segment + 1) * 1000 < this.samples.length).onClick(() => this.segment++)
          }.width('100%')
        }
      }
      if (!this.loading && !this.samples.length) { Text(this.message || this.tr('暂无波形')).fontSize(14).fontColor('#716860') }
      if (this.message) { Button(this.tr('重试')).onClick(() => this.load()) }
    }.width('100%')
  }
}
