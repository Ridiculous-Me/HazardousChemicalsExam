// 文件路径: entry/src/main/ets/common/CalendarService.ets
import { calendarManager } from '@kit.CalendarKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common, abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

export class CalendarService {

  /**
   * 添加每日重复的日历提醒
   * @param context 上下文
   * @param hour 小时 (0-23)
   * @param minute 分钟 (0-59)
   * @returns 返回事件ID (number), 失败返回 -1
   */
  static async addCalendarEvent(context: common.UIAbilityContext, hour: number, minute: number): Promise<number> {
    // 1. 请求权限
    const isGranted: boolean = await CalendarService.requestPermissions(context);
    if (!isGranted) {
      promptAction.showToast({ message: '请授予日历权限以设置提醒' });
      return -1;
    }

    // 2. 获取日历账户
    const calendarMgr = calendarManager.getCalendarManager(context);
    let calendar: calendarManager.Calendar | undefined = undefined;
    try {
      calendar = await calendarMgr.getCalendar(); // 获取默认日历
    } catch (e) {
      // 创建本地账户兜底
      const account: calendarManager.CalendarAccount = {
        name: 'study_punch_reminder',
        type: calendarManager.CalendarType.LOCAL,
        displayName: '学习打卡'
      };
      try {
        calendar = await calendarMgr.createCalendar(account);
      } catch (createErr) {
        console.error(`创建日历账户失败: ${JSON.stringify(createErr)}`);
        return -1;
      }
    }

    if (!calendar) return -1;

    // 3. 计算开始时间
    const now = new Date();
    // 设置为用户指定的时间
    const startTimeDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hour, minute, 0);

    // 如果今天的时间已经过了，从明天开始
    if (now.getTime() > startTimeDate.getTime()) {
      startTimeDate.setDate(startTimeDate.getDate() + 1);
    }

    const startTime: number = startTimeDate.getTime();
    const endTime: number = startTime + 60 * 60 * 1000; // 持续1小时

    // 4. 构建事件
    const event: calendarManager.Event = {
      type: calendarManager.EventType.NORMAL,
      startTime: startTime,
      endTime: endTime,
      title: '⏰ 危险化学品考试通关王提醒您，该去打卡啦',
      description: '今天的学习计划完成了吗？坚持就是胜利！',
      reminderTime: [0], // 准点提醒
      recurrenceRule: {
        recurrenceFrequency: calendarManager.RecurrenceFrequency.DAILY, // 每日重复
        interval: 1
      }
    };

    // 5. 写入
    try {
      const eventId: number = await calendar.addEvent(event);
      console.info(`[CalendarService] 添加提醒成功, ID: ${eventId}, 时间: ${hour}:${minute}`);
      promptAction.showToast({ message: `已设置每日 ${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')} 提醒` });
      return eventId;
    } catch (error) {
      const err = error as BusinessError;
      console.error(`[CalendarService] 添加失败: ${err.message}`);
      promptAction.showToast({ message: '设置提醒失败' });
      return -1;
    }
  }

  /**
   * 删除指定的日历提醒
   * @param context
   * @param id 事件ID
   */
  static async deleteCalendarEvent(context: common.UIAbilityContext, id: number): Promise<void> {
    if (id === -1) return;

    const calendarMgr = calendarManager.getCalendarManager(context);
    try {
      const calendar = await calendarMgr.getCalendar();
      if (calendar) {
        // 根据ID删除事件
        await calendar.deleteEvent(id);
        console.info(`[CalendarService] 删除提醒成功 ID: ${id}`);
      }
    } catch (e) {
      console.warn(`[CalendarService] 删除提醒遇到问题 (可能已不存在): ${JSON.stringify(e)}`);
    }
  }

  private static async requestPermissions(context: common.UIAbilityContext): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    const permissions: Array<Permissions> = ['ohos.permission.READ_CALENDAR', 'ohos.permission.WRITE_CALENDAR'];
    try {
      const data = await atManager.requestPermissionsFromUser(context, permissions);
      let grantStatus: Array<number> = data.authResults;
      return grantStatus.every((status: number) => status === 0);
    } catch (err) {
      return false;
    }
  }
}
