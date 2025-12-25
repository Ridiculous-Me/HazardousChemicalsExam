import { ExamDetail, ExamManager } from '../model/QuestionAnswerRecord';
import { getQuestionType, SelectComponent } from './SelectComponent';
import { CustomContentDialog } from '@kit.ArkUI';
import { ExamController } from '../controller/ExamController';
import { JSON } from '@kit.ArkTS';
import { AddParams, ApiService, PromptMessage, UserPreferencesManager } from 'common';
import json from '@ohos.util.json';
import { common } from '@kit.AbilityKit';

// 设置 和 模拟考试时按返回键时打开弹窗
let examController: ExamController = ExamController.instance;

class DailyStatsModel {
  date: string = '';
  total: number = 0;
  correct: number = 0;
}

@Entry
@ComponentV2
export struct Exam {


  //用户id
  @Local userId: string = AppStorage.get('userId')!

  @Param @Require appPathStack: NavPathStack;
  @Param @Require examManager: ExamManager;
  // 记录模拟考试分数回调, 用于计算模拟考试平均分
  @Param mockExamCall: (score: number) => void = (score: number) => {
  };
  // 监听monitor中isShowMockExamDialog的变化
  private examController: ExamController = ExamController.instance;
  // 显示剩余时间
  @Local remainTime: number = 0;
  // 是否显示答题卡
  @Local isShowProblemListSheet: boolean = false;
  // 记录当前是第几题
  @Local currentIndex: number = 0;
  // 模拟考试-暂停考试/继续考试
  @Local isStop: boolean = false;

  private userPrefs: UserPreferencesManager = new UserPreferencesManager();
  private context = getContext(this) as common.UIAbilityContext;

  /**
   * 核心方法：保存今日答题统计 (ArkTS 修复版)
   * @param isCorrect 是否答对
   */
  async saveDailyStats(isCorrect: boolean) {
    if (!this.userId) return;

    // 初始化 Prefs
    await this.userPrefs.initUser(this.context, this.userId);

    // 1. 获取今天的日期字符串
    const now = new Date();
    const todayStr = `${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}`;

    // 2. 读取旧数据
    const statsJson = await this.userPrefs.getValue<string>('daily_answer_stats', '{}');

    // 3. 安全解析 JSON
    let stats: DailyStatsModel;
    try {
      // 使用 'as' 关键字进行类型断言，告诉编译器 "我相信这是这个类型"
      stats = JSON.parse(statsJson) as DailyStatsModel;
    } catch (e) {
      stats = new DailyStatsModel();
    }

    // 防止解析出来是 null 或 undefined
    if (!stats) {
      stats = new DailyStatsModel();
    }

    // 4. 判断是否跨天：如果存储的日期不是今天，重置数据
    // 注意：这里不再创建新对象，而是直接修改属性，符合 ArkTS 性能优化建议
    if (stats.date !== todayStr) {
      stats.date = todayStr;
      stats.total = 0;
      stats.correct = 0;
    }

    // 5. 更新数据
    stats.total = stats.total + 1;
    if (isCorrect) {
      stats.correct = stats.correct + 1;
    }

    // 6. 保存回去
    await this.userPrefs.setValue('daily_answer_stats', JSON.stringify(stats));

    console.info(`[Exam] 统计更新: 总${stats.total}, 对${stats.correct}`);
  }

  @Monitor('examController.isShowMockExamDialog')
  mockExamDialogChange() {
    if (examController.isShowMockExamDialog) {
      examController.isShowMockExamDialog = false;
      this.isStop = true;
      this.examExitDialog.open();
    }
  }

  aboutToAppear(): void {
    this.currentIndex = this.examManager.currentQuestionId + 1;

    if (this.examManager.timeLimit !== 0) {
      this.remainTime = this.examManager.timeLimit * 60;
      let showDialog: boolean = true;
      setInterval(() => {
        if (showDialog && !this.isStop) {
          if (this.remainTime >= 1) {
            this.remainTime--;
          } else {
            showDialog = false;
            this.isStop = true;
            this.examSubmitDialog.open();
          }
        }

      }, 1000); // 1秒触发一次
    }
  }


  // 如果想退出考试重新进入后将已做题回显，去掉这个方法
  aboutToDisappear(): void {
    this.examManager.clearSelectedOption();
  }

  //添加错题
  async addWrong(item: ExamDetail){
    let param = {
      sign: 'dd',
      userid: parseInt(this.userId),
      cate: getQuestionType(item.questionType),
      problemid: item.id
    } as AddParams

    try {
      const res = await ApiService.AddWrong( param)
      console.log('添加参数'+JSON.stringify(param))
      console.log('错题添加'+res.msg)
    } catch (error) {
      console.log(error)
    }
  }

