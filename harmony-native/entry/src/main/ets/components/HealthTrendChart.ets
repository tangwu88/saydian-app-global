import { HealthRecord } from '../model/WearableContracts';
import { TrendPeriod, TrendSeries, trendSeries, trendFieldNames, plotSeries, spreadChartPoints } from '../model/HealthTrend';
import { DisplayUnits } from '../model/DisplayPreferences';

@Component
export struct HealthTrendChart {
  @Prop records: HealthRecord[] = [];
  @Prop period: TrendPeriod = 'day';
  @Prop units: DisplayUnits = { distance: 'km', temperature: 'c' };
  @Prop names: string[] = [];
  onInspect: (x: number, width: number) => void = (): void => {};
  @State private chartWidth: number = 320;
  private fields(): string[] { return (this.names.length ? this.names : trendFieldNames(this.records)).slice(0, 2); }
  private series(name: string): TrendSeries { return plotSeries(trendSeries(this.records, name, this.period, this.units)); }
  private values(): number[] { return this.fields().map((name: string) => this.series(name).points.map(point => point.value)).flat(); }
  private maximum(): number { return this.values().reduce((value: number, next: number) => Math.max(value, next), 1); }
  private minimum(): number { return this.values().reduce((value: number, next: number) => Math.min(value, next), this.maximum()); }
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.fields(), (name: string, index: number) => {
        if (this.records[0]?.metric === 'activity') {
          ForEach(spreadChartPoints(this.series(name), 0, this.maximum(), this.chartWidth), (point: number[]) => {
            Column().width(8).height(Math.max(1, 144 - point[1])).backgroundColor('#B84C4B').position({ x: Math.max(0, Math.min(this.chartWidth - 8, point[0])), y: point[1] })
          })
        } else {
          if (this.series(name).points.length > 1) {
            Polyline({ width: this.chartWidth, height: 160 }).points(spreadChartPoints(this.series(name), this.minimum(), this.maximum(), this.chartWidth))
              .fillOpacity(0).stroke(index === 0 ? '#B84C4B' : '#4F7CA1').strokeWidth(2)
          }
          ForEach(spreadChartPoints(this.series(name), this.minimum(), this.maximum(), this.chartWidth), (point: number[]) => {
            Column().width(6).height(6).borderRadius(3).backgroundColor(index === 0 ? '#B84C4B' : '#4F7CA1').position({ x: point[0] - 3, y: point[1] - 3 })
          })
        }
      }, (name: string) => name)
    }.width('100%').height(160).onAreaChange((oldArea: Area, area: Area) => this.chartWidth = Number(area.width))
      .onTouch((event: TouchEvent) => {
        if ((event.type === TouchType.Down || event.type === TouchType.Move) && event.touches.length) this.onInspect(event.touches[0].x, this.chartWidth);
      }).id('health_trend_chart')
  }
}
