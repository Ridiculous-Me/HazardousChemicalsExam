import { AppStorageV2, router } from "@kit.ArkUI";
import common from '@ohos.app.ability.common';
import { UserPreferencesManager } from "common";

// --- 接口定义 ---
interface FocusRecord {
  id: string;
  startTime: number;
  endTime: number;
  duration: number;
  dateStr: string;
}

interface HistoryGroup {
  date: string;
  totalDuration: number;
  items: FocusRecord[];
  isExpanded: boolean;
}

// 【新增】图表数据接口
interface ChartItem {
  weekName: string;
  fullDate: string;
  minutes: number;
  percent: number;
}

@Builder
export function FocusHistoryPageBuilder() {
  FocusHistoryPage()
}

@Entry
@Component
export struct FocusHistoryPage {
  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack, () => new NavPathStack())!;

  @StorageLink('userId') userId: string = '';
  private userPrefs: UserPreferencesManager = new UserPreferencesManager();
  private context = getContext(this) as common.UIAbilityContext;

  @State isLoading: boolean = true;
  @State historyGroups: HistoryGroup[] = [];

  // 基础统计状态
  @State totalFocusTimeStr: string = '0分钟';
  @State todayFocusTimeStr: string = '0分钟';
  @State totalCount: number = 0;

  // 【新增】图表相关状态
  @State weekChartData: ChartItem[] = [];
  @State selectedChartIndex: number = 6; // 默认选中今天
  private chartSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private chartContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.chartSettings);
  private chartWidth: number = 0;
  private chartHeight: number = 0;

  async aboutToAppear() {
    if (this.userId) {
      await this.userPrefs.initUser(this.context, this.userId);
      await this.loadData();
    }
    this.isLoading = false;
  }

  async loadData() {
    const historyKey = 'focus_history_list';
    const rawList = await this.userPrefs.getValue<FocusRecord[]>(historyKey, []);

    // 基础统计初始化
    this.totalCount = rawList.length;
    let totalSeconds = 0;
    let todaySeconds = 0;
    const todayStr = this.getTodayStr();

    const groups: HistoryGroup[] = [];
    const map = new Map<string, HistoryGroup>();
    // 【新增】用于图表的数据映射
    const dateDurationMap = new Map<string, number>();

    for (const item of rawList) {
      totalSeconds += item.duration;
      if (item.dateStr === todayStr) {
        todaySeconds += item.duration;
      }

      // 【新增】累加每天的分钟数
      const currentMin = dateDurationMap.get(item.dateStr) || 0;
      dateDurationMap.set(item.dateStr, currentMin + Math.floor(item.duration / 60));

      if (!map.has(item.dateStr)) {
        const newGroup: HistoryGroup = {
          date: item.dateStr,
          totalDuration: 0,
          items: [],
          isExpanded: true
        };
        groups.push(newGroup);
        map.set(item.dateStr, newGroup);
      }
      const group = map.get(item.dateStr)!;
      group.items.push(item);
      group.totalDuration += item.duration;
    }

    this.historyGroups = groups;
    this.totalFocusTimeStr = this.formatDurationSmart(totalSeconds);
    this.todayFocusTimeStr = this.formatDurationSmart(todaySeconds);

    // 【新增】生成图表数据
    this.generateChartData(dateDurationMap);
  }

  // 【新增】生成最近7天图表数据
  generateChartData(dataMap: Map<string, number>) {
    const weekDays = ['日', '一', '二', '三', '四', '五', '六'];
    const tempChart: ChartItem[] = [];
    let maxMinutes = 0;

    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const dateStr = `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;

      const minutes = dataMap.get(dateStr) || 0;
      if (minutes > maxMinutes) maxMinutes = minutes;

      tempChart.push({
        weekName: i === 0 ? '今天' : weekDays[d.getDay()],
        fullDate: i === 0 ? '今天' : `${d.getMonth()+1}月${d.getDate()}日`,
        minutes: minutes,
        percent: 0
      });
    }

    const safeMax = maxMinutes === 0 ? 60 : maxMinutes * 1.25; // 留出顶部空间

    tempChart.forEach(item => {
      item.percent = item.minutes / safeMax;
    });

    this.weekChartData = tempChart;
    // 延迟绘制确保Canvas组件已准备好
    setTimeout(() => {
      this.drawChart();
    }, 100);
  }

  // 【新增】Canvas 绘图逻辑 (已修复所有视觉问题)
  drawChart() {
    if (!this.chartContext || this.weekChartData.length === 0 || this.chartWidth === 0) return;

    const ctx = this.chartContext;
    const width = this.chartWidth;
    const height = this.chartHeight;

    const paddingBottom = 25;
    const paddingTop = 20;
    const paddingSide = 15;

    const graphWidth = width - (paddingSide * 2);
    const graphHeight = height - paddingBottom - paddingTop;
    const stepX = graphWidth / (this.weekChartData.length - 1);

    ctx.clearRect(0, 0, width, height);

    // 1. 网格背景
    ctx.beginPath();
    ctx.strokeStyle = '#f5f5f5';
    ctx.lineWidth = 1;
    ctx.setLineDash([5, 5]);
    [0, 0.33, 0.66, 1].forEach((ratio: number) => {
      const y = paddingTop + graphHeight * ratio;
      ctx.moveTo(paddingSide, y);
      ctx.lineTo(width - paddingSide, y);
    });
    ctx.stroke();
    ctx.setLineDash([]);

    // 2. 坐标计算
    const points: number[][] = [];
    this.weekChartData.forEach((item, index) => {
      const x = paddingSide + (index * stepX);
      const y = paddingTop + graphHeight * (1 - item.percent);
      points.push([x, y]);
    });

    // 3. 渐变填充
    ctx.beginPath();
    if (points.length > 0) {
      ctx.moveTo(points[0][0], points[0][1]);
      for (let i = 1; i < points.length; i++) {
        const xc = (points[i][0] + points[i - 1][0]) / 2;
        const yc = (points[i][1] + points[i - 1][1]) / 2;
        ctx.quadraticCurveTo(points[i - 1][0], points[i - 1][1], xc, yc);
        if (i === points.length - 1) {
          ctx.lineTo(points[i][0], points[i][1]);
        }
      }
      ctx.lineTo(points[points.length - 1][0], height - paddingBottom);
      ctx.lineTo(points[0][0], height - paddingBottom);
      ctx.closePath();

      const gradient = ctx.createLinearGradient(0, 0, 0, height);
      gradient.addColorStop(0, 'rgba(126, 212, 186, 0.5)');
      gradient.addColorStop(1, 'rgba(255, 255, 255, 0.05)');
      ctx.fillStyle = gradient;
      ctx.fill();
    }

    // 4. 线条绘制
    ctx.beginPath();
    ctx.strokeStyle = '#7ed4ba';
    ctx.lineWidth = 3;
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    if (points.length > 0) {
      ctx.moveTo(points[0][0], points[0][1]);
      for (let i = 1; i < points.length; i++) {
        const xc = (points[i][0] + points[i - 1][0]) / 2;
        const yc = (points[i][1] + points[i - 1][1]) / 2;
        ctx.quadraticCurveTo(points[i - 1][0], points[i - 1][1], xc, yc);
        if (i === points.length - 1) {
          ctx.lineTo(points[i][0], points[i][1]);
        }
      }
    }
    ctx.stroke();

    // 5. 交互高亮
    const selIndex = this.selectedChartIndex;
    if (selIndex >= 0 && selIndex < points.length) {
      const point = points[selIndex];
      const selX = point[0];
      const selY = point[1];

      ctx.beginPath();
      ctx.strokeStyle = '#e0e0e0';
      ctx.lineWidth = 1;
      ctx.moveTo(selX, paddingTop);
      ctx.lineTo(selX, height - paddingBottom);
      ctx.stroke();

      ctx.beginPath();
      ctx.fillStyle = 'rgba(126, 212, 186, 0.3)';
      ctx.arc(selX, selY, 8, 0, Math.PI * 2);
      ctx.fill();

      ctx.beginPath();
      ctx.fillStyle = '#ffffff';
      ctx.arc(selX, selY, 5, 0, Math.PI * 2);
      ctx.fill();

      ctx.beginPath();
      ctx.fillStyle = '#7ed4ba';
      ctx.arc(selX, selY, 3, 0, Math.PI * 2);
      ctx.fill();
    }

    // 6. 底部文字
    ctx.fillStyle = '#999999';
    ctx.font = '11vp sans-serif';

    this.weekChartData.forEach((item, index) => {
      const x = paddingSide + (index * stepX);
      const y = height - 5;

      if (index === 0) {
        ctx.textAlign = 'start';
      } else if (index === this.weekChartData.length - 1) {
        ctx.textAlign = 'end';
      } else {
        ctx.textAlign = 'center';
      }
      ctx.fillText(item.weekName, x, y);
    });
  }

  // --- 工具函数 ---
  private getTodayStr(): string {
    const now = new Date();
    return `${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}`;
  }

  private formatDurationSmart(seconds: number): string {
    if (seconds < 60) return `${seconds}秒`;
    const min = Math.floor(seconds / 60);
    if (min < 60) return `${min}分钟`;
    const hour = Math.floor(min / 60);
    const remainMin = min % 60;
    return remainMin > 0 ? `${hour}小时${remainMin}分` : `${hour}小时`;
  }

  private formatTimePoint(timestamp: number): string {
    const date = new Date(timestamp);
    const h = date.getHours().toString().padStart(2, '0');
    const m = date.getMinutes().toString().padStart(2, '0');
    return `${h}:${m}`;
  }

  private formatDateTitle(dateStr: string): string {
    const today = this.getTodayStr();
    if (dateStr === today) return '今天';

    const d = new Date();
    d.setDate(d.getDate() - 1);
    const yesterday = `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
    if (dateStr === yesterday) return '昨天';

    return dateStr;
  }

  toggleExpand(index: number) {
    animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
      const oldGroup = this.historyGroups[index];
      this.historyGroups[index] = {
        date: oldGroup.date,
        totalDuration: oldGroup.totalDuration,
        items: oldGroup.items,
        isExpanded: !oldGroup.isExpanded
      };
    })
  }

  build() {
    NavDestination(){
      Column() {
        // --- 1. 顶部 Header 区域 ---
        Stack({ alignContent: Alignment.Top }) {
          Row()
            .width('100%')
            .height(240) // 保持你原来的高度
            .linearGradient({
              angle: 180,
              colors: [
                ['#f3b0a7', 0.0],
                ['#ffdad4', 1.0]
              ]
            })
            .borderRadius({ bottomLeft: 40, bottomRight: 40 })

          Column() {
            // 导航栏
            Row() {
              Image($r('app.media.iv_back'))
                .width(24)
                .height(24)
                .fillColor(Color.White)
                .onClick(() => {
                  this.pathStack.pop();
                })

              Text('专注记录')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .margin({ left: 16 })
            }
            .width('100%')
            .padding({ top: 50, left: 20 })

            // 统计卡片 (保留你的设计)
            Row() {
              Column({ space: 8 }) {
                Text(this.totalFocusTimeStr)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#333')
                Text('累计专注')
                  .fontSize(12)
                  .fontColor('#999')
              }
              .layoutWeight(1)

              Divider().vertical(true).height(30).color('#eee')

              Column({ space: 8 }) {
                Text(this.todayFocusTimeStr)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#7ed4ba')
                Text('今日专注')
                  .fontSize(12)
                  .fontColor('#999')
              }
              .layoutWeight(1)

              Divider().vertical(true).height(30).color('#eee')

              Column({ space: 8 }) {
                Text(this.totalCount.toString())
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#333')
                Text('专注次数')
                  .fontSize(12)
                  .fontColor('#999')
              }
              .layoutWeight(1)
            }
            .width('90%')
            .height(100)
            .backgroundColor(Color.White)
            .borderRadius(16)
            .margin({ top: 20 })
            .shadow({ radius: 15, color: 'rgba(0,0,0,0.05)', offsetY: 5 })
            .justifyContent(FlexAlign.SpaceAround)
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .height(260) // Stack 总高度稍微给大一点点，给阴影留空间

        // --- 2. 列表区域 ---
        List({ space: 20 }) {

          // 【新增】将图表作为列表的第一项
          ListItem() {
            this.CanvasChartCard()
          }

          if (this.historyGroups.length === 0) {
            ListItem() {
              Column({ space: 15 }) {
                Text('还没有专注记录，快去开始第一次吧~')
                  .fontSize(14)
                  .fontColor('#999')
                  .margin({ top: 20 })
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
            }
          } else {
            ForEach(this.historyGroups, (group: HistoryGroup, index: number) => {
              ListItemGroup({ header: this.GroupHeader(group, index), space: 12 }) {
                if (group.isExpanded) {
                  ForEach(group.items, (item: FocusRecord) => {
                    ListItem() {
                      this.RecordItem(item)
                    }
                  })
                }
              }
            })
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 15, right: 15, bottom: 20 })
        .sticky(StickyStyle.Header)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#f8f8f8')
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }

  // 【新增】图表卡片组件
  @Builder
  CanvasChartCard() {
    Column() {
      // 标题行
      Row() {
        Text('近7天趋势')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333')

        Blank()

        // 选中日期的动态展示
        if (this.weekChartData.length > 0) {
          Text(`${this.weekChartData[this.selectedChartIndex]?.fullDate}: ${this.weekChartData[this.selectedChartIndex]?.minutes}分钟`)
            .fontSize(12)
            .fontColor('#7ed4ba')
        }
      }
      .width('100%')
      .margin({ bottom: 10 })

      // 画布
      Canvas(this.chartContext)
        .width('100%')
        .height(150)
        .onReady(() => {
          this.chartWidth = this.chartContext.width;
          this.chartHeight = this.chartContext.height;
          this.drawChart();
        })
        .onClick((event: ClickEvent) => {
          if (this.weekChartData.length === 0) return;
          const x = event.x;
          const paddingSide = 15;
          const graphWidth = this.chartWidth - (paddingSide * 2);

          // 坐标映射
          let effectiveX = x - paddingSide;
          const stepX = graphWidth / (this.weekChartData.length - 1);

          let index = Math.round(effectiveX / stepX);
          if (index < 0) index = 0;
          if (index >= this.weekChartData.length) index = this.weekChartData.length - 1;

          this.selectedChartIndex = index;
          this.drawChart();
        })
    }
    .width('100%')
    .padding(15)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 2 })
  }

  @Builder
  GroupHeader(group: HistoryGroup, index: number) {
    Row() {
      Text(this.formatDateTitle(group.date))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333')

      Blank()

      Text(`共 ${Math.floor(group.totalDuration / 60)} 分钟`)
        .fontSize(12)
        .fontColor('#999')
        .margin({ right: 10 })

      Image($r('app.media.ic_right_arrow_lined'))
        .width(16)
        .height(16)
        .fillColor('#ccc')
        .rotate({ angle: group.isExpanded ? 90 : 0 })
        .animation({ duration: 300 })
    }
    .width('100%')
    .padding({ top: 15, bottom: 10 })
    .backgroundColor('#f8f8f8')
    .onClick(() => {
      this.toggleExpand(index);
    })
  }

  @Builder
  RecordItem(item: FocusRecord) {
    Row() {
      Row() {
        Image($r('app.media.time'))
          .width(20)
          .height(20)
          .fillColor('#7ed4ba')
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor('#e6f7f2')
      .justifyContent(FlexAlign.Center)
      .margin({ right: 12 })

      Column({ space: 4 }) {
        Text('专注学习')
          .fontSize(14)
          .fontColor('#333')
          .fontWeight(FontWeight.Medium)

        Text(`${this.formatTimePoint(item.startTime)} - ${this.formatTimePoint(item.endTime)}`)
          .fontSize(12)
          .fontColor('#999')
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Text(`${Math.floor(item.duration / 60)} 分钟`)
        .fontSize(16)
        .fontColor('#7ed4ba')
        .fontWeight(FontWeight.Bold)
    }
    .width('100%')
    .padding(15)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.03)', offsetY: 2 })
  }
}
