import { AppStorageV2, promptAction } from "@kit.ArkUI";
import common from '@ohos.app.ability.common';
import http from '@ohos.net.http';
import { UserPreferencesManager } from "common"; // 确保路径正确
import { componentSnapshot } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { userInfo } from "../../../pages/Mine";

// --- 1. 数据接口定义 ---
interface SkinItem {
  id: number;
  color: string;
  imgurl: string;
  iconurl: string;
}

interface SkinResponse {
  msg: string;
  code: number;
  data: SkinItem[];
}

// 统计模型
class DailyStatsModel {
  date: string = '';
  total: number = 0;
  correct: number = 0;
}

// --- 2. 日签弹窗 ---
@CustomDialog
struct DailyBadgeDialog {
  controller: CustomDialogController;
  skinList: SkinItem[] = [];
  consecutiveDays: number = 0;
  @State currentSkin: SkinItem | null = null;
  @State quote: string = "耐得住寂寞，才能看见繁华";
  private dayStr: string = '';
  private monthStr: string = '';
  private yearStr: string = '';
  private quotes: string[] = [
    "耐得住寂寞，才能看见繁华", "星光不问赶路人，时光不负有心人",
    "每一个不曾起舞的日子，都是对生命的辜负", "种一棵树最好的时间是十年前，其次是现在",
    "自律给我自由", "不仅要看远方，更要走好脚下的路", "唯有热爱，可抵岁月漫长"
  ];

  aboutToAppear() {
    const now = new Date();
    this.dayStr = now.getDate().toString();
    this.yearStr = now.getFullYear().toString();
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    this.monthStr = months[now.getMonth()];
    this.randomNext();
  }

  randomNext() {
    if (this.skinList.length > 0) {
      const randomIndex = Math.floor(Math.random() * this.skinList.length);
      this.currentSkin = this.skinList[randomIndex];
    }
    this.quote = this.quotes[Math.floor(Math.random() * this.quotes.length)];
  }

  async handleShare() {
    try {
      const pixelMap = await componentSnapshot.get('daily_card');
      const context = getContext(this) as common.UIAbilityContext;
      const fileName = `daily_share_${new Date().getTime()}.jpg`;
      const filePath = context.cacheDir + '/' + fileName;
      const file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      const packer = image.createImagePacker();
      const packOpts: image.PackingOption = { format: 'image/jpeg', quality: 98 };
      await packer.packToFile(pixelMap, file.fd, packOpts);
      fs.closeSync(file.fd);
      packer.release();
      const uri = fileUri.getUriFromPath(filePath);
      const shareData = new systemShare.SharedData({
        utd: utd.UniformDataType.JPEG, uri: uri, title: '每日打卡日签', description: '来自我的学习打卡记录'
      });
      shareData.addRecord({ utd: utd.UniformDataType.JPEG, uri: uri, title: fileName });
      const controller = new systemShare.ShareController(shareData);
      controller.show(context, { previewMode: systemShare.SharePreviewMode.DEFAULT, selectionMode: systemShare.SelectionMode.SINGLE });
    } catch (error) {
      promptAction.showToast({ message: '分享失败' });
    }
  }
  @StorageLink('userInfo') userInfo: userInfo = {
    nickname: '',
    headimg: ''
  }

