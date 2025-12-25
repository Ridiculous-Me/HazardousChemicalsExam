import { AppStorageV2, LengthMetrics } from "@kit.ArkUI";

export interface ExamParam {
  types: string[];
  count: number;
  timeLimit: number;
  mode?: 'standard' | 'speed' //模式区分
}

@Builder
export function RandomPracticeBuilder() {
  RandomPractice()
}

@Component
export struct RandomPractice {
  // 获取路由栈
  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack, () => new NavPathStack())!

  // 状态管理
  @State selectedTypes: string[] = ['单选题'];
  @State questionCount: number = 10;
  @State timeLimit: number = 0;

  // 配置数据
  readonly questionTypes: string[] = ['单选题', '判断题', '多选题'];
  readonly timeOptions: number[] = [0, 15, 30, 45, 60];

  // 切换题目类型选择
  toggleType(type: string) {
    if (this.selectedTypes.includes(type)) {
      if (this.selectedTypes.length > 1) {
        this.selectedTypes = this.selectedTypes.filter(t => t !== type);
      }
    } else {
      this.selectedTypes.push(type);
    }
  }

  build() {
    NavDestination() {
      Column() {

        // --- 顶部导航栏 ---
        this.TitleBar()

        // --- 内容区域 ---
        Scroll() {
          Column({ space: 24 }) {

            // 1. 选择题目类型
            // 使用自定义组件 PracticeCard，利用尾随闭包写法传递 UI 内容
            PracticeCard({ title: '题目类型' }) {
              // 修复点：space 直接使用数字 12，代表 12vp
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, space: { main: LengthMetrics.vp(12), cross: LengthMetrics.vp(12) } }) {
                ForEach(this.questionTypes, (item: string) => {
                  Text(item)
                    .fontSize(16)
                    .fontColor(this.selectedTypes.includes(item) ? Color.White : '#666666')
                    .padding({ left: 20, right: 20, top: 10, bottom: 10 })
                    .backgroundColor(this.selectedTypes.includes(item) ? '#007DFF' : '#F5F5F5')
                    .borderRadius(20)
                    .animation({ duration: 200 })
                    .onClick(() => {
                      this.toggleType(item)
                    })
                })
              }
            }

            // 2. 选择题目数量
            PracticeCard({ title: '题目数量' }) {
              Column() {
                Row() {
                  Text(`${this.questionCount} 题`)
                    .fontSize(28)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#007DFF')
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .margin({ bottom: 10 })

                Slider({
                  value: this.questionCount,
                  min: 5,
                  max: 50,
                  step: 5,
                  style: SliderStyle.OutSet
                })
                  .blockColor('#007DFF')
                  .trackColor('#E0E0E0')
                  .selectedColor('#007DFF')
                  .showSteps(true)
                  .onChange((value: number) => {
                    this.questionCount = value;
                  })

                Row() {
                  Text('5题').fontSize(12).fontColor('#999')
                  Text('50题').fontSize(12).fontColor('#999')
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
                .padding({ left: 10, right: 10 })
              }
            }

            // 3. 选择答题时间
            PracticeCard({ title: '时间限制' }) {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                ForEach(this.timeOptions, (min: number) => {
                  Column() {
                    Text(min === 0 ? '不限时' : `${min}分钟`)
                      .fontSize(14)
                      .fontColor(this.timeLimit === min ? '#007DFF' : '#333')
                      .fontWeight(this.timeLimit === min ? FontWeight.Medium : FontWeight.Normal)
                  }
                  .width('18%')
                  .height(40)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor(this.timeLimit === min ? '#E6F2FF' : '#F5F5F5')
                  .border({
                    width: 1,
                    color: this.timeLimit === min ? '#007DFF' : 'transparent'
                  })
                  .borderRadius(8)
                  .onClick(() => {
                    this.timeLimit = min;
                  })
                })
              }
            }

          }
          .padding(20)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)

        // --- 底部开始按钮 ---
        Column() {
          Button('开始练习')
            .width('90%')
            .height(50)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#007DFF')
            .shadow({ radius: 10, color: '#40007DFF', offsetY: 5 })
            .onClick(() => {
              this.startPractice()
            })
        }
        .width('100%')
        .padding({ bottom: 20, top: 10 })
        .backgroundColor(Color.White)


      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      //.backgroundColor('#F1F3F5')
      .linearGradient({
        angle: 180,
        colors: [['#c8361d', 0.0], ['#fad8d6', 1.0]]
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
    .hideTitleBar(true)
  }

  // 顶部标题栏 Builder
  @Builder
  TitleBar() {
    Row(){
      Row(){
        Image($r('app.media.iv_back'))
          .width(30)
      }
      .onClick(() => {
        this.pathStack.pop()
      })



      Row(){
        Text('随机练习')
          .fontSize(24)
      }
      .layoutWeight(1)
      .padding({right: 34})
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .padding({top: 40,bottom: 10})
    .backgroundColor(Color.White)
  }

  startPractice() {
    // 模拟开始练习
    AlertDialog.show({
      message: `配置确认:
类型: ${this.selectedTypes.join(',')}
数量: ${this.questionCount}\n时间: ${this.timeLimit}分`,
      confirm: { value: '确定', action: () => {
        let practiceData: ExamParam = {
          types: this.selectedTypes,
          count: this.questionCount,
          timeLimit: this.timeLimit
        }
        this.pathStack.pushPathByName('RandomExamPage', practiceData,false)
      } }
    })
  }
}

// --- 修复方案：定义一个独立的组件来作为卡片容器 ---
@Component
struct PracticeCard {
  @Prop title: string;
  // 使用 @BuilderParam 接收外部传入的 UI 内容
  @BuilderParam content: () => void = this.defaultBuilder;

  @Builder defaultBuilder() {}

  build() {
    Column() {
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333')
        .margin({ bottom: 16 })
        .width('100%')

      // 渲染传入的 UI 内容
      this.content()
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .shadow({ radius: 20, color: '#10000000', offsetY: 5 })
  }
}