  build() {
    Column() {
      // 模拟考试-展示剩余时间
      this.showRemainTime();

      Swiper(examController.swiperController) {
        ForEach(this.examManager.examDetails, (item: ExamDetail, examIndex: number) => {
          Column({ space: 12 }) {
            SelectComponent({
              item: item,
              // 如果想退出考试重新进入后将已做题回显，打开这个参数
              // isReDisplay: item.selected.length !== 0,
              changeCorrectNum: (isAdd: boolean) => {
                isAdd ? this.examManager.correctNumber++ : this.examManager.correctNumber--;
                if(isAdd){
                  this.saveDailyStats(true);
                }
              },
              changeErrorNum: (isAdd: boolean) => {
                if(isAdd){
                  this.examManager.errorNumber++;
                  this.addWrong(item)
                  this.saveDailyStats(false);
                } else {
                  this.examManager.errorNumber--;
                }
              },
            });
          };
        }, (item: ExamDetail) => JSON.stringify(item.id));
      }
      .index(this.examManager.currentQuestionId)
      .height('100%')
      .autoPlay(false)
      .loop(false)
      .indicator(false)
      .onChange((targetIndex: number) => {
        this.examManager.currentQuestionId = targetIndex;
        this.currentIndex = targetIndex + 1;

        //新增: 通知 Controller 题目索引变了
        if(examController.onIndexChange) {
          examController.onIndexChange(targetIndex)
        }
      })
      .padding({
        top: 12,
        bottom: this.examManager.timeLimit === 0 ? 92 : 92 + 48,
      });

      this.bottomBar();
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F1F3F5');
  }

  @Builder
  showRemainTime() {
    Row({ space: 12 }) {
      Image($r('app.media.clock'))
        .width(24)
        .height(24);

      Text('剩余时间')
        .fontSize(12)
        .fontColor('#64BB5C');

      Text(this.convertToTime(this.remainTime))
        .fontSize(16)
        .fontColor('#64BB5C');
    }
    .height(48)
    .visibility(this.examManager.timeLimit === 0 ? Visibility.None : Visibility.Visible);
  }

  // 答题卡-点击显示清除数据弹窗
  clearRecordsController: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: '温馨提示',
      contentBuilder: () => {
        this.clearRecords();
      },
      buttons: [
        {
          value: '取消',
          buttonStyle: ButtonStyleMode.TEXTUAL,
          action: () => {
          },
        },
        {
          value: '确定',
          buttonStyle: ButtonStyleMode.TEXTUAL,
          role: ButtonRole.ERROR,
          action: () => {
            this.examManager.clearRecords();
            examController.swiperController.changeIndex(this.examManager.currentQuestionId);
            this.examController.renderView = !this.examController.renderView;
            this.isShowProblemListSheet = !this.isShowProblemListSheet;
          },
        },
      ],
    }),
  });
  examExitDialog: CustomDialogController = new CustomDialogController({
    builder: () => {
      this.examExitBuilder();
    },
    autoCancel: false,
  });

  @Builder
  examExitBuilder() {
    Column() {
      Text('考试尚未结束')
        .dialogTitleStyle()

      Blank().height(12)

      Text('是否确认立即退出考试?')
        .dialogInfoStyle()

      Blank().height(28)

      Row() {
        Text('继续考试')
          .dialogChooseStyle()
          .fontColor('#64BB5C')
          .onClick(() => {
            this.examExitDialog.close()
            this.isStop = false;
          })
        Column() {
          Column() {

          }
          .height(24)
          .width(1)
          .backgroundColor('rgba(0,0,0,0.05)')
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .width(8)
        .height('100%')

        Text('确认退出')
          .dialogChooseStyle()
          .fontColor('rgba(0,0,0,0.40)')
          .onClick(() => {
            this.examExitDialog.close()
            this.examSubmitDialog.open();
          })
      }
      .width(296)
      .height(40)

      Blank()
    }
    .width(328)
    .height(164)
  }

  examSubmitDialog: CustomDialogController = new CustomDialogController({
    builder: () => {
      this.submitExamBuilder();
    },
    autoCancel: false,
    onWillDismiss: (dismissDialogAction: DismissDialogAction) => {

    }
  });

  @Builder
  submitExamBuilder() {
    Column() {
      Text(this.calcExamScore() ? '成绩合格' : '成绩不合格')
        .dialogTitleStyle()

      Blank().height(12)

      Text('未答题数: ' + (this.examManager.total - this.examManager.correctNumber - this.examManager.errorNumber) +
        '           ' + '考试成绩: ' + this.examManager.correctNumber + '分')
        .dialogInfoStyle()

      Blank().height(28)

      Row() {
        Text('重新考试')
          .dialogChooseStyle()
          .fontColor('#64BB5C')
          .onClick(() => {
            this.isStop = false;
            this.examSubmitDialog.close();

            this.examManager.clearRecords();
            this.examController.renderView = !this.examController.renderView;
            examController.swiperController.changeIndex(0);
            this.remainTime = this.examManager.timeLimit * 60;
          })
        Column() {
          Column() {

          }
          .height(24)
          .width(1)
          .backgroundColor('rgba(0,0,0,0.05)')
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .width(8)
        .height('100%')

        Text('我知道了')
          .dialogChooseStyle()
          .fontColor('rgba(0,0,0,0.40)')
          .onClick(() => {
            this.isStop = false;
            this.examSubmitDialog.close();
            this.mockExamCall(this.examManager.correctNumber);
            this.appPathStack.pop();
          })
      }
      .width(296)
      .height(40)

      Blank()
    }
    .width(328)
    .height(164);
  }

  // 模拟考试-计算考试成绩是否合格
  calcExamScore(): boolean {
    return this.examManager.total * 0.9 <= this.examManager.correctNumber;
  }

  /**
   * 底部栏视图（正确与错误数量，答题卡入口，是否收藏）
   */
  @Builder
  bottomBar() {
    Row() {
      Image($r('app.media.correct'))
        .width(16)
        .height(16)
        .margin({
          right: '1%',
        });

      Text(String(this.examManager.correctNumber));

      Image($r('app.media.error'))
        .width(16)
        .height(16)
        .margin({
          left: '3%',
          right: '1%',
        });

      Text(String(this.examManager.errorNumber))
        .margin({
          right: '7%',
        });

      Row() {
        Image($r('app.media.exam_list'))
          .width(16)
          .height(16)
          .margin({
            right: '1%',
          });
        Text(`${this.currentIndex}/${this.examManager.total}`);
      }
      .onClick(() => {
        this.isShowProblemListSheet = !this.isShowProblemListSheet;
      })
      .bindSheet($$this.isShowProblemListSheet, this.showProblemListSheet(), {
        height: '70%',
        width: '100%',
        preferType: SheetType.CENTER,
        title: { title: '答题卡' },
        backgroundColor: Color.White,
      });

      Blank();

      Row() {
        Image(this.examManager.examDetails.length > 0 && this.examManager.examDetails[this.currentIndex-1].isCollect ?
        $r('app.media.has_been_marked') :
        $r('app.media.not_marked'))
          .width(24)
          .height(24)
          .margin({
            right: '1%',
          });

        Text('收藏')
          .fontSize(12)
          .fontColor('rgba(0,0,0,0.90)');
      }
      .onClick(async () => {

        // 获取当前题目对象
        let currentDetail = this.examManager.examDetails[this.currentIndex - 1];

        // 切换收藏状态
        currentDetail.isCollect = !currentDetail.isCollect;

        let param = {
          sign: 'dd',
          userid: parseInt(this.userId),
          cate: getQuestionType(currentDetail.questionType),//单选、多选、判断
          problemid: currentDetail.id
        } as AddParams

        console.log('题目信息'+JSON.stringify(param))

        try {
          const res = await ApiService.AddLike(param)

          if(res.issucc){
            PromptMessage.showMessage(res.msg)
          }
        } catch (error) {
          console.log('收藏失败'+error)
        }
      });

      Row() {
        Image($r('app.media.bell'))
          .width(16)
          .height(16);
        Text('交卷')
          .fontColor(Color.White)
          .fontSize(12);
      }
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#64BB5C')
      .borderRadius(8)
      .width(76)
      .height(28)
      .margin({
        left: '3%',
        top: -3,
      })
      .onClick(() => {
        this.isStop = true;
        this.examExitDialog.open();
      })
      .visibility(this.examManager.timeLimit === 0 ? Visibility.None : Visibility.Visible);
    }
    .backgroundColor(Color.White)
    .width('100%')
    .height(76)
    .alignItems(VerticalAlign.Top)
    .padding({
      top: 16,
      left: '4%',
      right: '4%',
    })
    .position({
      bottom: 0,
    });
  }

  /**
   * 答题卡视图
   */
  @Builder
  showProblemListSheet() {
    Column() {
      Grid() {
        ForEach(this.examManager.examDetails, (item: ExamDetail, index: number) => {
          GridItem() {
            Stack() {
              Row() {
              }
              .width('100%')
              .width(40)
              .height(40)
              .borderRadius(20)
              .backgroundColor(this.getBgColorByIsCorrect(item.isCorrect));

              Text(String(index + 1))
                .fontColor(item.isCorrect === undefined ? 'rgba(0,0,0,0.90)' : Color.White);
            };
          }
          .onClick(() => {
            this.currentIndex = index + 1;
            this.examManager.currentQuestionId = index;
            examController.swiperController.changeIndex(index);
            this.isShowProblemListSheet = !this.isShowProblemListSheet;
          });
        }, (item: ExamDetail) => JSON.stringify(item.isCorrect));
      }
      .rowsGap(16)
      .columnsTemplate('repeat(auto-stretch, 69)')
      .height('75%')
      .scrollBar(BarState.Off)

      Blank('15%')

      Button('清空记录')
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('sys.color.font_on_primary'))
        .fontWeight(FontWeight.Medium)
        .backgroundColor('#64BB5C')
        .height(40)
        .width('78%')
        .margin({
          top: 40,
          bottom: 30,
        })
        .onClick(() => {
          this.clearRecordsController.open();
        });
    }
    .padding({
      left: '2%',
      right: '2%',
    })
    .height('100%')
    .width('100%');
  }

  /**
   * 答题卡-显示对、错和未答题的背景色
   * @param isCorrect
   * @returns
   */
  getBgColorByIsCorrect(isCorrect: boolean | undefined): string {
    if (isCorrect === undefined) {
      return '#F1F3F5';
    }
    return isCorrect ? '#64BB5C' : ' #E84026';
  }

  /**
   * 清除记录弹窗视图
   */
  @Builder
  clearRecords() {
    Row() {
      Text('确定要清空当前操作记录吗');
    }
    .justifyContent(FlexAlign.Center)
    .width('100%');
  }

  /**
   * 时间转换-将剩余秒数转换为 mm:ss
   * @param time
   * @returns
   */
  convertToTime(time: number): string {
    let minute: number = Math.floor(time / 60);
    let second: number = time % 60;
    return (minute < 10 ? '0' + minute : minute + '') + ':' + (second < 10 ? '0' + second : second) + '';
  }
}


