import { vepWearable } from '../services/VepWearableService';
import { Eb1DynamicPressureSettings, Eb1PulseSample } from '../model/UrionEb1Protocol';
import { appText } from '../model/GlobalLocale';

@Component
export struct UrionFeaturesPage {
  @Prop locale: string = 'en';
  private tr(text: string): string { return appText(text, this.locale); }
  @Prop feature: string = '';
  @State private monitoringEnabled: boolean = false;
  @State private startHour: string = '8';
  @State private dayInterval: string = '60';
  @State private nightInterval: string = '120';
  @State private pulse: Eb1PulseSample | undefined = undefined;
  @State private busy: boolean = false;
  @State private ready: boolean = false;
  @State private message: string = '';
  private generation: number = 0;
  aboutToAppear(): void { this.load(); }
  aboutToDisappear(): void { ++this.generation; }
  private async load(): Promise<void> {
    const generation = ++this.generation; this.busy = true; this.message = ''; this.ready = false;
    try {
      if (this.feature === 'healthMonitoring') {
        const settings = await vepWearable.readUrionPressureSettings(); if (generation !== this.generation) return;
        this.monitoringEnabled = settings.enabled; this.startHour = String(settings.startHour);
        this.dayInterval = String(settings.dayIntervalMinutes); this.nightInterval = String(settings.nightIntervalMinutes);
      } else {
        const pulse = await vepWearable.readUrionPulse(); if (generation !== this.generation) return; this.pulse = pulse;
      }
      this.ready = true;
    } catch { if (generation === this.generation) this.message = this.tr('读取失败，重试'); }
    finally { if (generation === this.generation) this.busy = false; }
  }
  private async save(): Promise<void> {
    if (this.busy || !this.ready) return; const generation = this.generation; this.busy = true;
    const settings: Eb1DynamicPressureSettings = { enabled: this.monitoringEnabled, startHour: Number(this.startHour),
      dayIntervalMinutes: Number(this.dayInterval), nightIntervalMinutes: Number(this.nightInterval) };
    try { await vepWearable.saveUrionPressureSettings(settings); if (generation === this.generation) this.message = this.tr('已保存'); }
    catch { if (generation === this.generation) { this.ready = false; this.message = this.tr('保存失败，重试'); } }
    finally { if (generation === this.generation) this.busy = false; }
  }
  private async measure(): Promise<void> {
    if (this.busy || !this.ready) return; const generation = this.generation; this.busy = true; this.pulse = undefined;
    this.message = this.tr('请保持静止，在手表上结束测量');
    try { const result = await vepWearable.readUrionPulse(true, () => generation === this.generation); if (generation === this.generation) { this.pulse = result; this.message = result ? this.tr('测量完成') : this.tr('未收到有效测量结果'); } }
    catch { if (generation === this.generation) this.message = this.tr('未收到有效测量结果'); }
    finally { if (generation === this.generation) this.busy = false; }
  }
  build() {
    Column({ space: 14 }) {
      Text(this.tr(this.feature === 'healthMonitoring' ? '动态血压' : '脉诊')).fontSize(22).fontWeight(FontWeight.Bold)
      if (this.busy) { LoadingProgress().width(36).height(36) }
      if (this.message) { Text(this.message).fontSize(15).fontColor('#716860') }
      if (this.feature === 'healthMonitoring') {
        Row() { Text(this.tr('自动测量')).layoutWeight(1); Toggle({ type: ToggleType.Switch, isOn: this.monitoringEnabled }).enabled(!this.busy && this.ready).onChange((value: boolean) => this.monitoringEnabled = value) }.width('100%')
        Text(this.tr('白天开始小时')).width('100%')
        TextInput({ text: this.startHour }).type(InputType.Number).enabled(!this.busy && this.ready).onChange((value: string) => this.startHour = value)
        Text(this.tr('白天间隔（分钟）')).width('100%')
        TextInput({ text: this.dayInterval }).type(InputType.Number).enabled(!this.busy && this.ready).onChange((value: string) => this.dayInterval = value)
        Text(this.tr('夜间间隔（分钟）')).width('100%')
        TextInput({ text: this.nightInterval }).type(InputType.Number).enabled(!this.busy && this.ready).onChange((value: string) => this.nightInterval = value)
        Button(this.tr('保存')).enabled(!this.busy && this.ready).onClick(() => this.save())
      } else {
        if (this.pulse) {
          Text(`${this.tr('血瘀')} ${this.pulse.bloodStasis} · ${this.tr('气血')} ${this.pulse.qiBlood} · ${this.tr('湿气')} ${this.pulse.dampness}`).fontSize(18)
          Text(this.tr('手表返回值，历史时间未确认')).fontSize(13).fontColor('#716860')
        } else if (!this.busy) { Text(this.tr('暂无记录')) }
        Button(this.tr('手动测量')).enabled(!this.busy && this.ready).onClick(() => this.measure())
      }
      Button(this.tr('刷新')).enabled(!this.busy).onClick(() => this.load())
    }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)
  }
}
