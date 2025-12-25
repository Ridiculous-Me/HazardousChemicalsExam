import { AppStorageV2, promptAction, curves } from "@kit.ArkUI";
import common from '@ohos.app.ability.common';
import { CalendarService, UserPreferencesManager} from "common";
import { media } from '@kit.MediaKit';
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';

// --- 0. 白噪音与全局音频管理 ---
interface WhiteNoiseOption {
  name: string;
  fileName: string;
  icon: string;
}

const NOISE_OPTIONS: WhiteNoiseOption[] = [
  { name: '静音', fileName: '', icon: '🔕' },
  { name: '雨声', fileName: 'rain.mp3', icon: '🌧️' },
  { name: '森林', fileName: 'forest.wav', icon: '🌲' },
  { name: '篝火', fileName: 'fire.wav', icon: '🔥' },
];

export class AudioManager {
  private static instance: AudioManager;
  private avPlayer: media.AVPlayer | undefined;
  private currentFileName: string = '';

  private constructor() {}

  public static getInstance(): AudioManager {
    if (!AudioManager.instance) {
      AudioManager.instance = new AudioManager();
    }
    return AudioManager.instance;
  }

  async play(context: common.UIAbilityContext, fileName: string) {
    if (!fileName) {
      await this.stop();
      return;
    }
    if (this.currentFileName === fileName && this.avPlayer && this.avPlayer.state === 'playing') {
      return;
    }
    if (this.avPlayer) {
      await this.avPlayer.reset();
    } else {
      this.avPlayer = await media.createAVPlayer();
    }
    try {
      let fileDescriptor = await context.resourceManager.getRawFd(fileName);
      this.avPlayer.fdSrc = fileDescriptor;
      this.avPlayer.on('stateChange', async (state: media.AVPlayerState) => {
        if (state === 'initialized') {
          await this.avPlayer?.prepare();
        } else if (state === 'prepared') {
          if (this.avPlayer) this.avPlayer.loop = true;
          await this.avPlayer?.play();
        }
      });
      this.currentFileName = fileName;
    } catch (e) {
      console.error(`[AudioManager] 播放失败:`, e);
      promptAction.showToast({ message: `音频文件 ${fileName} 未找到` });
    }
  }

  async stop() {
    if (this.avPlayer) {
      try {
        if (this.avPlayer.state === 'playing' || this.avPlayer.state === 'paused') {
          await this.avPlayer.stop();
        }
        await this.avPlayer.reset();
      } catch (e) {
        console.error('[AudioManager] 停止出错', e);
      }
    }
    this.currentFileName = '';
  }
}

// --- 1. 数据源与模型定义 ---
const DAILY_QUOTES = [
  "种一棵树最好的时间是十年前，其次是现在。",
  "不积跬步，无以至千里。",
  "Stay hungry, stay foolish.",
  "学习从未如此快乐，只要开始。",
  "今天的努力，是明天的底气。",
  "星光不问赶路人，时光不负有心人。",
  "自律给我自由。"
];

export interface FocusRecord {
  id: string;
  startTime: number;
  endTime: number;
  duration: number;
  dateStr: string;
}

const MIN_FOCUS_TIME = 60;

class DailyStatsModel {
  date: string = '';
  total: number = 0;
  correct: number = 0;
}

interface CalendarItem {
  weekName: string;
  dayNum: number;
  dateStr: string;
  isToday: boolean;
  isPunched: boolean;
}

// --- 2. 弹窗组件 ---
@CustomDialog
struct FocusTipDialog {
  controller: CustomDialogController;
  confirm: (noiseIndex: number) => void = () => {};
  @State selectedNoiseIndex: number = 0;