  build() {

    Stack() {
      if (this.currentSkin) {
        Image(this.currentSkin.imgurl).width('100%').height('100%').objectFit(ImageFit.Cover).blur(30)
      } else {
        Column().width('100%').height('100%').backgroundColor('#2c3e50')
      }
      Column().width('100%').height('100%').backgroundColor('rgba(0,0,0,0.3)')
      Column() {
        Row() {
          Blank()
          Image($r('app.media.cancel')).width(28).height(28).fillColor(Color.White).opacity(0.8).onClick(() => { this.controller.close(); })
        }.width('85%').padding({ bottom: 10 })
        Stack({ alignContent: Alignment.TopStart }) {
          if (this.currentSkin) {
            Image(this.currentSkin.imgurl).width('100%').height('100%').borderRadius(24).objectFit(ImageFit.Cover).backgroundColor('#333')
          }
          Column().width('100%').height('100%').borderRadius(24).backgroundColor('rgba(0,0,0,0.25)')
          Column() {
            Row() {
              Column({ space: 4 }) {
                Text(this.dayStr).fontSize(48).fontWeight(FontWeight.Regular).fontColor(Color.White)
                Row() {
                  Text('/').fontSize(16).fontColor(Color.White).margin({ right: 4 })
                  Column() { Text(`${this.monthStr},${this.yearStr}`).fontSize(14).fontColor(Color.White) }
                }
              }.alignItems(HorizontalAlign.Start)
            }.width('100%').padding({ top: 30, left: 24, right: 24 })
            Text(`坚持学习打卡 ${this.consecutiveDays} 天`).fontSize(16).fontColor(Color.White).margin({ top: 20, left: 24 }).width('100%')
            Blank()
            Row() {
              Image($r('app.media.update')).width(24).fillColor(Color.White).margin({ right: 4 })
              Text('换一个').fontSize(14).fontColor(Color.White)
            }.margin({ left: 24, bottom: 10 }).width('100%').onClick(() => { this.randomNext(); })
            Text(this.quote).fontSize(18).fontColor(Color.White).width('85%').margin({ left: 24, bottom: 30 })
            Row() {
              Blank()
              if (this.currentSkin) {
                Image(this.userInfo.headimg).width(60).height(60).objectFit(ImageFit.Contain).opacity(0.9).borderRadius(30)
              }
            }.width('100%').padding({ left: 24, right: 24, bottom: 30 }).alignItems(VerticalAlign.Bottom)
          }.width('100%').height('100%')
        }.id('daily_card').width('85%').height('65%').borderRadius(24).clip(true).shadow({ radius: 20, color: 'rgba(0,0,0,0.5)', offsetY: 10 })
        Button('立即分享').width('75%').height(50).fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White).backgroundColor('#7ed4ba').borderRadius(25).margin({ top: 30 }).shadow({ radius: 10, color: 'rgba(126, 212, 186, 0.4)', offsetY: 5 }).onClick(() => { this.handleShare(); })
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    }.width('100%').height('100%').backgroundColor(Color.Transparent)
  }
}

// --- 3. 制定目标弹窗 ---
@CustomDialog
struct TargetSettingDialog {
  controller: CustomDialogController;
  confirm: (value: number) => void = (value: number) => {};
  @State inputValue: string = '';

  build() {
    Column() {
      Text('设定今日目标').fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 20, bottom: 15 })
      TextInput({ placeholder: '请输入目标题数 (如: 30)' }).type(InputType.Number).maxLength(4).width('80%').height(40).margin({ bottom: 20 }).onChange((value: string) => { this.inputValue = value; })
      Row() {
        Button('取消').onClick(() => { if (this.controller) this.controller.close(); }).backgroundColor(Color.White).fontColor('#666').width('40%')
        Button('确定').onClick(() => {
          const num = parseInt(this.inputValue);
          if (!isNaN(num) && num > 0) { this.confirm(num); if (this.controller) this.controller.close(); }
          else { promptAction.showToast({ message: '请输入有效的数字' }); }
        }).backgroundColor('#7ed4ba').fontColor(Color.White).width('40%')
      }.width('100%').justifyContent(FlexAlign.SpaceEvenly).margin({ bottom: 20 })
    }.backgroundColor(Color.White).borderRadius(12).width('80%')
  }
}

// --- 4. 主页面 ---
@Builder
export function PunchInDetailPageBuilder() {
  PunchInDetailPage()
}

