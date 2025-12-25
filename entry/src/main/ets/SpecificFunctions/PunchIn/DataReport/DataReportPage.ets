import { AppStorageV2, componentSnapshot } from "@kit.ArkUI";
import common from '@ohos.app.ability.common';
import { UserPreferencesManager } from "common";
import { image } from "@kit.ImageKit";
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit'
import promptAction from '@ohos.promptAction';

// --- 接口定义 ---
interface DailyStats {
  date: string;
  total: number;
  correct: number;
}

interface ChartData {
  dateStr: string;
  fullDate: string;
  count: number;
  accuracy: number;
  isToday: boolean;
  xPos: number;
  yPos: number;
}

@Builder
export function DataReportPageBuilder() {
  DataReportPage()
}

@Component
export struct DataReportPage {
  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack, () => new NavPathStack())!;
  @StorageLink('userId') userId: string = '';

  private userPrefs: UserPreferencesManager = new UserPreferencesManager();
  private context = getContext(this) as common.UIAbilityContext;

  // --- 核心数据 ---
  @State todayTotal: number = 0;
  @State todayGoal: number = 0;
  @State accuracyStr: string = '0.00%';
  @State accuracyVal: number = 0;
  @State totalPunchDays: number = 0;
  @State consecutiveDays: number = 0;

  // --- 图表数据 ---
  @State last7DaysData: ChartData[] = [];
  @State maxCountValue: number = 10;
  @State chartMode: number = 0; // 0=答题数, 1=正确率

  // --- 交互状态 ---
  @State selectedIndex: number = -1;
  @State showShareModal: boolean = false;
  private shareImagePixMap: image.PixelMap | undefined = undefined;

  // --- 布局常量 ---
  @State chartContainerWidth: number = 300;
  private readonly CHART_HEIGHT: number = 130;
  private readonly TOP_PADDING: number = 40;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context2D: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private getDateFormat(date: Date): string {
    return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
  }

  async loadData() {
    if (!this.userId) return;
    await this.userPrefs.initUser(this.context, this.userId);
    const todayStr = this.getDateFormat(new Date());

    // 1. 读取今日实时数据（内存/缓存中）
    const dailyStatsJson = await this.userPrefs.getValue<string>('daily_answer_stats', '{}');
    let tempTotal = 0, tempCorrect = 0;
    try {
      const stats = JSON.parse(dailyStatsJson) as DailyStats;
      // 只有当缓存里的日期是今天时，才算作今天的实时数据
      if (stats && stats.date === todayStr) {
        tempTotal = Number(stats.total) || 0;
        tempCorrect = Number(stats.correct) || 0;
      }
    } catch (e) {}

    let finalStr = '0.00%', finalVal = 0;
    if (tempTotal > 0) {
      const rate = (tempCorrect / tempTotal) * 100;
      finalStr = rate.toFixed(2) + '%';
      finalVal = Number(rate.toFixed(2));
    }

    this.todayTotal = tempTotal;
    this.accuracyStr = finalStr;
    this.accuracyVal = finalVal;

    const savedGoal = await this.userPrefs.getValue<number>(`goal_${todayStr}`, 0);
    this.todayGoal = Number(savedGoal) || 0;

    // 2. 计算打卡统计
    await this.calculatePunchStats();

    // 3. 生成图表（传入今天的实时数据，剩下的去读历史存档）
    await this.generateChartData(tempTotal, finalVal);
  }

  async calculatePunchStats() {
    const historyList = await this.userPrefs.getValue<string[]>('punch_history_list', []);

    const lastPunchDate = await this.userPrefs.getValue<string>('last_punch_date', '');
    const punchedSet = new Set<string>(historyList);
    if (lastPunchDate) punchedSet.add(lastPunchDate);

    this.totalPunchDays = punchedSet.size;

    let streak = 0;
    const now = new Date();
    const todayStr = this.getDateFormat(now);
    const yesterdayDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
    const yesterdayStr = this.getDateFormat(yesterdayDate);

    let checkDate: Date;
    if (punchedSet.has(todayStr)) checkDate = now;
    else if (punchedSet.has(yesterdayStr)) checkDate = yesterdayDate;
    else {
      this.consecutiveDays = 0;
      return;
    }

    while (punchedSet.has(this.getDateFormat(checkDate))) {
      streak++;
      checkDate.setDate(checkDate.getDate() - 1);
    }
    this.consecutiveDays = streak;
  }

  /**
   * 核心修复：生成图表数据
   * 暴力匹配所有可能的日期 Key 格式，确保读到数据
   */
  async generateChartData(todayCount: number, todayAcc: number) {
    const data: ChartData[] = [];
    const now = new Date(); // 当前时间
    const oneDayMs = 24 * 60 * 60 * 1000;
    let maxCount = 0;

    const colWidth = this.chartContainerWidth / 7;

    for (let i = 6; i >= 0; i--) {
      // 使用时间戳倒推，最精准，不会出跨月错
      const d = new Date(now.getTime() - (i * oneDayMs));

      const day = d.getDate();
      const month = d.getMonth() + 1;
      const year = d.getFullYear();

      const dateStr = `${month}-${day}`; // X轴显示简写
      const fullDate = `${year}-${month}-${day}`; // 完整日期

      let count = 0;
      let accuracy = 0;

      if (i === 0) {
        // 如果是今天，优先使用传入的实时数据
        count = todayCount;
        accuracy = todayAcc;
      } else {
        // --- 核心修复：暴力尝试读取 ---
        // 尝试 Key 1: stats_2024-5-1 (无补零)
        const k1 = `stats_${year}-${month}-${day}`;
        // 尝试 Key 2: stats_2024-05-01 (全补零)
        const mPad = month < 10 ? `0${month}` : month;
        const dPad = day < 10 ? `0${day}` : day;
        const k2 = `stats_${year}-${mPad}-${dPad}`;
        // 尝试 Key 3: stats_2024-5-01 (只补日)
        const k3 = `stats_${year}-${month}-${dPad}`;
        // 尝试 Key 4: stats_2024-05-1 (只补月)
        const k4 = `stats_${year}-${mPad}-${day}`;

        // 依次读取，读到为止
        let jsonStr = await this.userPrefs.getValue<string>(k1, '');
        if (!jsonStr || jsonStr === '{}') jsonStr = await this.userPrefs.getValue<string>(k2, '');
        if (!jsonStr || jsonStr === '{}') jsonStr = await this.userPrefs.getValue<string>(k3, '');
        if (!jsonStr || jsonStr === '{}') jsonStr = await this.userPrefs.getValue<string>(k4, '');

        if (jsonStr && jsonStr !== '{}') {
          try {
            const stats = JSON.parse(jsonStr) as DailyStats;
            if (stats) {
              count = Number(stats.total) || 0;
              const correct = Number(stats.correct) || 0;
              if (count > 0) {
                accuracy = Number(((correct / count) * 100).toFixed(0));
              }
            }
          } catch (e) {
            console.error('Parse stats error:', e);
          }
        }
      }

      if (count > maxCount) maxCount = count;

      const index = 6 - i;
      const x = (index * colWidth) + (colWidth / 2);
      const y = (1 - accuracy / 100) * this.CHART_HEIGHT;

      data.push({
        dateStr,
        fullDate,
        count,
        accuracy,
        isToday: (i === 0),
        xPos: x,
        yPos: y
      });
    }

    this.last7DaysData = data;
    this.maxCountValue = maxCount < 10 ? 10 : maxCount + 5;

    // 强制刷新一下画布
    if (this.chartMode === 1) {
      setTimeout(() => { this.drawLines(); }, 100);
    }
  }

  drawLines() {
    if (this.last7DaysData.length === 0) return;
    const ctx = this.context2D;
    const width = this.chartContainerWidth;
    const height = this.CHART_HEIGHT;

    ctx.clearRect(0, 0, width, height);

    if (this.chartMode !== 1) return;

    ctx.beginPath();
    ctx.lineWidth = 2;
    ctx.strokeStyle = '#4caf50';
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    this.last7DaysData.forEach((item, index) => {
      if (index === 0) ctx.moveTo(item.xPos, item.yPos);
      else ctx.lineTo(item.xPos, item.yPos);
    });
    ctx.stroke();
  }

  takeSnapshot() {
    componentSnapshot.get('PAGE_STATS_ROOT', (error: Error, pixmap: image.PixelMap) => {
      if (!error) {
        this.shareImagePixMap = pixmap;
        this.showShareModal = true;
      }
    })
  }

  async shareToSystem() {
    if (!this.shareImagePixMap) return;
    try {
      const fileName = `report_${new Date().getTime()}.jpg`;
      const filePath = this.context.cacheDir + '/' + fileName;
      const file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      const packer = image.createImagePacker();
      const packOpts: image.PackingOption = { format: 'image/jpeg', quality: 98 };
      await packer.packToFile(this.shareImagePixMap, file.fd, packOpts);
      fs.closeSync(file.fd);
      packer.release();

      const uri = fileUri.getUriFromPath(filePath);
      const sharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.JPEG, uri: uri, title: '我的学习报告', description: '快来看看我的学习数据吧'
      });
      sharedData.addRecord({ utd: utd.UniformDataType.JPEG, uri: uri, title: fileName });
      const controller = new systemShare.ShareController(sharedData);
      controller.show(this.context, { previewMode: systemShare.SharePreviewMode.DEFAULT, selectionMode: systemShare.SelectionMode.SINGLE });
    } catch (error) {
      promptAction.showToast({ message: '分享调起失败，请重试' });
    }
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          this.HeaderSection()
          Scroll() {
            Column({ space: 16 }) {
              this.RingStatsSection()
              this.StatsCardSection()
              this.TrendChartSection()
            }
            .padding(16)
            .id('PAGE_STATS_ROOT')
          }
          .layoutWeight(1).width('100%').align(Alignment.Top).scrollBar(BarState.Off)
        }
        .width('100%').height('100%').backgroundColor('#f5f7fa')

        if (this.selectedIndex !== -1) {
          Column()
            .width('100%').height('100%').backgroundColor(Color.Transparent).zIndex(100)
            .onClick(() => { this.selectedIndex = -1; })
        }

        if (this.showShareModal && this.shareImagePixMap) {
          Stack() {
            Rect().width('100%').height('100%').fill('rgba(0,0,0,0.85)').onClick(() => this.showShareModal = false)
            Column({ space: 24 }) {
              Text('生成海报成功').fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White)
              Image(this.shareImagePixMap).width('75%').objectFit(ImageFit.Contain).borderRadius(12).shadow({ radius: 20, color: 'rgba(0,0,0,0.5)' })
              Row({ space: 20 }) {
                Button('关闭').backgroundColor('rgba(255,255,255,0.2)').fontColor(Color.White).width(120).onClick(() => this.showShareModal = false)
                Button('立即分享').backgroundColor('#4caf50').fontColor(Color.White).width(120).onClick(() => { this.showShareModal = false; this.shareToSystem(); })
              }
            }
            .justifyContent(FlexAlign.Center).width('100%').height('100%')
          }
          .zIndex(9999).transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
        }
      }
    }
    .hideTitleBar(true)
    .onShown(() => {
      this.loadData();
    })
  }

  @Builder HeaderSection() {
    Row() {
      Image($r('app.media.iv_back')).width(30).onClick(() => { this.pathStack.pop(); })
      Text('学习情况').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 16 })
      Image($r('app.media.ic_share')).width(30).fillColor('#333').onClick(() => this.takeSnapshot())
    }
    .width('100%').padding({ left: 16, right: 16, top: 40, bottom: 10 }).backgroundColor(Color.White).justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder RingStatsSection() {
    Row({ space: 12 }) {
      Column() {
        Text('今日正确率').fontSize(14).fontColor('#666').margin({ bottom: 15 })
        Stack() {
          Progress({ value: this.accuracyVal, total: 100, type: ProgressType.Ring }).width(100).height(100).color(this.todayTotal > 0 ? '#4caf50' : '#d0d0d0').backgroundColor('#f0f0f0').style({ strokeWidth: 10 })
          Column() { Text(this.accuracyStr).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333') }
        }
        Text(this.todayTotal > 0 ? '保持专注' : '暂无数据').fontSize(12).fontColor('#999').margin({ top: 10 })
      }
      .layoutWeight(1).height(180).backgroundColor(Color.White).borderRadius(16).justifyContent(FlexAlign.Center).shadow({ radius: 8, color: 'rgba(0,0,0,0.03)', offsetY: 2 })

      Column() {
        Text(this.todayGoal > 0 ? '今日目标进度' : '今日答题数').fontSize(14).fontColor('#666').margin({ bottom: 15 })
        Stack() {
          Progress({ value: this.todayTotal, total: this.todayGoal > 0 ? this.todayGoal : 100, type: ProgressType.Ring }).width(100).height(100).color(this.todayGoal > 0 ? '#2196f3' : '#f0f0f0').backgroundColor('#f0f0f0').style({ strokeWidth: 10 })
          Column() { Text(this.todayGoal > 0 ? `${this.todayTotal}/${this.todayGoal}` : `${this.todayTotal}`).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333') }
        }
        Text(this.todayGoal > 0 ? (this.todayTotal >= this.todayGoal ? '目标已达成' : '加油') : '未制定计划').fontSize(12).fontColor('#999').margin({ top: 10 })
      }
      .layoutWeight(1).height(180).backgroundColor(Color.White).borderRadius(16).justifyContent(FlexAlign.Center).shadow({ radius: 8, color: 'rgba(0,0,0,0.03)', offsetY: 2 })
    }
    .width('100%')
  }

  @Builder StatsCardSection() {
    Row({ space: 12 }) {
      Row() {
        Column().width(4).height(30).borderRadius(2).backgroundColor('#ff9800').margin({ right: 16 })
        Column({ space: 6 }) {
          Text('累计打卡').fontSize(13).fontColor('#666')
          Row({ space: 4 }) {
            Text(`${this.totalPunchDays}`).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#333')
            Text('天').fontSize(12).fontColor('#999').margin({ bottom: 4 })
          }.alignItems(VerticalAlign.Bottom)
        }.alignItems(HorizontalAlign.Start)
        Blank()
        Image($r('app.media.like')).width(24).opacity(0.2)
      }
      .padding({ left: 16, right: 16 }).layoutWeight(1).height(90).backgroundColor(Color.White).borderRadius(16).shadow({ radius: 8, color: 'rgba(0,0,0,0.02)', offsetY: 2 })

      Row() {
        Column().width(4).height(30).borderRadius(2).backgroundColor('#e91e63').margin({ right: 16 })
        Column({ space: 6 }) {
          Text('连续坚持').fontSize(13).fontColor('#666')
          Row({ space: 4 }) {
            Text(`${this.consecutiveDays}`).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#333')
            Text('天').fontSize(12).fontColor('#999').margin({ bottom: 4 })
          }.alignItems(VerticalAlign.Bottom)
        }.alignItems(HorizontalAlign.Start)
        Blank()
        Image($r('app.media.punch_in_1')).width(24).opacity(0.2)
      }
      .padding({ left: 16, right: 16 }).layoutWeight(1).height(90).backgroundColor(Color.White).borderRadius(16).shadow({ radius: 8, color: 'rgba(0,0,0,0.02)', offsetY: 2 })
    }
    .width('100%')
  }

  @Builder TrendChartSection() {
    Column() {
      Row() {
        Text('近7天学习趋势').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333')
        Blank()
        Row({ space: 10 }) {
          Text('答题数')
            .fontSize(12).fontColor(this.chartMode === 0 ? '#fff' : '#666').backgroundColor(this.chartMode === 0 ? '#7ed4ba' : '#f0f0f0').padding({ left: 12, right: 12, top: 6, bottom: 6 }).borderRadius(12)
            .onClick(() => { this.chartMode = 0; this.selectedIndex = -1; this.context2D.clearRect(0,0, this.chartContainerWidth, this.CHART_HEIGHT); })
          Text('正确率')
            .fontSize(12).fontColor(this.chartMode === 1 ? '#fff' : '#666').backgroundColor(this.chartMode === 1 ? '#4caf50' : '#f0f0f0').padding({ left: 12, right: 12, top: 6, bottom: 6 }).borderRadius(12)
            .onClick(() => { this.chartMode = 1; this.selectedIndex = -1; this.drawLines() })
        }
      }.width('100%').margin({ bottom: 20 })

      Stack({ alignContent: Alignment.TopStart }) {
        Column() { Divider().color('#f5f5f5'); Blank(); Divider().color('#f5f5f5'); Blank(); Divider().color('#f5f5f5') }.width('100%').height(this.CHART_HEIGHT).margin({ top: this.TOP_PADDING })
        Column() {
          Stack({ alignContent: Alignment.TopStart }) {
            if (this.chartMode === 1) {
              Canvas(this.context2D).width('100%').height('100%').hitTestBehavior(HitTestMode.None).onReady(() => this.drawLines())
              ForEach(this.last7DaysData, (item: ChartData, index: number) => {
                Stack() {
                  Circle({ width: 8, height: 8 }).fill(Color.White).stroke('#4caf50').strokeWidth(2)
                  if (this.selectedIndex === index) { Circle({ width: 16, height: 16 }).fill('#4caf50').fillOpacity(0.3) }
                }
                .width(24).height(24).position({ x: item.xPos, y: item.yPos }).markAnchor({ x: '50%', y: '50%' }).onClick(() => { this.selectedIndex = index; })
                Text(`${item.accuracy.toFixed(0)}%`).fontSize(16).fontColor('#4caf50').fontWeight(FontWeight.Bold).position({ x: item.xPos, y: item.yPos }).markAnchor({ x: '50%', y: '100%' }).offset({ y: -25 }).hitTestBehavior(HitTestMode.None)
              })
            } else {
              Row() {
                ForEach(this.last7DaysData, (item: ChartData, index: number) => {
                  Column() {
                    Column() {
                      if (item.count > 0) { Text(`${item.count}`).fontSize(16).fontColor(this.selectedIndex === index ? '#ff9800' : '#999').fontWeight(this.selectedIndex === index ? FontWeight.Bold : FontWeight.Normal).margin({ bottom: 4 }) }
                      if (item.count > 0) {
                        Column().width(12).height(`${(item.count / (this.maxCountValue || 1)) * 100}%`).backgroundColor(this.selectedIndex === index ? '#ff9800' : (item.isToday ? '#7ed4ba' : '#e0e0e0')).borderRadius({ topLeft: 6, topRight: 6 }).onClick(() => { this.selectedIndex = index; })
                      } else {
                        Column().width(12).height(4).backgroundColor('#f5f5f5').borderRadius(2)
                      }
                    }
                    .height('100%').width('100%').justifyContent(FlexAlign.End).alignItems(HorizontalAlign.Center)
                  }
                  .height('100%').layoutWeight(1)
                })
              }
              .width('100%').height(this.CHART_HEIGHT).alignItems(VerticalAlign.Bottom)
            }
          }
          .width('100%').height(this.CHART_HEIGHT)

          Row() {
            ForEach(this.last7DaysData, (item: ChartData) => {
              Text(item.dateStr).fontSize(10).fontColor(item.isToday ? '#333' : '#bbb')
                .fontWeight(item.isToday ? FontWeight.Bold : FontWeight.Normal)
                .width('100%').textAlign(TextAlign.Center).layoutWeight(1)
            })
          }.width('100%').margin({ top: 8 })
        }
        .width('100%')
        .padding({ top: this.TOP_PADDING })

        if (this.selectedIndex >= 0 && this.selectedIndex < this.last7DaysData.length) {
          Column({ space: 4 }) {
            Text(this.last7DaysData[this.selectedIndex].fullDate)
              .fontSize(10).fontColor(Color.White).opacity(0.8)
            Text(`答题数: ${this.last7DaysData[this.selectedIndex].count}`)
              .fontSize(12).fontWeight(FontWeight.Bold).fontColor(Color.White)
            Text(`正确率: ${this.last7DaysData[this.selectedIndex].accuracy.toFixed(1)}%`)
              .fontSize(12).fontWeight(FontWeight.Bold).fontColor(Color.White)
          }
          .alignItems(HorizontalAlign.Start)
          .padding(8)
          .backgroundColor('rgba(0,0,0,0.85)')
          .borderRadius(8)
          .shadow({ radius: 10, color: 'rgba(0,0,0,0.3)' })
          .zIndex(99)
          .hitTestBehavior(HitTestMode.None)
          .position({
            x: this.last7DaysData[this.selectedIndex].xPos,
            y: this.chartMode === 1
              ? this.last7DaysData[this.selectedIndex].yPos + this.TOP_PADDING
              : (this.CHART_HEIGHT - (this.last7DaysData[this.selectedIndex].count / (this.maxCountValue || 1) * this.CHART_HEIGHT)) + this.TOP_PADDING
          })
          .markAnchor({ x: '50%', y: '100%' })
          .offset({ y: -25 })
          .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
        }
      }
      .width('100%')
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.chartContainerWidth = Number(newValue.width);
        this.generateChartData(this.todayTotal, this.accuracyVal);
      })
    }
    .width('100%').padding(20).backgroundColor(Color.White).borderRadius(16)
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.03)', offsetY: 2 })
  }
}
