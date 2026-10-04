import { saydianApi } from '../services/SaydianApi';
import { GlobalCareMember, GlobalCareWrite, GLOBAL_VIEW_METRICS, GLOBAL_METRIC_TITLES } from '../model/GlobalHealthViews';
import { HealthRecord, HealthValue } from '../model/WearableContracts';
import { localDateKey, TrendPeriod, trendWindow, shiftTrendDay, trendFieldNames, trendSummary } from '../model/HealthTrend';
import { DisplayUnits, displayNumber, displayHealthValue } from '../model/DisplayPreferences';
import { appText } from '../model/GlobalLocale';
import { HealthTrendChart } from './HealthTrendChart';
import { EcgWaveformView } from './EcgWaveformView';

@Component
export struct GlobalCarePage {
  @Prop locale: string = 'en';
  private tr(text: string): string { return appText(text, this.locale); }
  @Prop @Watch('foregroundChanged') foreground: boolean = true;
  @Prop units: DisplayUnits = { distance: 'km', temperature: 'c' };
  @State private members: GlobalCareMember[] = [];
  @State private selected: string = '';
  @State private mode: string = 'overview';
  @State private metrics: string[] = [];
  @State private overview: HealthRecord[] = [];
  @State private records: HealthRecord[] = [];
  @State private selectedMetric: string = '';
  @State private period: TrendPeriod = 'day';
  @State private day: string = localDateKey();
  @State private loading: boolean = false;
  @State private busy: boolean = false;
  @State private message: string = '';
  @State private identifier: string = '';
  @State private sharingId: string = '';
  @State private sharing: string[] = [];
  @State private selectedRecord: HealthRecord | undefined = undefined;
  private generation: number = 0;
  private release: (() => void) | undefined = undefined;
  private permissionTimer: number = -1;
  private permissionReading: boolean = false;
  aboutToAppear(): void {
    this.release = saydianApi.observeSession(() => this.clear()); this.reload();
    this.foregroundChanged();
  }
  aboutToDisappear(): void { this.stopPermissionTimer(); this.release?.(); this.clear(); }
  private stopPermissionTimer(): void {
    if (this.permissionTimer >= 0) clearInterval(this.permissionTimer); this.permissionTimer = -1;
  }
  private foregroundChanged(): void {
    this.stopPermissionTimer();
    if (!this.foreground) { ++this.generation; this.selectedRecord = undefined; this.records = []; this.overview = []; this.metrics = []; this.loading = false; this.mode = 'overview'; return; }
    this.checkPermission();
    this.permissionTimer = setInterval(() => this.checkPermission(), 30000);
  }
  private async checkPermission(): Promise<void> {
    if (!this.foreground || !this.selected || this.loading || this.busy || this.permissionReading || this.mode === 'manage') return;
    const epoch = this.generation; const member = this.selected; this.permissionReading = true;
    try {
      const summary = await saydianApi.globalCareSummary(member);
      if (epoch !== this.generation || member !== this.selected || !this.foreground) return;
      this.metrics = summary.metrics; this.overview = summary.records;
      if (this.selectedMetric && !this.metrics.includes(this.selectedMetric)) throw new Error('Permission changed');
    } catch {
      if (epoch === this.generation) { ++this.generation; this.selectedRecord = undefined; this.records = []; this.overview = []; this.metrics = []; this.mode = 'overview'; this.message = this.tr('授权失效或加载失败，请刷新'); }
    } finally { this.permissionReading = false; }
  }
  private clear(): void {
    ++this.generation; this.members = []; this.selected = ''; this.metrics = []; this.overview = []; this.records = [];
    this.selectedRecord = undefined; this.sharingId = ''; this.sharing = []; this.mode = 'overview'; this.message = ''; this.loading = false;
  }
  private activeMembers(): GlobalCareMember[] { return this.members.filter(member => member.direction === 'sent' && member.status === 'active'); }
  private title(metric: string): string {
    return this.tr(GLOBAL_METRIC_TITLES[metric] ?? metric);
  }
  private text(record?: HealthRecord): string {
    return record ? record.values.map((raw: HealthValue) => {
      const value = displayHealthValue(raw, this.units); return `${this.tr(value.name)} ${displayNumber(value.value)} ${this.tr(value.unit)}`;
    }).join(' · ') : this.tr('暂无记录');
  }
  private latest(metric: string): HealthRecord | undefined { return this.overview.find(record => record.serverMetric === metric); }
  private date(record?: HealthRecord): string { return record ? new Date(record.timestamp).toLocaleString() : ''; }
  private async reload(): Promise<void> {
    const epoch = ++this.generation; this.loading = true; this.message = ''; this.overview = []; this.records = []; this.metrics = []; this.selectedRecord = undefined;
    try {
      const members = await saydianApi.globalCareRelationships(); if (epoch !== this.generation) return; this.members = members;
      if (!this.activeMembers().some(member => member.id === this.selected)) this.selected = this.activeMembers()[0]?.id ?? '';
      if (this.selected && this.mode === 'overview') {
        const result = await saydianApi.globalCareSummary(this.selected); if (epoch !== this.generation) return;
        this.metrics = result.metrics; this.overview = result.records;
      }
    } catch { if (epoch === this.generation) { this.metrics = []; this.overview = []; this.records = []; this.message = this.tr('加载失败，重试'); } }
    finally { if (epoch === this.generation) this.loading = false; }
  }
  private async details(metric: string): Promise<void> {
    if (!this.metrics.includes(metric) || !this.selected) return;
    const epoch = ++this.generation; const member = this.selected; this.selectedMetric = metric; this.mode = 'detail';
    this.selectedRecord = undefined; this.records = []; this.loading = true; this.message = '';
    try {
      const window = trendWindow(this.day, this.period);
      const records = await saydianApi.globalCareRecords(member, metric, window.start, window.end);
      if (epoch === this.generation && this.selected === member) this.records = records;
    } catch { if (epoch === this.generation) { this.records = []; this.metrics = []; this.message = this.tr('授权失效或加载失败，请刷新'); } }
    finally { if (epoch === this.generation) this.loading = false; }
  }
  private async write(id: string, action: 'respond' | 'permissions' | 'revoke', value?: GlobalCareWrite): Promise<void> {
    if (this.busy) return; this.busy = true; this.message = ''; const owner = saydianApi.healthSession();
    try {
      await saydianApi.globalCareWrite(id, action, value);
      if (owner.generation !== saydianApi.healthSession().generation) return;
      this.sharingId = ''; this.mode = 'manage'; await this.reload();
    } catch { if (owner.generation === saydianApi.healthSession().generation) this.message = this.tr('操作失败，重试'); }
    finally { this.busy = false; }
  }
  private revoke(member: GlobalCareMember): void {
    AlertDialog.show({ title: this.tr('停止共享'), message: this.tr('停止后将无法查看共享数据'),
      primaryButton: { value: this.tr('取消'), action: (): void => {} },
      secondaryButton: { value: this.tr('停止共享'), action: (): void => { this.write(member.id, 'revoke'); } } });
  }
  private toggle(metric: string): void { this.sharing = this.sharing.includes(metric) ? this.sharing.filter(value => value !== metric) : this.sharing.concat([metric]); }
  private async invite(): Promise<void> {
    if (this.busy) return; this.busy = true; const epoch = this.generation;
    try { await saydianApi.globalCareInvite(this.identifier); if (epoch !== this.generation) return; this.identifier = ''; await this.reload(); }
    catch (error) { if (epoch === this.generation) this.message = this.tr((error as Error).message); }
    finally { this.busy = false; }
  }
  private previous(direction: number): void { this.day = shiftTrendDay(this.day, this.period, direction); this.details(this.selectedMetric); }
  @Builder
  Details() {
    Row({ space: 6 }) {
      ForEach(['day', 'week', 'month'], (period: string) => {
        Button(this.tr(period === 'day' ? '日' : period === 'week' ? '周' : '月')).layoutWeight(1)
          .backgroundColor(this.period === period ? '#DEC58D' : '#F7F3ED').fontColor('#302B25')
          .onClick(() => { this.period = period as TrendPeriod; this.details(this.selectedMetric); })
      })
    }.width('100%')
    Row({ space: 8 }) {
      Button('‹').onClick(() => this.previous(-1))
      Text(trendWindow(this.day, this.period).label).fontSize(15).layoutWeight(1).textAlign(TextAlign.Center)
        .onClick(() => DatePickerDialog.show({ selected: new Date(`${this.day}T12:00:00`), end: new Date(),
          onDateAccept: (date: Date): void => { this.day = localDateKey(date.getTime()); this.details(this.selectedMetric); } }))
      Button('›').enabled(trendWindow(this.day, this.period).end <= Date.now()).onClick(() => this.previous(1))
    }.width('100%')
    if (this.selectedMetric !== 'ecg') {
      ForEach(trendFieldNames(this.records), (name: string) => {
        Column({ space: 8 }) {
          Text(this.tr(name)).fontSize(16).fontWeight(FontWeight.Bold).width('100%')
          Text(`${this.tr('平均')} ${displayNumber(trendSummary(this.records, [], name, this.units)?.average ?? 0)} · ` +
            `${this.tr('最小')} ${displayNumber(trendSummary(this.records, [], name, this.units)?.min ?? 0)} · ` +
            `${this.tr('最大')} ${displayNumber(trendSummary(this.records, [], name, this.units)?.max ?? 0)}`).fontSize(14)
        }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)
      }, (name: string) => name)
      if (this.records.length && this.selectedMetric !== 'sleep') {
        HealthTrendChart({ records: this.records, period: this.period, units: this.units,
          names: this.selectedMetric === 'blood_pressure' ? ['收缩压', '舒张压'] : trendFieldNames(this.records).slice(0, 1) })
      }
    }
    ForEach(this.records, (record: HealthRecord) => {
      Column({ space: 8 }) {
        Text(this.date(record)).fontSize(13).fontColor('#716860').width('100%')
        Text(this.text(record)).fontSize(16).width('100%')
        if (record.metric === 'sleep') {
          Row({ space: 2 }) {
            ForEach(record.values.filter(value => ['深睡', '浅睡', '清醒'].includes(value.name)), (value: HealthValue) => {
              Column().height(24).layoutWeight(Math.max(0.1, value.value)).backgroundColor(value.name === '深睡' ? '#6451A4' : value.name === '浅睡' ? '#AB9CD1' : '#E2C68A')
            })
          }.width('100%').borderRadius(6).clip(true)
        }
        if (record.metric === 'ecg') { Button(this.tr('查看波形')).onClick(() => { this.selectedRecord = record; this.mode = 'record'; }) }
      }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)
    }, (record: HealthRecord) => record.id)
    if (!this.loading && !this.records.length) { Text(this.tr('暂无记录')).fontSize(16) }
  }
  build() {
    Column({ space: 14 }) {
      Row() {
        if (this.mode !== 'overview') {
          Button(this.tr('返回')).onClick(() => {
            if (this.mode === 'record') { this.selectedRecord = undefined; this.details(this.selectedMetric); }
            else { this.mode = 'overview'; this.sharingId = ''; this.reload(); }
          })
        }
        Text(this.mode === 'detail' || this.mode === 'record' ? this.title(this.selectedMetric) : this.tr('远程关爱')).fontSize(21).fontWeight(FontWeight.Bold).layoutWeight(1)
        if (this.mode === 'overview') { Button(this.tr('管理')).onClick(() => { ++this.generation; this.overview = []; this.mode = 'manage'; this.reload(); }) }
      }.width('100%')
      if (this.loading) { LoadingProgress().width(36).height(36) }
      if (this.message) { Text(this.message).fontColor('#A04F28'); Button(this.tr('重试')).onClick(() => this.mode === 'detail' ? this.details(this.selectedMetric) : this.reload()) }
      if (this.mode === 'overview') {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.activeMembers(), (member: GlobalCareMember) => {
              Button(member.name).backgroundColor(this.selected === member.id ? '#DEC58D' : '#F7F3ED').fontColor('#302B25')
                .onClick(() => { this.selected = member.id; this.reload(); })
            }, (member: GlobalCareMember) => member.id)
          }
        }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        if (!this.loading && !this.activeMembers().length) { Text(this.tr('暂无成员')).fontColor('#716860') }
        ForEach(this.metrics.filter(metric => !!GLOBAL_VIEW_METRICS[metric]), (metric: string) => {
          Column({ space: 8 }) {
            Text(this.title(metric)).fontSize(18).fontWeight(FontWeight.Bold).width('100%')
            Text(this.text(this.latest(metric))).fontSize(16).width('100%')
            Text(this.date(this.latest(metric))).fontSize(13).fontColor('#716860').width('100%')
          }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(18).border({ width: 1, color: '#E4DDD3' })
            .onClick(() => this.details(metric)).id(`global_care_${metric}`)
        }, (metric: string) => metric)
        if (this.selected && !this.loading && !this.metrics.length) { Text(this.tr('暂无授权指标')).fontColor('#716860') }
        Button(this.tr('刷新')).onClick(() => this.reload())
      } else if (this.mode === 'manage') {
        TextInput({ text: this.identifier, placeholder: this.tr('邮箱或国际手机号') }).onChange((value: string) => this.identifier = value)
        Button(this.tr('邀请')).enabled(!this.busy && !!this.identifier.trim()).onClick(() => this.invite())
        ForEach(this.members, (member: GlobalCareMember) => {
          Column({ space: 8 }) {
            Text(member.name).fontSize(18).fontWeight(FontWeight.Bold).width('100%')
            Text(this.tr(member.status === 'pending' ? '待处理' : member.status === 'active' ? '已共享' : '已停止')).fontColor('#716860')
            if (member.direction === 'received' && member.status === 'pending') {
              Row({ space: 8 }) {
                Button(this.tr('同意')).enabled(!this.busy).onClick(() => this.write(member.id, 'respond', { accepted: true }))
                Button(this.tr('拒绝')).enabled(!this.busy).onClick(() => this.write(member.id, 'respond', { accepted: false }))
              }
            }
            if (member.status === 'active') {
              if (member.direction === 'received') { Button(this.tr('共享权限')).onClick(() => { this.sharingId = member.id; this.sharing = member.metrics.slice(); }) }
              Button(this.tr('停止共享')).enabled(!this.busy).onClick(() => this.revoke(member))
            }
            if (this.sharingId === member.id) {
              ForEach(Object.keys(GLOBAL_VIEW_METRICS), (metric: string) => {
                Row() {
                  Text(this.title(metric)).layoutWeight(1)
                  Toggle({ type: ToggleType.Switch, isOn: this.sharing.includes(metric) }).onChange(() => this.toggle(metric))
                }.width('100%')
              })
              Button(this.tr('保存')).enabled(!this.busy).onClick(() => this.write(member.id, 'permissions', { metrics: this.sharing }))
            }
          }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)
        }, (member: GlobalCareMember) => member.id)
      } else if (this.mode === 'detail') { this.Details() }
      else if (this.mode === 'record' && this.selectedRecord) { EcgWaveformView({ record: this.selectedRecord, relationshipId: this.selected, locale: this.locale }) }
    }.width('100%')
  }
}