@Component
export struct PunchInDetailPage {
  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack, () => new NavPathStack())!;
  @StorageLink('userId') userId: string = '';
  private userPrefs: UserPreferencesManager = new UserPreferencesManager();
  private context = getContext(this) as common.UIAbilityContext;

  @State currentYear: number = 0;
  @State currentMonth: number = 0;
  @State today: number = 0;
  @State daysInMonth: number[] = [];
  @State emptyDaysArray: number[] = [];
  @State selectedDay: number = 0;

  @StorageLink('global_target_num') targetNum: number = 0;
  @StorageLink('global_last_punch_date') @Watch('onGlobalPunchDateChange') globalLastPunchDate: string = '';

  @State punchedSet: Set<string> = new Set();
  @State monthPunchCount: number = 0;
  @State monthMissCount: number = 0;
  @State monthAnswerCount: number = 0;
  @State consecutiveDays: number = 0;

  @State selectedDayTotal: number = 0;
  @State selectedDayAccuracy: string = '0.00%';

  @State isDanmuOn: boolean = true;
  @State danmu1Offset: number = 400;
  @State text1: string = '';
  @State color1: string = 'transparent';
  @State danmu2Offset: number = 400;
  @State text2: string = '';
  @State color2: string = 'transparent';
  private timer1: number = -1;
  private timer2_timeout: number = -1;
  private timer2_interval: number = -1;
  private danmuList: string[] = ["书山有路勤为径", "今日事今日毕", "坚持就是胜利", "越努力越幸运", "加油！"];
  private danmuColors: string[] = ['rgba(255, 235, 238, 0.9)', 'rgba(232, 245, 233, 0.9)'];

  @State skinList: SkinItem[] = [];

  targetDialogController: CustomDialogController = new CustomDialogController({
    builder: TargetSettingDialog({ confirm: (value: number): void => { this.handleSetGoal(value) } }),
    alignment: DialogAlignment.Center, autoCancel: true, customStyle: true
  });

  badgeDialogController: CustomDialogController = new CustomDialogController({
    builder: DailyBadgeDialog({ skinList: this.skinList, consecutiveDays: this.consecutiveDays }),
    alignment: DialogAlignment.Center, autoCancel: true, customStyle: true
  });

  // --- 关键辅助方法：日期格式统一 ---

  // 格式A: 2024-5-1
  private getDateKey(year: number, month: number, day: number): string {
    return `${year}-${month}-${day}`;
  }

  // 格式B: 2024-05-01 (兼容部分旧数据或系统日期格式)
  private getPadDateKey(year: number, month: number, day: number): string {
    const m = month < 10 ? `0${month}` : `${month}`;
    const d = day < 10 ? `0${day}` : `${day}`;
    return `${year}-${m}-${d}`;
  }

  async aboutToAppear() {
    const now = new Date();
    this.currentYear = now.getFullYear();
    this.currentMonth = now.getMonth() + 1;
    this.today = now.getDate();
    this.selectedDay = this.today;

    this.calculateCalendarLayout();

    if (this.userId) {
      await this.userPrefs.initUser(this.context, this.userId);
      await this.loadData();
    }
    this.startDoubleLaneDanmu();
    this.fetchSkinList();
  }

  onPageShow() {
    this.loadData();
  }

  aboutToDisappear() {
    if (this.timer1 !== -1) clearInterval(this.timer1);
    if (this.timer2_timeout !== -1) clearTimeout(this.timer2_timeout);
    if (this.timer2_interval !== -1) clearInterval(this.timer2_interval);
  }

  onGlobalPunchDateChange() {
    if (this.globalLastPunchDate) {
      this.punchedSet.add(this.globalLastPunchDate);
      // 这里的 Set 需要重新赋值触发响应，但最好在 loadData 里统一处理
      this.loadData();
    }
  }

  async fetchSkinList() {
    const apiUrl = 'http://love.csweimei.cn/listing_group/GetSkin';
    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(apiUrl, { method: http.RequestMethod.GET });
      if (response.responseCode === 200 && typeof response.result === 'string') {
        const result = JSON.parse(response.result) as SkinResponse;
        if (result.code === 0 && result.data) this.skinList = result.data;
      }
    } catch (error) {
      console.error('Fetch skin list error:', error);
    }
  }

  async handleSetGoal(num: number) {
    this.targetNum = num;
    const todayStr = this.getDateKey(this.currentYear, this.currentMonth, this.today);
    await this.userPrefs.setValue(`goal_${todayStr}`, num);
    promptAction.showToast({ message: `目标已设定为 ${num} 题` });
  }

  // --- 核心修复：打卡逻辑（含目标校验） ---
  async handlePunchAction() {
    // 1. 如果已打卡，直接弹日签
    if (this.isPunched(this.today)) {
      if (this.skinList.length === 0) await this.fetchSkinList();
      if (this.skinList.length > 0) this.badgeDialogController.open();
      else promptAction.showToast({message: '正在获取日签数据...'});
      return;
    }

    // 2. 获取统一格式的日期 Key (使用 getDateKey)
    const todayKey = this.getDateKey(this.currentYear, this.currentMonth, this.today);
    const todayStr = todayKey;

    // =========================================================
    // 3. [关键修复]：打卡前的目标校验 (与主页逻辑对齐)
    // =========================================================

    // 3.1 检查是否设定目标
    if (this.targetNum <= 0) {
      promptAction.showToast({ message: '请先制定今日学习计划' });
      this.targetDialogController.open();
      return;
    }

    // 3.2 检查是否完成目标
    // 读取缓存中的今日答题数据
    const currentCacheStr = await this.userPrefs.getValue<string>('daily_answer_stats', '');
    let todayAnswerNum = 0;
    try {
      if (currentCacheStr && currentCacheStr !== '{}') {
        const stats = JSON.parse(currentCacheStr) as DailyStatsModel;
        // 简单校验日期，防止脏数据
        // (注：这里允许不严格校验日期，因为 usually daily_answer_stats is cleared next day or updated today)
        todayAnswerNum = stats.total || 0;
      }
    } catch (e) { todayAnswerNum = 0; }

    if (todayAnswerNum < this.targetNum) {
      const remain = this.targetNum - todayAnswerNum;
      promptAction.showToast({ message: `目标未完成，还需答题 ${remain} 道` });
      return;
    }
    // =========================================================

    // 4. 校验通过，开始打卡逻辑
    try {
      let statsToSave: DailyStatsModel;
      // 准备要归档的数据
      if (currentCacheStr && currentCacheStr !== '{}') {
        try {
          statsToSave = JSON.parse(currentCacheStr) as DailyStatsModel;
        } catch (e) {
          statsToSave = { total: 0, correct: 0, date: todayStr };
        }
        // 关键：强制将日期修正为标准格式，确保一致性
        statsToSave.date = todayStr;
      } else {
        statsToSave = { total: todayAnswerNum, correct: 0, date: todayStr };
      }

      // 将数据保存到【历史归档】
      await this.userPrefs.setValue(`stats_${todayKey}`, JSON.stringify(statsToSave));

    } catch (e) {
      console.error('保存历史存档失败:', e);
    }

    // 5. 更新打卡日期历史列表
    const historyList = await this.userPrefs.getValue<string[]>('punch_history_list', []);
    const todayPad = this.getPadDateKey(this.currentYear, this.currentMonth, this.today);
    // 防止重复
    if (!historyList.includes(todayStr) && !historyList.includes(todayPad)) {
      historyList.push(todayStr);
      await this.userPrefs.setValue('punch_history_list', historyList);
    }

    // 6. 更新全局状态
    this.globalLastPunchDate = todayStr;
    await this.userPrefs.setValue('last_punch_date', todayStr);

    // 7. 更新本地内存状态
    this.punchedSet.add(todayStr);
    this.punchedSet = new Set(this.punchedSet); // 触发刷新

    // 8. 刷新界面数据
    this.recalculateStats();
    await this.loadData();

    promptAction.showToast({ message: '打卡成功！' });
    if (this.skinList.length > 0) this.badgeDialogController.open();
  }

  async loadData() {
    const historyList = await this.userPrefs.getValue<string[]>('punch_history_list', []);
    const tempSet = new Set(historyList);
    if (this.globalLastPunchDate) {
      tempSet.add(this.globalLastPunchDate);
    }
    this.punchedSet = tempSet;

    this.recalculateStats();
    await this.updateSelectedDayInfo();

    // 顶部显示今日实时数据
    const todayStats = await this.getStatsForDate(this.today);
    this.monthAnswerCount = todayStats.total;
  }

  recalculateStats() {
    let punchCount = 0;
    let missCount = 0;
    for (let day = 1; day <= this.today; day++) {
      // 只要这一天被打卡了（无论哪种格式），就算
      if (this.isPunched(day)) punchCount++;
      else missCount++;
    }
    this.monthPunchCount = punchCount;
    this.monthMissCount = missCount;
    this.calculateConsecutiveDays();
  }

  // 修复后的连续天数计算
  calculateConsecutiveDays() {
    let count = 0;
    const now = new Date();
    // 从今天开始往前推
    let currentCheck = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    // 检查今天是否打卡
    if (this.checkDateIsPunched(currentCheck)) {
      count++;
    } else {
      // 如果今天还没打，不计入，但也不算断（除非昨天也没打）
      // 这里的逻辑：通常连续天数包含今天已打的。如果今天没打，就从昨天开始算
      // 如果昨天断了，就是0
    }

    // 如果今天打了，currentCheck 依然是今天，下面循环第一轮会再次判断今天，导致+1 (count=2)
    // 所以，如果上面判断了，下面应该从昨天开始
    // 更好的写法：

    count = 0;
    // 重置时间检查器
    currentCheck = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    // 先看今天
    if (this.checkDateIsPunched(currentCheck)) {
      // 今天打了，从今天开始往前数
    } else {
      // 今天没打，从昨天开始往前数
      currentCheck.setDate(currentCheck.getDate() - 1);
      if (!this.checkDateIsPunched(currentCheck)) {
        this.consecutiveDays = 0;
        return;
      }
    }

    while (true) {
      if (this.checkDateIsPunched(currentCheck)) {
        count++;
        currentCheck.setDate(currentCheck.getDate() - 1);
      } else {
        break;
      }
    }
    this.consecutiveDays = count;
  }

  // 辅助方法：检查 Date 对象对应的日期是否打卡
  checkDateIsPunched(date: Date): boolean {
    const y = date.getFullYear();
    const m = date.getMonth() + 1;
    const d = date.getDate();
    const key1 = this.getDateKey(y, m, d);
    const key2 = this.getPadDateKey(y, m, d);
    return this.punchedSet.has(key1) || this.punchedSet.has(key2);
  }

  // --- 核心修复：获取指定日期的数据 (解决数据显示不对的问题) ---
  async getStatsForDate(day: number): Promise<DailyStatsModel> {
    const targetKey = this.getDateKey(this.currentYear, this.currentMonth, day);
    const targetPadKey = this.getPadDateKey(this.currentYear, this.currentMonth, day);

    // 1. 定义解析函数，增加容错
    const parseStats = (jsonStr: string | object): DailyStatsModel => {
      try {
        if (!jsonStr || jsonStr === '{}') return new DailyStatsModel();
        let obj: DailyStatsModel;
        if (typeof jsonStr === 'string') {
          obj = JSON.parse(jsonStr) as DailyStatsModel;
        } else {
          obj = jsonStr as DailyStatsModel;
        }
        const res = new DailyStatsModel();
        res.total = obj.total || 0;
        res.correct = obj.correct || 0;
        res.date = obj.date || '';
        return res;
      } catch (e) {
        return new DailyStatsModel();
      }
    };

    // 2. 读取【历史归档】数据
    let historyStr = await this.userPrefs.getValue<string>(`stats_${targetKey}`, '');
    if (!historyStr || historyStr === '{}') {
      historyStr = await this.userPrefs.getValue<string>(`stats_${targetPadKey}`, '');
    }
    const historyStats = parseStats(historyStr);

    // 3. 如果查询的不是今天，直接返回归档数据
    if (day !== this.today) {
      return historyStats;
    }

    // 4. 如果查询的是【今天】，融合【实时缓存】
    const cacheStr = await this.userPrefs.getValue<string>('daily_answer_stats', '');
    const cacheStats = parseStats(cacheStr);

    const todayStandard = this.getDateKey(this.currentYear, this.currentMonth, this.today);
    const todayPad = this.getPadDateKey(this.currentYear, this.currentMonth, this.today);

    let isCacheValid = false;
    // 只要缓存有数据，且日期匹配或者无日期(可能是刚刚做完还没打卡)，就认为缓存有效
    if (cacheStats.total > 0 && (!cacheStats.date || cacheStats.date === todayStandard || cacheStats.date === todayPad)) {
      isCacheValid = true;
    }

    // 优先取最大值
    if (isCacheValid && cacheStats.total >= historyStats.total) {
      return cacheStats;
    }

    return historyStats;
  }

  async updateSelectedDayInfo() {
    const stats = await this.getStatsForDate(this.selectedDay);
    this.selectedDayTotal = stats.total;
    this.selectedDayAccuracy = stats.total > 0
      ? ((stats.correct / stats.total) * 100).toFixed(2) + '%'
      : '0.00%';
  }

  startDoubleLaneDanmu() {
    const duration = 8000;
    this.runLane1(duration);
    this.timer1 = setInterval(() => { this.runLane1(duration); }, 8500);
    this.timer2_timeout = setTimeout(() => {
      this.runLane2(duration);
      this.timer2_interval = setInterval(() => { this.runLane2(duration); }, 8500);
    }, 4250);
  }

  runLane1(duration: number) {
    if (!this.isDanmuOn) return;
    this.danmu1Offset = 400;
    this.text1 = this.danmuList[Math.floor(Math.random() * this.danmuList.length)];
    this.color1 = this.danmuColors[Math.floor(Math.random() * this.danmuColors.length)];
    animateTo({ duration: duration, curve: Curve.Linear }, () => { this.danmu1Offset = -350; });
  }

  runLane2(duration: number) {
    if (!this.isDanmuOn) return;
    this.danmu2Offset = 400;
    this.text2 = this.danmuList[Math.floor(Math.random() * this.danmuList.length)];
    this.color2 = this.danmuColors[Math.floor(Math.random() * this.danmuColors.length)];
    animateTo({ duration: duration, curve: Curve.Linear }, () => { this.danmu2Offset = -350; });
  }

  calculateCalendarLayout() {
    const days = new Date(this.currentYear, this.currentMonth, 0).getDate();
    let tempDays: number[] = [];
    for (let i = 1; i <= days; i++) tempDays.push(i);
    this.daysInMonth = tempDays;

    const firstDayWeek = new Date(this.currentYear, this.currentMonth - 1, 1).getDay();
    let tempEmpty: number[] = [];
    for (let i = 0; i < firstDayWeek; i++) tempEmpty.push(i);
    this.emptyDaysArray = tempEmpty;
  }

  // --- 核心修复：打卡状态判断 ---
  private isPunched(day: number): boolean {
    const key1 = this.getDateKey(this.currentYear, this.currentMonth, day);
    const key2 = this.getPadDateKey(this.currentYear, this.currentMonth, day);
    // 兼容两种格式
    return this.punchedSet.has(key1) || this.punchedSet.has(key2);
  }

  private getCircleColor(day: number): string | Color {
    const isSelected = (day === this.selectedDay);
    const isPunched = this.isPunched(day);
    if (isSelected) return '#2e7d32';
    else if (isPunched) return '#b9f6ca';
    else if (day > this.today) return Color.Transparent;
    else if (day === this.today) return '#e0e0e0';
    return '#ffcdd2';
  }

  private getFontColor(day: number): string | Color {
    return (day === this.selectedDay) ? Color.White : (day > this.today ? '#d0d0d0' : '#333333');
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        Scroll() {
          Column() {
            this.HeaderSection()
            this.StatsSection()
            this.CalendarSection()
            this.SelectedDayDetailSection()
            if (this.selectedDay === this.today) {
              this.ActionButtonsSection()
            }
          }
          .width('100%').padding({ left: 16, right: 16, bottom: 40 })
        }
        .width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off)

        if (this.isDanmuOn) {
          // ... 弹幕层 ...
          Row() {
            Text(this.text1).fontSize(14).fontColor('#555').padding({ left: 12, right: 12, top: 6, bottom: 6 }).backgroundColor(this.color1).borderRadius(15)
          }
          .position({ x: this.danmu1Offset, y: 50 })
          .hitTestBehavior(HitTestMode.None)

          Row() {
            Text(this.text2).fontSize(14).fontColor('#555').padding({ left: 12, right: 12, top: 6, bottom: 6 }).backgroundColor(this.color2).borderRadius(15)
          }
          .position({ x: this.danmu2Offset, y: 70 })
          .hitTestBehavior(HitTestMode.None)
        }
      }.width('100%').height('100%').backgroundColor('#e6f7ff')
    }.hideTitleBar(true)
  }

  // --- 界面组件构建器 (Builders) ---

  @Builder HeaderSection() {
    Row() {
      Image($r('app.media.iv_back')).width(30).onClick(() => { this.pathStack.pop(); })
      Column() {
        Text(`${this.currentMonth}月`).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#333')
        Text(this.currentYear.toString()).fontSize(14).fontColor('#666')
      }.padding({left: 20})
      Row() {
        Text('弹幕').fontSize(12).fontColor('#666').margin({ right: 6 })
        Toggle({ type: ToggleType.Switch, isOn: this.isDanmuOn }).selectedColor('#7ed4ba').onChange((isOn) => this.isDanmuOn = isOn).height(24)
      }.justifyContent(FlexAlign.End)
    }.width('100%').height(80).alignItems(VerticalAlign.Center).justifyContent(FlexAlign.SpaceBetween).padding({top: 40})
  }

  @Builder StatsSection() {
    Row() {
      Column({ space: 8 }) {
        Text(this.monthPunchCount.toString()).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#333')
        Text('本月打卡').fontSize(12).fontColor('#888')
      }.layoutWeight(1)

      Column({ space: 8 }) {
        Text(this.monthMissCount.toString()).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#333')
        Text('本月缺卡').fontSize(12).fontColor('#888')
      }.layoutWeight(1)

      Column({ space: 8 }) {
        Text(this.consecutiveDays.toString()).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#333')
        Text('连续打卡').fontSize(12).fontColor('#888')
      }.layoutWeight(1)

      Column({ space: 8 }) {
        // 显示今日实时的答题进度
        Text(this.targetNum > 0 ? `${this.monthAnswerCount}/${this.targetNum}` : this.monthAnswerCount.toString())
          .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#333')
        Text('今日答题').fontSize(12).fontColor('#888')
      }.layoutWeight(1)
    }
    .width('100%').padding({ top: 20, bottom: 30 }).justifyContent(FlexAlign.SpaceAround)
  }

  @Builder CalendarSection() {
    Column() {
      Row() {
        ForEach(['日', '一', '二', '三', '四', '五', '六'], (item: string) => {
          Text(item).fontSize(14).fontColor('#999').layoutWeight(1).textAlign(TextAlign.Center)
        })
      }.width('100%').margin({ bottom: 16 })

      Grid() {
        ForEach(this.emptyDaysArray, () => { GridItem() { Text('') } })
        ForEach(this.daysInMonth, (day: number) => { GridItem() { this.DayCell(day) } })
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .rowsGap(16)
      .width('100%')
      .height(350)
    }
    .width('100%')
    .backgroundColor('rgba(255,255,255, 0.6)')
    .borderRadius(20)
    .padding(16)
  }

  @Builder DayCell(day: number) {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Circle({ width: 36, height: 36 }).fill(this.getCircleColor(day));
        Text(day.toString()).fontSize(14).fontColor(this.getFontColor(day))
      }
      if (this.isPunched(day)) {
        Circle({ width: 4, height: 4 }).fill('#2e7d32').margin({ top: 4 })
      } else if (day < this.today) {
        Circle({ width: 4, height: 4 }).fill('#d32f2f').margin({ top: 4 })
      } else {
        Blank().height(8)
      }
    }
    .onClick(async () => {
      if (day > this.today) return;
      this.selectedDay = day;
      await this.updateSelectedDayInfo();
    })
  }

  @Builder SelectedDayDetailSection() {
    Column() {
      // 状态栏
      if (this.isPunched(this.selectedDay)) {
        Row() {
          Image($r('app.media.correct')).width(16).height(16).fillColor('#2e7d32').margin({ right: 8 })
          Text(`${this.currentMonth}月${this.selectedDay}日 已打卡`).fontSize(14).fontColor('#2e7d32')
        }
        .width('100%').padding(12).backgroundColor('#e8f5e9').borderRadius(12).margin({ top: 20, bottom: 16 })
      } else if (this.selectedDay === this.today) {
        Row() {
          Image($r('app.media.time')).width(16).height(16).fillColor('#666').margin({ right: 8 })
          Text(`${this.currentMonth}月${this.selectedDay}日 待打卡`).fontSize(14).fontColor('#666')
        }
        .width('100%').padding(12).backgroundColor('#f5f5f5').borderRadius(12).margin({ top: 20, bottom: 16 })
      } else if (this.selectedDay < this.today) {
        Row() {
          Image($r('app.media.cancel')).width(16).height(16).fillColor('#d32f2f').margin({ right: 8 })
          Text(`${this.currentMonth}月${this.selectedDay}日 未打卡`).fontSize(14).fontColor('#d32f2f')
        }
        .width('100%').padding(12).backgroundColor('#ffebee').borderRadius(12).margin({ top: 20, bottom: 16 })
      }

      // 数据栏
      Column({ space: 12 }) {
        Row() {
          Text("答题数").fontSize(16).fontColor('#666')
          Blank()
          Text(this.selectedDayTotal.toString()).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333')
        }.width('100%').padding({ left: 10, right: 10 })

        Divider().color('rgba(0,0,0,0.05)')

        Row() {
          Text("正确率").fontSize(16).fontColor('#666')
          Blank()
          Text(this.selectedDayAccuracy).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333')
        }.width('100%').padding({ left: 10, right: 10 })
      }
      .width('100%').padding(16).backgroundColor('rgba(255,255,255,0.6)').borderRadius(16)
    }
    .width('100%')
  }

  @Builder ActionButtonsSection() {
    Row({ space: 16 }) {
      Button(this.targetNum > 0 ? "修改计划" : "制定计划")
        .onClick(() => { this.targetDialogController.open(); })
        .backgroundColor('#fff')
        .fontColor('#7ed4ba')
        .border({ width: 1, color: '#7ed4ba' })
        .layoutWeight(1)
        .height(44)
        .borderRadius(22)

      Button(this.isPunched(this.today) ? "查看日签" : "立即打卡")
        .onClick(() => { this.handlePunchAction(); })
        .backgroundColor('#7ed4ba')
        .fontColor(Color.White)
        .layoutWeight(1)
        .height(44)
        .borderRadius(22)
    }
    .width('100%')
    .padding({ top: 20, bottom: 20 })
  }
}