  build() {
    Column() {
      Text('开启专注模式').fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 20, bottom: 15 })
      Column({ space: 10 }) {
        Text('选择沉浸背景音').fontSize(14).fontColor('#666').width('100%')
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(NOISE_OPTIONS, (item: WhiteNoiseOption, index: number) => {
            Column() {
              Text(item.icon).fontSize(24).margin({ bottom: 4 })
              Text(item.name).fontSize(12).fontColor(this.selectedNoiseIndex === index ? '#7ed4ba' : '#999')
            }
            .width('22%').height(65).justifyContent(FlexAlign.Center)
            .backgroundColor(this.selectedNoiseIndex === index ? '#e6f7f2' : '#f9f9f9')
            .borderRadius(8).borderWidth(1)
            .borderColor(this.selectedNoiseIndex === index ? '#7ed4ba' : 'transparent')
            .onClick(() => { this.selectedNoiseIndex = index; })
          })
        }
        Text(`专注时长需超过 ${Math.ceil(MIN_FOCUS_TIME/60)} 分钟才会生成记录`).fontSize(12).fontColor('#999').margin({ top: 5 })
      }.padding({ left: 15, right: 15 }).margin({ bottom: 25 })
      Row() {
        Button('取消').onClick(() => { if (this.controller) this.controller.close(); }).backgroundColor(Color.White).fontColor('#666').width('40%')
        Button('开始专注').onClick(() => { this.confirm(this.selectedNoiseIndex); if (this.controller) this.controller.close(); }).backgroundColor('#7ed4ba').fontColor(Color.White).width('40%')
      }.width('100%').justifyContent(FlexAlign.SpaceEvenly).margin({ bottom: 20 })
    }.backgroundColor(Color.White).borderRadius(12).width('85%')
  }
}

@CustomDialog
struct TargetSettingDialog {
  controller: CustomDialogController;
  confirm: (value: number) => void = (value: number) => {};
  @State inputValue: string = '';
  build() {
    Column() {
      Text('设定今日目标').fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 20, bottom: 15 })
      TextInput({ placeholder: '请输入目标题数 (如: 30)' }).type(InputType.Number).maxLength(4).width('80%').height(40).margin({ bottom: 20 })
        .onChange((value: string) => { this.inputValue = value; })
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

// --- 3. 主页面组件 ---
@Component
export struct PunchIn {
  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack,() => new NavPathStack())!
  @StorageLink('userId') userId: string = '';
  private userPrefs: UserPreferencesManager = new UserPreferencesManager();
  private context = getContext(this) as common.UIAbilityContext;

  @State isPunchIn: boolean = false;
  @State todayAnswerNum: number = 0;
  @State todayAnswerRate: number = 0;
  @State streakDays: number = 0;
  @State weekCalendar: CalendarItem[] = [];
  @State punchDateList: string[] = [];
  @State dailyQuote: string = '';

  @State showSuccessModal: boolean = false;
  @State medalScale: number = 0;
  @State medalOpacity: number = 0;
  @State lightRotate: number = 0;

  @StorageLink('app_focus_start_time') focusStartTime: number = 0;
  @StorageLink('app_current_noise_file') currentNoiseFile: string = '';
  @State focusTimeString: string = '00:00';
  private timerId: number = -1;

  @StorageLink('global_target_num') targetNum: number = 0;
  @StorageLink('global_last_punch_date') @Watch('checkPunchStatus') globalLastPunchDate: string = '';

  // ★★★ 提醒相关状态 ★★★
  @State isReminderOn: boolean = false;
  @State reminderId: number = -1; // Calendar Kit 的事件ID通常也是 number
  // 新增：记录用户设置的时间
  @State reminderHour: number = 20;
  @State reminderMinute: number = 0;

  targetDialogController: CustomDialogController = new CustomDialogController({
    builder: TargetSettingDialog({ confirm: (value: number): void => { this.handleSetGoal(value) } }),
    alignment: DialogAlignment.Center, autoCancel: true, customStyle: true
  });

  focusDialogController: CustomDialogController = new CustomDialogController({
    builder: FocusTipDialog({ confirm: (index: number) => { this.handleStartConfirm(index) } }),
    alignment: DialogAlignment.Center, autoCancel: true, customStyle: true
  });

  private getTodayStr(): string {
    const now = new Date();
    return `${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}`;
  }