@Extend(Text)
function dialogTitleStyle() {
  .fontSize(20)
  .fontColor('#E84026')
  .fontWeight(FontWeight.Bold)
  .width('100%')
  .textAlign(TextAlign.Center)
  .width(280)
  .height(56)
}

@Extend(Text)
function dialogInfoStyle() {
  .fontSize(16)
  .fontWeight(FontWeight.Regular)
  .width('100%')
  .textAlign(TextAlign.Center)
  .height(21)
}

@Extend(Text)
function dialogChooseStyle() {
  .fontSize(16)
  .fontWeight(FontWeight.Medium)
  .width(144)
  .height('100%')
  .textAlign(TextAlign.Center)
}

@Builder
export function showSettingSheet() {
  Column({ space: 20 }) {
    Row() {
      Text('答对自动下一题')
        .fontSize(16)
        .fontColor('rgba(0,0,0,0.90)');
      Blank();
      Toggle({ type: ToggleType.Switch, isOn: examController.showNext })
        .selectedColor($r('sys.color.comp_background_emphasize'))
        .onChange((isOn: boolean) => {
          if (isOn) {
            examController.showNext = true;
            return;
          }
          examController.showNext = false;
        });
    }
    .width(360)
    .padding({
      top: 5,
    });

    Row() {
      Text('字体大小')
        .fontSize(10)
        .fontColor('rgba(0,0,0,0.90)');
      Blank();
      Row() {
        Slider({
          value: examController.fontSize,
          min: 14, //滑动最小值
          max: 22, //滑动最大值
          step: 2, //步长
          style: SliderStyle.OutSet,
        })
          .stepColor('rgba(0,0,0,0.40)')
          .trackColor('rgba(0,0,0,0.20)')
          .selectedColor('rgba(0,0,0,0.20)')
          .showSteps(true)
          .blockStyle({ type: SliderBlockType.IMAGE, image: $r('app.media.font_setting') })
          .blockSize({ width: 16, height: 16 })
          .onChange((value: number, mode: SliderChangeMode) => {
            examController.fontSize = value;
          });
      }
      .width('70%');

      Blank();

      Text('字体大小')
        .fontSize(16)
        .fontColor('rgba(0,0,0,0.90)');
    }
    .width(360);
  }
  .height('100%')
  .margin({
    left: '4%',
    right: '4%',
  });
}
