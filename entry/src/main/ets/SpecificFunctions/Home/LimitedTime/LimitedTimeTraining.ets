import { AppStorageV2 } from "@kit.ArkUI";
import { ExamParam } from "../Random/RandomPractice";

// 定义配置项的数据结构
interface TrainingConfig {
  title: string
  time: number
  count: number
  desc: string
  difficulty: string
  color: string
}

@Builder
export function LimitedTimeTrainingBuilder() {
  LimitedTimeTraining()
}

@Component
export struct LimitedTimeTraining {
  // 路由栈
  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack, () => new NavPathStack())!

  // 当前选中的模式：0-标准模式，1-闯关模式
  @State currentTab: number = 0

  // --- 配置数据源 ---

  // 标准模式配置：固定时间，固定题量
  readonly standardConfigs: TrainingConfig[] = [
    {
      title: '快速自测',
      time: 10,
      count: 15,
      desc: '利用碎片时间，快速检验复习成果',
      difficulty: '入门',
      color: '#409EFF'
    },
    {
      title: '进阶训练',
      time: 30,
      count: 40,
      desc: '中等强度，覆盖核心考点',
      difficulty: '进阶',
      color: '#67C23A'
    },
    {
      title: '全真模考',
      time: 60,
      count: 100,
      desc: '完全模拟真实考试题量与节奏',
      difficulty: '困难',
      color: '#E6A23C'
    }
  ]

  // 闯关模式配置：时间极短，题量给足(伪无限)，看能做多少
  readonly speedConfigs: TrainingConfig[] = [
    {
      title: '极速 3 分钟',
      time: 3,
      count: 300, // 给个做不完的数量
      desc: '高度紧张，测试瞬间反应能力',
      difficulty: '闪电',
      color: '#F56C6C'
    },
    {
      title: '极限 10 分钟',
      time: 10,
      count: 400,
      desc: '耐力与速度的双重考验',
      difficulty: '炼狱',
      color: '#909399'
    }
  ]

  build() {
    NavDestination() {
      Column() {
        // 1. 顶部标题栏
        this.buildTitleBar()

        // 2. 模式切换 Tabs
        this.buildTabs()

        // 3. 列表内容区域
        Scroll() {
          Column({ space: 16 }) {
            // 顶部提示文案
            Text(this.currentTab === 0
              ? '标准模式：在规定时间内完成指定数量的题目。'
              : '闯关模式：时间结束即交卷，挑战你的做题速度上限！')
              .fontSize(13)
              .fontColor('#999')
              .width('100%')
              .padding({ left: 4 })

            // 渲染卡片列表
            ForEach(
              this.currentTab === 0 ? this.standardConfigs : this.speedConfigs,
              (item: TrainingConfig, index: number) => {
                this.buildCard(item)
              }
            )
          }
          .padding(16)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)

      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F7F9') // 浅灰背景
    }
    .hideTitleBar(true)
    .onReady((ctx) => {
      this.pathStack = ctx.pathStack
    })
  }

  // --- UI 组件构建 ---

  @Builder
  buildTitleBar() {
    Row(){
      Row(){
        Image($r('app.media.iv_back'))
          .width(30)
      }
      .onClick(() => {
        this.pathStack.pop()
      })



      Row(){
        Text('限时训练')
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

  @Builder
  buildTabs() {
    Row() {
      Stack() {
        // 背景滑块 (可选，为了简单这里只用颜色切换)
      }

      Row() {
        this.buildTabItem('标准模式', 0)
        this.buildTabItem('闯关模式', 1)
      }
      .width('100%')
      .height(40)
      .backgroundColor('#Eef0f4')
      .borderRadius(20)
      .padding(4)
    }
    .padding({ left: 16, right: 16, top: 16 })
    .backgroundColor(Color.White)
  }

  @Builder
  buildTabItem(text: string, index: number) {
    Button(text)
      .layoutWeight(1)
      .height('100%')
      .type(ButtonType.Normal)
      .borderRadius(16)
      .backgroundColor(this.currentTab === index ? Color.White : Color.Transparent)
      .fontColor(this.currentTab === index ? '#333' : '#999')
      .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
      .shadow(this.currentTab === index ? { radius: 8, color: 'rgba(0,0,0,0.05)', offsetY: 2 } : undefined)
      .onClick(() => {
        animateTo({ duration: 250, curve: Curve.EaseInOut }, () => {
          this.currentTab = index
        })
      })
  }

  @Builder
  buildCard(item: TrainingConfig) {
    Column() {
      // 卡片头部：标题 + 难度标签
      Row() {
        Text(item.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333')

        Blank()

        Text(item.difficulty)
          .fontSize(12)
          .fontColor(item.color)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(this.hexToRgba(item.color, 0.1)) // 动态生成浅色背景
          .borderRadius(4)
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 卡片中间：数据展示
      Row() {
        Column() {
          Text(`${item.time}`)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333')
          Text('限时(分钟)')
            .fontSize(12)
            .fontColor('#999')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 分割线
        Divider().vertical(true).height(30).color('#EEE')

        Column() {
          Text(this.currentTab === 1 ? `${item.count}` : `${item.count}`)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333')
          Text('题目数量')
            .fontSize(12)
            .fontColor('#999')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 20 })
        .layoutWeight(1)

        // 开始按钮图标
        Image($r('app.media.ic_right_arrow_lined')) // 使用箭头图标
          .width(24)
          .height(24)
          .fillColor('#CCC')
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 卡片底部：描述
      Text(item.desc)
        .fontSize(13)
        .fontColor('#666')
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.03)', offsetY: 4 })
    .onClick(() => {
      this.startTraining(item)
    })
  }

  // --- 逻辑处理 ---

  startTraining(config: TrainingConfig) {
    const param: ExamParam = {
      types: ['单选题', '判断题', '多选题'], // 默认全题型混合
      count: config.count,
      timeLimit: config.time,
      mode: this.currentTab === 0 ? 'standard' : 'speed'
    }

    // 跳转到 RandomExamPage (确保你在路由表中注册了这个名字)
    this.pathStack.pushPath({
      name: 'RandomExamPage',
      param: param
    })
  }

  // 辅助函数：简单的颜色透明度转换
  hexToRgba(hex: string, alpha: number): string {
    // 这里简单处理，实际项目中建议用更严谨的颜色工具
    // 假设输入都是 #RRGGBB 格式
    if (hex.startsWith('#') && hex.length === 7) {
      const r = parseInt(hex.slice(1, 3), 16)
      const g = parseInt(hex.slice(3, 5), 16)
      const b = parseInt(hex.slice(5, 7), 16)
      return `rgba(${r}, ${g}, ${b}, ${alpha})`
    }
    return 'rgba(0,0,0,0.05)'
  }
}