  private generateWeekData() {
    const weekDays = ['日', '一', '二', '三', '四', '五', '六'];
    const tempCalendar: CalendarItem[] = [];
    const today = new Date();
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(today.getDate() - i);
      const dateStr = `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
      const m = d.getMonth() + 1;
      const day = d.getDate();
      const padDateStr = `${d.getFullYear()}-${m < 10 ? '0'+m : m}-${day < 10 ? '0'+day : day}`;
      const isPunched = this.punchDateList.includes(dateStr) || this.punchDateList.includes(padDateStr);
      tempCalendar.push({
        weekName: weekDays[d.getDay()],
        dayNum: d.getDate(),
        dateStr: dateStr,
        isToday: i === 0,
        isPunched: isPunched
      });
    }
    this.weekCalendar = tempCalendar;
  }

  private getCalendarColor(item: CalendarItem): string {
    if (item.isPunched) return '#54e762';
    else if (item.isToday) return '#e0e0e0';
    else return '#ff6b6b';
  }

  async aboutToAppear() {
    const randomIndex = Math.floor(Math.random() * DAILY_QUOTES.length);
    this.dailyQuote = DAILY_QUOTES[randomIndex];

    if (this.userId) {
      await this.userPrefs.initUser(this.context, this.userId);
      const savedPunchDate = await this.userPrefs.getValue<string>('last_punch_date', '');
      if (savedPunchDate && !this.globalLastPunchDate) this.globalLastPunchDate = savedPunchDate;

      this.punchDateList = await this.userPrefs.getValue<string[]>('punch_history_list', []);
      this.checkPunchStatus();

      await this.loadStatsData();
      await this.loadGoalData();

      // ★★★ 恢复提醒状态和时间 ★★★
      // 这里只做状态的读取，不触发 CalendarService 的添加方法，从而避免 Toast
      this.reminderId = await this.userPrefs.getValue<number>('saved_reminder_id', -1);
      this.isReminderOn = this.reminderId !== -1;
      this.reminderHour = await this.userPrefs.getValue<number>('saved_reminder_hour', 20);
      this.reminderMinute = await this.userPrefs.getValue<number>('saved_reminder_minute', 0);
    }

    if (this.focusStartTime > 0) {
      this.startUITimer();
    }
  }

  aboutToDisappear() {
    this.stopUITimer();
  }

  startUITimer() {
    this.updateFocusTimeStr();
    if (this.timerId !== -1) clearInterval(this.timerId);
    this.timerId = setInterval(() => { this.updateFocusTimeStr(); }, 1000);
  }

  stopUITimer() { if (this.timerId !== -1) { clearInterval(this.timerId); this.timerId = -1; } }

  updateFocusTimeStr() {
    if (this.focusStartTime === 0) { this.focusTimeString = '00:00'; return; }
    const now = Date.now();
    const diffSeconds = Math.floor((now - this.focusStartTime) / 1000);
    if (diffSeconds < 0) { this.focusTimeString = '00:00'; return; }
    const min = Math.floor(diffSeconds / 60);
    const sec = diffSeconds % 60;
    this.focusTimeString = `${min.toString().padStart(2, '0')}:${sec.toString().padStart(2, '0')}`;
  }

  toggleFocusState() { if (this.focusStartTime > 0) this.handleEndFocus(); else this.focusDialogController.open(); }

  async handleStartConfirm(noiseIndex: number) {
    this.focusStartTime = Date.now();
    this.startUITimer();
    const selected = NOISE_OPTIONS[noiseIndex];
    if (selected.fileName) {
      this.currentNoiseFile = selected.fileName;
      await AudioManager.getInstance().play(this.context, selected.fileName);
      promptAction.showToast({ message: `专注开始，正在播放：${selected.name}` });
    } else {
      this.currentNoiseFile = '';
      await AudioManager.getInstance().stop();
      promptAction.showToast({ message: '专注模式已开启，加油！' });
    }
  }

  async handleEndFocus() {
    this.stopUITimer();
    const endTime = Date.now();
    await AudioManager.getInstance().stop();
    this.currentNoiseFile = '';
    const durationSeconds = Math.floor((endTime - this.focusStartTime) / 1000);
    if (durationSeconds < MIN_FOCUS_TIME) {
      promptAction.showToast({ message: `专注不足 ${Math.ceil(MIN_FOCUS_TIME/60)} 分钟，未生成记录`, duration: 2500 });
    } else {
      const min = Math.floor(durationSeconds / 60);
      const sec = durationSeconds % 60;
      const newRecord: FocusRecord = { id: endTime.toString(), startTime: this.focusStartTime, endTime: endTime, duration: durationSeconds, dateStr: this.getTodayStr() };
      const historyKey = 'focus_history_list';
      const currentList = await this.userPrefs.getValue<FocusRecord[]>(historyKey, []);
      currentList.unshift(newRecord);
      await this.userPrefs.setValue(historyKey, currentList);
      promptAction.showToast({ message: `专注结束！时长：${min}分${sec}秒` });
    }
    this.focusStartTime = 0;
    this.focusTimeString = '00:00';
  }

  private checkDateIsPunched(date: Date): boolean {
    const y = date.getFullYear();
    const m = date.getMonth() + 1;
    const d = date.getDate();
    const key1 = `${y}-${m}-${d}`;
    const key2 = `${y}-${m < 10 ? '0' + m : m}-${d < 10 ? '0' + d : d}`;
    return this.punchDateList.includes(key1) || this.punchDateList.includes(key2);
  }

  private calculateStreakDays() {
    let count = 0;
    const now = new Date();
    let currentCheck = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    if (this.checkDateIsPunched(currentCheck)) {
    } else {
      currentCheck.setDate(currentCheck.getDate() - 1);
      if (!this.checkDateIsPunched(currentCheck)) {
        this.streakDays = 0;
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
    this.streakDays = count;
  }

  checkPunchStatus() {
    const todayStr = this.getTodayStr();
    const now = new Date();
    const m = now.getMonth() + 1;
    const d = now.getDate();
    const padStr = `${now.getFullYear()}-${m<10?'0'+m:m}-${d<10?'0'+d:d}`;
    this.isPunchIn = this.punchDateList.includes(todayStr) || this.punchDateList.includes(padStr);
    this.calculateStreakDays();
    this.generateWeekData();
  }

  async loadStatsData() {
    const todayStr = this.getTodayStr();
    const statsJson = await this.userPrefs.getValue<string>('daily_answer_stats', '{}');
    try {
      const stats = JSON.parse(statsJson) as DailyStatsModel;
      const now = new Date();
      const m = now.getMonth() + 1;
      const d = now.getDate();
      const padStr = `${now.getFullYear()}-${m<10?'0'+m:m}-${d<10?'0'+d:d}`;
      if (stats && (stats.date === todayStr || stats.date === padStr)) {
        this.todayAnswerNum = stats.total;
        this.todayAnswerRate = stats.total > 0 ? parseFloat(((stats.correct / stats.total) * 100).toFixed(2)) : 0;
      } else {
        this.todayAnswerNum = 0;
        this.todayAnswerRate = 0;
      }
    } catch (e) { this.todayAnswerNum = 0; this.todayAnswerRate = 0; }
  }

  async loadGoalData() {
    const todayStr = this.getTodayStr();
    const goalKey = `goal_${todayStr}`;
    const savedGoal = await this.userPrefs.getValue<number>(goalKey, 0);
    if (savedGoal > 0) this.targetNum = savedGoal;
  }

  async handleSetGoal(num: number) {
    this.targetNum = num;
    const todayStr = this.getTodayStr();
    const goalKey = `goal_${todayStr}`;
    await this.userPrefs.setValue(goalKey, num);
    promptAction.showToast({ message: `目标已设定为 ${num} 题` });
  }

  async handlePunchIn() {
    if (this.isPunchIn) return;
    if (this.targetNum <= 0) {
      promptAction.showToast({ message: '请先制定今日学习计划' });
      this.targetDialogController.open();
      return;
    }
    if (this.todayAnswerNum < this.targetNum) {
      const remain = this.targetNum - this.todayAnswerNum;
      promptAction.showToast({ message: `目标未完成，还需答题 ${remain} 道` });
      return;
    }
    const todayStr = this.getTodayStr();
    this.globalLastPunchDate = todayStr;
    await this.userPrefs.setValue('last_punch_date', todayStr);
    if (!this.punchDateList.includes(todayStr)) {
      this.punchDateList.push(todayStr);
      await this.userPrefs.setValue('punch_history_list', this.punchDateList);
    }
    this.checkPunchStatus();
    try {
      const currentCacheStr = await this.userPrefs.getValue<string>('daily_answer_stats', '');
      let statsToSave: DailyStatsModel = new DailyStatsModel();
      if (currentCacheStr && currentCacheStr !== '{}') {
        const parsed = JSON.parse(currentCacheStr) as DailyStatsModel;
        statsToSave.total = parsed.total;
        statsToSave.correct = parsed.correct;
        statsToSave.date = todayStr;
      } else {
        statsToSave.total = this.todayAnswerNum;
        statsToSave.correct = 0;
        statsToSave.date = todayStr;
      }
      await this.userPrefs.setValue(`stats_${todayStr}`, JSON.stringify(statsToSave));
    } catch (e) {}
    this.triggerVibration();
    this.triggerSuccessAnimation();
  }

  triggerVibration() {
    try {
      vibrator.startVibration({ type: 'time', duration: 200, }, { id: 0, usage: 'touch' }).catch((error: BusinessError) => {});
    } catch (err) {}
  }

  triggerSuccessAnimation() {
    this.showSuccessModal = true;
    this.lightRotate = 0;
    animateTo({
      duration: 800,
      curve: curves.springMotion(0.6, 0.8),
      onFinish: () => {
        setTimeout(() => {
          animateTo({ duration: 300 }, () => {
            this.medalOpacity = 0;
            this.showSuccessModal = false;
          })
          setTimeout(() => { this.medalScale = 0; }, 300);
        }, 3000);
      }
    }, () => {
      this.medalScale = 1;
      this.medalOpacity = 1;
    })
  }

  // ★★★ 核心修改：使用 CalendarService 替代旧逻辑 ★★★
  async toggleReminder(isOn: boolean) {
    this.isReminderOn = isOn;

    if (isOn) {
      // 开启提醒：写入系统日历
      // 传入当前设置的 小时 和 分钟
      const id = await CalendarService.addCalendarEvent(this.context, this.reminderHour, this.reminderMinute);

      if (id !== -1) {
        // 成功
        this.reminderId = id;
        await this.userPrefs.setValue('saved_reminder_id', id);
      } else {
        // 失败（可能是拒绝了权限）
        this.isReminderOn = false;
      }
    } else {
      // 关闭提醒：从系统日历删除
      if (this.reminderId !== -1) {
        await CalendarService.deleteCalendarEvent(this.context, this.reminderId);
        this.reminderId = -1;
        await this.userPrefs.setValue('saved_reminder_id', -1);
      }
    }
  }

  // ★★★ 修改：时间选择器逻辑适配日历 ★★★
  openTimePicker() {
    // 只有在开启提醒时才允许修改时间
    if (!this.isReminderOn) {
      promptAction.showToast({ message: '请先开启右侧开关' });
      return;
    }

    TimePickerDialog.show({
      selected: new Date(new Date().setHours(this.reminderHour, this.reminderMinute)),
      useMilitaryTime: true, // 24小时制
      onAccept: async (value: TimePickerResult) => {
        // 1. 更新内存时间
        this.reminderHour = value.hour;
        this.reminderMinute = value.minute;

        // 2. 保存时间偏好
        await this.userPrefs.setValue('saved_reminder_hour', this.reminderHour);
        await this.userPrefs.setValue('saved_reminder_minute', this.reminderMinute);

        // 3. 逻辑：删除旧的 -> 添加新的
        if (this.reminderId !== -1) {
          await CalendarService.deleteCalendarEvent(this.context, this.reminderId);
        }

        // 4. 创建新提醒
        const newId = await CalendarService.addCalendarEvent(this.context, this.reminderHour, this.reminderMinute);
        if (newId !== -1) {
          this.reminderId = newId;
          await this.userPrefs.setValue('saved_reminder_id', newId);
        } else {
          // 如果添加失败，回滚开关状态
          this.isReminderOn = false;
        }
      }
    })
  }

  // 辅助显示时间字符串
  formatTimeDisplay(): string {
    const h = this.reminderHour.toString().padStart(2, '0');
    const m = this.reminderMinute.toString().padStart(2, '0');
    return `${h}:${m}`;
  }
  @State isPlanReminderVisible: boolean = true;

  build() {
    Column() {
      Stack() {
        // --- 1. 背景层 (固定不动) ---
        Row() {
        }
        .width('100%')
        .backgroundColor('#f3b0a7')
        .height(200)
        .borderRadius({ bottomLeft: 80, bottomRight: 80 })
        .position({ x: 0, y: 0 })

        // --- 2. 主内容层 (添加滚动) ---
        Scroll() {
          Column() {
            // 2.1 顶部数据
            Column() {
              Row() {
                Text('学习统计').fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White)
                Blank()
                Row() {
                  Text('🔥 ').fontSize(16)
                  Text(`已连续 ${this.streakDays} 天`).fontSize(14).fontColor(Color.White).fontWeight(FontWeight.Medium)
                }
                .backgroundColor('rgba(255,255,255,0.2)')
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .borderRadius(15)


              }.width('100%')

              Text(this.dailyQuote).fontSize(12).fontColor('rgba(255,255,255,0.8)').margin({ top: 8 })
                .width('100%').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).fontStyle(FontStyle.Italic)
            }.width('100%').padding({ bottom: 15 })

            // 2.2 打卡与统计卡片
            Row({ space: 10 }) {
              Column() {
                Row({ space: 2 }) {
                  Image($r('app.media.punch_in_1')).width(26)
                  Text(this.isPunchIn ? '今日打卡成功' : '今日还未打卡').fontSize(12).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('90%').height(30).justifyContent(FlexAlign.Center).borderRadius(15).backgroundColor('#fad8d6')
                Row() {
                  Stack() {
                    Row() {
                      Text(this.isPunchIn ? '已完成打卡' : '立即打卡').fontSize(15).fontWeight(FontWeight.Bold)
                    }
                    .backgroundColor('#fad8d6').borderRadius(10).padding({ left: 10, right: 10, top: 8, bottom: 8 })
                    if (!this.isPunchIn) {
                      Row() { Image($r('app.media.click')).width(30) }.position({ y: 25, x: 30 })
                    }
                  }.onClick(() => { this.handlePunchIn(); })
                }.margin({ bottom: 12 })
              }
              .layoutWeight(4).borderRadius(10).height(130).backgroundColor(Color.White).justifyContent(FlexAlign.SpaceBetween).padding({ bottom: 15, top: 15 })
              .onClick(() => { this.pathStack.pushPathByName('PunchInDetailPage', null, false) })

              Column() {
                Row() { Text('今日概况').fontSize(16).fontWeight(FontWeight.Bold) }.width('100%').padding({ left: 10 })
                Row() {
                  Column({ space: 5 }) {
                    Text(`${this.todayAnswerNum}`).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333')
                    Text('已答题').fontSize(12).fontColor('#999')
                    Text(this.targetNum > 0 ? `目标: ${this.targetNum}` : '未设目标').fontSize(11).fontColor('#999').margin({ top: 5 })
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1).padding({ left: 10 })
                  Stack() {
                    Progress({ value: this.todayAnswerRate, total: 100, type: ProgressType.Ring }).color('#7ed4ba').style({ strokeWidth: 8 }).width(65).height(65)
                    Column() {
                      Text(`${this.todayAnswerRate}%`).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#7ed4ba')
                      Text('正确率').fontSize(9).fontColor('#999')
                    }
                  }.margin({ right: 10 })
                }.width('100%').justifyContent(FlexAlign.SpaceBetween).layoutWeight(1)
              }
              .layoutWeight(5).borderRadius(10).height(130).backgroundColor(Color.White).padding({ top: 10, bottom: 10 })
            }.width('100%')

            // 2.3 7天日历
            Column() {
              Row() { Text('近7天记录').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#333') }.width('100%').margin({ bottom: 12 })
              Row() {
                ForEach(this.weekCalendar, (item: CalendarItem) => {
                  Column({ space: 8 }) {
                    Text(item.weekName).fontSize(11).fontColor('#666')
                    Row() { Text(`${item.dayNum}`).fontSize(14).fontWeight(FontWeight.Bold).fontColor(Color.White) }
                    .width(32).height(32).borderRadius(16).backgroundColor(this.getCalendarColor(item)).justifyContent(FlexAlign.Center)
                  }.layoutWeight(1)
                })
              }.width('100%').justifyContent(FlexAlign.SpaceBetween)
            }.width('100%').backgroundColor(Color.White).borderRadius(10).padding(15).margin({ top: 12 })

            // 2.4 专注计时
            Row() {
              Column({ space: 5 }) {
                Row({ space: 5 }) {
                  Text('专注计时').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#333')
                  if (this.currentNoiseFile) { Text('🎵').fontSize(12) }
                }
                Text(this.focusStartTime > 0 ? (this.currentNoiseFile ? '专注中 · 白噪音播放中' : '保持专注，不要退出哦') : '记录每一次努力的时光')
                  .fontSize(12).fontColor(this.focusStartTime > 0 ? '#7ed4ba' : '#999')
              }.alignItems(HorizontalAlign.Start)
              Blank()
              if (this.focusStartTime > 0) Text(this.focusTimeString).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#7ed4ba').margin({ right: 15 })
              Button(this.focusStartTime > 0 ? '结束' : '开始专注').fontSize(13).height(32)
                .backgroundColor(this.focusStartTime > 0 ? '#ff6b6b' : '#7ed4ba')
                .onClick(() => { this.toggleFocusState(); })
            }
            .width('100%').padding(15).backgroundColor(Color.White).borderRadius(10).margin({ top: 12 }).alignItems(VerticalAlign.Center)

            // 2.5 制定计划提醒
            // 修改判断条件：只有当目标未设定(<=0) 且 提示可见(isPlanReminderVisible) 为 true 时才显示
            if (this.targetNum <= 0 && this.isPlanReminderVisible) {
              Row() {
                Row() {
                  Row() {
                    Image($r('app.media.cancel'))
                      .width(30)
                  }
                  .onClick(() => {
                    // --- 修改处：点击后将可见性设为 false，ArkUI 会自动移除该组件 ---
                    animateTo({ duration: 300 }, () => {
                      this.isPlanReminderVisible = false;
                    })
                  })

                  Row() {
                    Marquee({ start: true, step: 6, loop: -1, fromStart: true, src: '今日还未制定学习计划哦，点击前往制定~' })
                      .fontSize(14).fontColor('#7ed4ba').width('100%')
                  }.layoutWeight(1).margin({ left: 5, right: 5 })
                }.layoutWeight(1)

                Row() { Text('制定计划').fontSize(14).fontColor(Color.White) }
                .height(24).borderRadius(13).padding({ left: 4, right: 4 })
                .backgroundColor('#54e762')
                .onClick(() => { this.targetDialogController.open(); })
              }
              .width('100%').padding(6).backgroundColor('#d9f1ec')
              .justifyContent(FlexAlign.SpaceBetween).borderRadius(10).margin({ top: 10 })
              // 建议加上 transition 效果，消失时更丝滑
              .transition({ type: TransitionType.Delete, opacity: 0, scale: { x: 0.8, y: 0.8 } })
            }


            // ★★★ 每日提醒开关卡片 (支持点击改时间) ★★★
            Row() {
              Column({ space: 5 }) {
                Row({ space: 5 }) {
                  Text('每日打卡提醒').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#333')
                }
                Row() {
                  Text('每天 ').fontSize(12).fontColor('#999')
                  Text(this.formatTimeDisplay())
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    // 如果开启了提醒，显示主题色并增加下划线暗示可点击
                    .fontColor(this.isReminderOn ? '#7ed4ba' : '#999')
                    .decoration({ type: this.isReminderOn ? TextDecorationType.Underline : TextDecorationType.None, color: '#7ed4ba' })
                    .onClick(() => {
                      this.openTimePicker();
                    })
                  Text(' 提醒我学习').fontSize(12).fontColor('#999')
                }
              }.alignItems(HorizontalAlign.Start)
              Blank()

              Toggle({ type: ToggleType.Switch, isOn: this.isReminderOn })
                .selectedColor('#7ed4ba')
                .onChange((isOn: boolean) => {
                  this.toggleReminder(isOn);
                })
            }
            .width('100%').padding(15).backgroundColor(Color.White).borderRadius(10).margin({ top: 12 }).alignItems(VerticalAlign.Center)
            // ===============================================

            this.chooseType()
          }
          .padding({ top: 50, left: 15, right: 15 }) // 将内边距保留在这里
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
        .align(Alignment.TopStart)

        // --- 3. 高级打卡成功弹窗 ---
        if (this.showSuccessModal) {
          Stack() {
            Column().width('100%').height('100%').backgroundColor('rgba(0,0,0,0.6)').onClick(() => { this.showSuccessModal = false })
            Image($r('app.media.punch_in_1')).width(300).height(300).opacity(0.3).blur(20).rotate({ angle: this.lightRotate })
              .onAppear(() => { animateTo({ duration: 10000, iterations: -1, curve: Curve.Linear }, () => { this.lightRotate = 360; }) })
            Particle({ particles: [
              {
                emitter: { particle: { type: ParticleType.POINT, config: { radius: 8 }, count: 50, lifetime: 2500 }, emitRate: 100, position: ['50%', '50%'], size: [0, 0] },
                color: { range: ['#FFD700', '#FFA500'], distributionType: DistributionType.UNIFORM },
                scale: { range: [0.8, 1.5], updater: { type: ParticleUpdater.CURVE, config: [{ from: 0, to: 1, startMillis: 0, endMillis: 200 }, { from: 1, to: 0, startMillis: 2000, endMillis: 2500 }] } },
                acceleration: { speed: { range: [600, 1200] }, angle: { range: [0, 360] } },
              },
              {
                emitter: { particle: { type: ParticleType.POINT, config: { radius: 6 }, count: 60, lifetime: 3000 }, emitRate: 100, position: ['50%', '50%'], size: [0, 0] },
                color: { range: ['#FF69B4', '#00BFFF'], distributionType: DistributionType.UNIFORM },
                scale: { range: [0.5, 1.2], updater: { type: ParticleUpdater.CURVE, config: [{ from: 0, to: 1, startMillis: 0, endMillis: 200 }, { from: 1, to: 0, startMillis: 2000, endMillis: 3000 }] } },
                acceleration: { speed: { range: [500, 1000] }, angle: { range: [0, 360] } },
              }
            ]}).width('100%').height('100%').hitTestBehavior(HitTestMode.None).zIndex(2)

            Column() {
              Stack({ alignContent: Alignment.Bottom }) {
                Row() {
                  Polygon({ width: 40, height: 60 }).points([[0, 0], [40, 0], [40, 60], [20, 45], [0, 60]]).fill('#e6b800').rotate({ angle: 20 }).margin({ right: -10 })
                  Polygon({ width: 40, height: 60 }).points([[0, 0], [40, 0], [40, 60], [20, 45], [0, 60]]).fill('#e6b800').rotate({ angle: -20 }).margin({ left: -10 })
                }.margin({ bottom: -30 })
                Stack() {
                  Circle({ width: 150, height: 150 }).fillOpacity(0.3).fill('#ffeb3b')
                  Circle({ width: 120, height: 120 }).linearGradient({ angle: 135, colors: [[0xffd700, 0.0], [0xffa500, 1.0]] }).shadow({ radius: 10, color: 'rgba(0,0,0,0.3)', offsetY: 5 })
                  Circle({ width: 100, height: 100 }).fill(Color.White)
                  Column() { Text('🎉').fontSize(40); Text('打卡成功').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#d9a300').margin({ top: 5 }) }
                }
              }.scale({ x: this.medalScale, y: this.medalScale }).opacity(this.medalOpacity)
              Text(`太棒了！已连续坚持 ${this.streakDays} 天`).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ top: 50 }).shadow({ radius: 5, color: 'rgba(0,0,0,0.5)' }).opacity(this.medalOpacity).scale({ x: this.medalScale, y: this.medalScale })
            }.width('100%').height('100%').justifyContent(FlexAlign.Center).zIndex(3).hitTestBehavior(HitTestMode.None)
          }.width('100%').height('100%').zIndex(999)
        }
      }.width('100%').height('100%')
    }.width('100%').height('100%').backgroundColor('#f5f5f5')
  }

  @Builder
  chooseType() {
    GridRow({ columns: 2, gutter: { x: 12, y: 12 } }) {
      ForEach(selectModule, (item: SelectModule, index: number) => {
        GridCol() {
          Row() {
            Column() {
              Text(item.text).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333')
              Text('点击查看 >').fontSize(12).fontColor('#999').margin({ top: 5 })
            }.alignItems(HorizontalAlign.Start)
            Blank()
            Image(item.image).width(40).height(40).objectFit(ImageFit.Contain)
          }
          .width('100%').height(80).backgroundColor(Color.White).borderRadius(16).padding(15)
          .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 5 })
          .onClick(() => {
            if (index === 0) this.pathStack.pushPathByName('CollectionPage', null, false)
            else if (index === 1) this.pathStack.pushPathByName('WrongPage', null, false)
            else if (index === 2) this.pathStack.pushPathByName('FocusHistoryPage', null, false)
            else if (index === 3) this.pathStack.pushPathByName('DataReportPage', null, false)
          })
        }
      })
    }.width('100%').margin({ top: 10 })
  }
}

export const selectModule: SelectModule[] = [
  { image: $r('app.media.like'), text: '收藏' },
  { image: $r('app.media.Wrong_Collection'), text: '错题集' },
  { image: $r('app.media.content'), text: '专注记录' },
  { image: $r('app.media.DataReport'), text: '学习情况' }
]

interface SelectModule {
  image: Resource,
  text: string,
}
