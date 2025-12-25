import { AppStorageV2, componentSnapshot } from "@kit.ArkUI";
import { ClassificationTypeEnum, Exam, ExamController, ExamDetail, ExamManager, QuestionTypeEnum } from "exam";
import { common } from "@kit.AbilityKit";
import { fileIo as fs, fileUri } from '@kit.CoreFileKit'
import { image } from "@kit.ImageKit";
import { systemShare } from "@kit.ShareKit";
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { ApiService, LoadingComponent, QuestionItem, TopicRollDataParams, TopicRollDataResponse } from "common";

export const PaperName = '危险化学品'

// --- 1. 定义绘图数据结构 ---
interface DrawPoint {
  x: number
  y: number
}

interface DrawPath {
  points: DrawPoint[]
  color: string
  lineWidth: number
  isEraser: boolean
}

// 定义每个题目的绘图状态 (用于缓存)
interface QuestionDrawingState {
  history: DrawPath[]
  redoStack: DrawPath[]
}

@Builder
export function ExamComponentBuilder() {
  ExamComponent()
}

@Component
export struct ExamComponent {
  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack, () => new NavPathStack())!
  @State isLoading: boolean = true
  private examController: ExamController = ExamController.instance

  // --- 2. 状态变量 ---
  @State isSelectEraser: boolean = false
  @State isSelectPen: boolean = false // 画笔模式开关
  @State isShowSetting: boolean = false

  // 当前画板的历史记录与重做栈
  @State history: DrawPath[] = []
  @State redoStack: DrawPath[] = []

  // 【核心】：存储所有题目的绘图数据 Map<题目索引, 数据>
  private allDrawingsMap: Map<number, QuestionDrawingState> = new Map()
  // 当前题目索引 (用于存取数据)
  private currentQuestionIndex: number = 0

  // 绘图上下文
  private currentPath: DrawPath | null = null
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)

  private examManager: ExamManager = new ExamManager('模拟考试', [])

  aboutToAppear(): void {
    this.examManager.timeLimit = 10
    this.getMockData()

    // 【关键绑定】：监听 Exam 组件内部的题目切换
    // 确保你的 ExamController 定义了 onIndexChange?: (index: number) => void
    this.examController.onIndexChange = (newIndex: number) => {
      this.handleQuestionChange(newIndex)
    }
  }

  build() {
    NavDestination() {
      Column() {
        this.buildTopToolbar()

        if (!this.isLoading) {
          // --- 3. 核心布局：Stack 叠加 ---
          Stack() {
            // 底层：答题区域 (Exam 组件)
            Exam({
              appPathStack: this.pathStack,
              examManager: this.examManager
            })
              .layoutWeight(1)
              .width('100%')
              .height('100%')

            // 顶层：绘图遮罩 (只有开启画笔时才显示)
            if (this.isSelectPen) {
              this.buildDrawingCanvas()
            }
          }
          .layoutWeight(1)
          .width('100%')
          .alignContent(Alignment.TopStart)
          .id('drawing_board')
        } else {
          LoadingComponent()
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      if (this.examManager.timeLimit !== 0) {
        this.examController.isShowMockExamDialog = true
        return true
      }
      return false
    })
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }

  // --- 4. 绘图相关逻辑 ---

  // 构建画布
  @Builder
  buildDrawingCanvas() {
    Canvas(this.context)
      .width('100%')
      .height('100%')
      // 半透明白色遮罩，让用户感知到现在是"涂鸦模式"
      .backgroundColor('rgba(255, 255, 255, 0.3)')
      // 【关键修改点】：使用 Block，强制拦截事件，防止底部列表滑动
      .hitTestBehavior(HitTestMode.Block)
      .onReady(() => {
        this.redraw()
      })
      .onTouch((event: TouchEvent) => {
        this.handleTouch(event)
      })
  }

  // 处理题目切换：保存上一题，加载新一题
  handleQuestionChange(newIndex: number) {
    if (this.currentQuestionIndex === newIndex) return

    // 1. 保存当前(旧)题目的绘图数据
    this.allDrawingsMap.set(this.currentQuestionIndex, {
      history: [...this.history], // 浅拷贝，防止引用被清空
      redoStack: [...this.redoStack]
    })

    // 2. 更新索引
    this.currentQuestionIndex = newIndex

    // 3. 加载新题目的绘图数据
    const savedState = this.allDrawingsMap.get(newIndex)
    if (savedState) {
      this.history = savedState.history
      this.redoStack = savedState.redoStack
    } else {
      // 如果没画过，初始化为空
      this.history = []
      this.redoStack = []
    }

    // 4. 如果画板是开启状态，立即重绘
    if (this.isSelectPen) {
      setTimeout(() => {
        this.redraw()
      }, 10)
    }
  }

  // 绘图触摸事件
  handleTouch(event: TouchEvent) {
    // 阻止事件冒泡，双重保险防止底部滚动
    event.stopPropagation()

    const x = event.touches[0].x
    const y = event.touches[0].y

    switch (event.type) {
      case TouchType.Down:
        this.context.beginPath()
        this.context.moveTo(x, y)

        // 设置画笔样式
        this.context.lineCap = 'round'
        this.context.lineJoin = 'round'

        if (this.isSelectEraser) {
          this.context.lineWidth = 20
          this.context.globalCompositeOperation = 'destination-out' // 擦除模式
        } else {
          this.context.lineWidth = 3
          this.context.strokeStyle = '#FF0000' // 红色笔迹
          this.context.globalCompositeOperation = 'source-over' // 覆盖模式
        }

        this.currentPath = {
          points: [{ x, y }],
          color: '#FF0000',
          lineWidth: this.isSelectEraser ? 20 : 3,
          isEraser: this.isSelectEraser
        }
        break

      case TouchType.Move:
        if (this.currentPath) {
          this.context.lineTo(x, y)
          this.context.stroke()
          this.currentPath.points.push({ x, y })
        }
        break

      case TouchType.Up:
      case TouchType.Cancel:
        if (this.currentPath) {
          this.history.push(this.currentPath)
          this.redoStack = []
          this.currentPath = null

          // 【实时保存】：每一笔画完都存一下，防止意外退出丢失
          this.allDrawingsMap.set(this.currentQuestionIndex, {
            history: [...this.history],
            redoStack: [...this.redoStack]
          })
        }
        break
    }
  }

  // 重绘逻辑
  redraw() {
    this.context.clearRect(0, 0, 10000, 10000)

    for (const path of this.history) {
      this.context.beginPath()
      this.context.globalCompositeOperation = path.isEraser ? 'destination-out' : 'source-over'
      this.context.lineWidth = path.lineWidth
      this.context.strokeStyle = path.color
      this.context.lineCap = 'round'
      this.context.lineJoin = 'round'

      if (path.points.length > 0) {
        this.context.moveTo(path.points[0].x, path.points[0].y)
        for (let i = 1; i < path.points.length; i++) {
          this.context.lineTo(path.points[i].x, path.points[i].y)
        }
      }
      this.context.stroke()
    }
  }

  // 撤销
  undo() {
    if (this.history.length > 0) {
      const lastPath = this.history.pop()
      if (lastPath) {
        this.redoStack.push(lastPath)
        this.redraw()
        // 同步保存
        this.allDrawingsMap.set(this.currentQuestionIndex, {
          history: [...this.history],
          redoStack: [...this.redoStack]
        })
      }
    }
  }

  // 重做
  redo() {
    if (this.redoStack.length > 0) {
      const path = this.redoStack.pop()
      if (path) {
        this.history.push(path)
        this.redraw()
        // 同步保存
        this.allDrawingsMap.set(this.currentQuestionIndex, {
          history: [...this.history],
          redoStack: [...this.redoStack]
        })
      }
    }
  }

  // --- 5. 工具栏 (逻辑关联部分) ---
  @Builder
  buildTopToolbar() {
    Row() {
      // 返回按钮
      Row() {
        Image($r('app.media.iv_back'))
          .width(30)
      }
      .onClick(() => {
        if (this.examManager.timeLimit !== 0) {
          this.examController.isShowMockExamDialog = true
        }
      })

      // 撤销
      Row() {
        Image($r('app.media.back_drawing'))
          .width(20)
          .opacity(this.history.length > 0 ? 1 : 0.3)
      }
      .onClick(() => {
        if (this.isSelectPen) this.undo()
      })

      // 重做
      Row() {
        Image($r('app.media.next_drawing'))
          .width(20)
          .opacity(this.redoStack.length > 0 ? 1 : 0.3)
      }
      .onClick(() => {
        if (this.isSelectPen) this.redo()
      })

      // 橡皮擦
      Row() {
        Image(this.isSelectEraser ? $r('app.media.Eraser_true') : $r('app.media.Eraser_false'))
          .width(20)
      }
      .onClick(() => {
        if (this.isSelectPen) {
          this.isSelectEraser = !this.isSelectEraser
        }
      })

      // 画笔开关
      Row() {
        Image($r('app.media.Paint'))
          .width(26)
          .opacity(this.isSelectPen ? 1 : 0.3)
      }
      .onClick(() => {
        this.isSelectPen = !this.isSelectPen

        // 1. 如果关闭画笔，顺便把橡皮擦关了
        if (!this.isSelectPen) {
          this.isSelectEraser = false
        }
        // 2. 如果开启画笔，强制刷新一下 Canvas，防止切换导致的空白
        else {
          this.redraw()
        }
      })

      // 分享
      Row() {
        Image($r('app.media.ic_share'))
          .width(25)
      }
      .onClick(() => {
        this.handleShare()
      })

      // 设置
      Row() {
        Image($r('app.media.setting'))
          .width(28)
      }
      .bindSheet($$this.isShowSetting, this.showSettingSheet(), {
        height: '25%',
        width: '100%',
        title: { title: '设置' },
        backgroundColor: Color.White,
      })
      .onClick(() => {
        this.isShowSetting = !this.isShowSetting
      })
    }
    .width('100%')
    .backgroundColor('#ffffff')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ left: 10, right: 10, top: 40, bottom: 10 })
  }

  // 设置题目字体大小
  @Builder
  showSettingSheet() {
    Column({ space: 20 }) {
      Row() {
        Text('答对自动下一题')
          .fontSize(16)
          .fontColor('rgba(0,0,0,0.90)');
        Blank();
        Toggle({ type: ToggleType.Switch, isOn: this.examController.showNext })
          .selectedColor($r('sys.color.comp_background_emphasize'))
          .onChange((isOn: boolean) => {
            if (isOn) {
              this.examController.showNext = true;
              return;
            }
            this.examController.showNext = false;
          });
      }
      .width(360)
      .padding(10);

      Row() {
        Text('字体大小')
          .fontSize(16)
          .fontColor('rgba(0,0,0,0.90)');
        Blank();
        Row() {
          Slider({
            value: this.examController.fontSize,
            min: 14, //滑动最小值
            max: 22, //滑动最大值
            step: 1, //步长
            style: SliderStyle.OutSet,
          })
            .stepColor('rgba(0,0,0,0.40)')
            .trackColor('rgba(0,0,0,0.20)')
            .selectedColor('rgba(0,0,0,0.20)')
            //.showSteps(true)
            .blockStyle({ type: SliderBlockType.IMAGE, image: $r('app.media.font_setting') })
            .blockSize({ width: 16, height: 16 })
            .onChange((value: number, mode: SliderChangeMode) => {
              this.examController.fontSize = value;
            });
        }
        .width('70%');

        Blank();

        Text(this.examController.fontSize.toString())
          .fontSize(16)
          .fontColor('rgba(0,0,0,0.90)');
      }
      .padding(10)
      .width(360);
    }
    .height('100%')
    .margin({
      left: '4%',
      right: '4%',
    });
  }

  //获取模拟考试数据
  @State resultData: TopicRollDataResponse | null = null
  async getMockData() {
    this.isLoading = true

    const params = {
      sign: "dd",
      type: PaperName,
      num: 100,
      topicnum: 55,
      manynum: 35,
      judgenum: 10
    } as TopicRollDataParams

    try {
      const res = await ApiService.GetTopicRollData(params)

      if(res.issucc) {
        // 单选
        const bankList = this.transformQuestions(
          res.data.bankdata.banklist,
          ClassificationTypeEnum.SIMPLE,
          QuestionTypeEnum.RADIO
        )
        // 判断
        const judgeList = this.transformQuestions(
          res.data.judgedata.judgelist,
          ClassificationTypeEnum.SIMPLE,
          QuestionTypeEnum.JUDGE
        )
        // 多选
        const manyList = this.transformQuestions(
          res.data.manydata.manylist,
          ClassificationTypeEnum.SIMPLE,
          QuestionTypeEnum.CHECK_BOX
        )

        let allQuestions = [...bankList, ...judgeList, ...manyList]
        allQuestions = this.shuffleArray(allQuestions)

        this.examManager = new ExamManager('模拟考试', allQuestions)
        this.examManager.timeLimit = 90

        // 数据加载完，初始化索引
        this.currentQuestionIndex = this.examManager.currentQuestionId
      }
    } catch (error) {
      console.log('错误', error)
    } finally {
      this.isLoading = false
    }
  }



  //分享
  async handleShare() {
    try {
      // 1. 获取截图 (根据 ID: drawing_board)
      const pixelMap = await componentSnapshot.get('drawing_board')

      // 2. 准备保存路径 (应用缓存目录)
      const context = getContext(this) as common.UIAbilityContext
      const fileName = `drawing_${new Date().getTime()}.png` // 防止文件名冲突
      const filePath = context.cacheDir + '/' + fileName

      // 3. 将图片写入文件
      const file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      const packer = image.createImagePacker()
      // 压缩为 PNG
      await packer.packToFile(pixelMap, file.fd, { format: 'image/png', quality: 100 })
      fs.closeSync(file.fd)

      // 4. 构造分享数据
      const uri = fileUri.getUriFromPath(filePath)
      const shareData = new systemShare.SharedData({
        utd: utd.UniformDataType.PNG,
        uri: uri,
        title: '危险化学品考试',
        description: '危险化学品考试通过王'
      })
      // 必须添加记录
      shareData.addRecord({
        utd: utd.UniformDataType.PNG,
        uri: uri,
        title: '危险化学品考试',
        description: '危险化学品考试通过王'
      })

      // 5. 拉起系统分享面板
      const controller = new systemShare.ShareController(shareData)
      controller.show(context, {
        previewMode: systemShare.SharePreviewMode.DEFAULT,
        selectionMode: systemShare.SelectionMode.SINGLE
      })

    } catch (e) {
      console.error('Share Error:', JSON.stringify(e))
    }
  }

  //将答案映射到索引
  private mapAnswerToIndex(correctChar: string): number {
    const upperChar = correctChar.toUpperCase().trim()

    if(!isNaN(Number(upperChar))) {
      return Number(upperChar) - 1
    }

    switch (upperChar) {
      case 'A': return 0
      case 'B': return 1
      case 'C': return 2
      case 'D': return 3
      default: return -1
    }
  }

  //将QuestionItem[]转为ExamDetail[]
  private transformQuestions(items: QuestionItem[], classification: ClassificationTypeEnum, type: QuestionTypeEnum): ExamDetail[]{
    if(!items || items.length === 0)
      return []

    return items.map(item => {
      let options: string[] = []
      if(item.option1) options.push(this.cleanOptionText(item.option1))
      if(item.option2) options.push(this.cleanOptionText(item.option2))
      if(item.option3) options.push(this.cleanOptionText(item.option3))
      if(item.option4) options.push(this.cleanOptionText(item.option4))

      let answerList: string[] = []
      if(type === QuestionTypeEnum.JUDGE) {
        if(item.correct === 'A' || item.correct === '正确') {
          answerList = [options[0]]
        } else {
          answerList = [options[1]]
        }
      }
      else if(type === QuestionTypeEnum.CHECK_BOX) {
        const correctChars = item.correct.split('')
        correctChars.forEach(char => {
          const index = this.mapAnswerToIndex(char)
          if(index != -1 && index < options.length){
            answerList.push(options[index])
          }
        })
      }
      else {
        const index = this.mapAnswerToIndex(item.correct)
        if(index != -1 && index < options.length){
          answerList = [options[index]]
        }
      }

      const examDetail = new ExamDetail(
        item.title,
        '',
        options,
        answerList,
        type,
        classification,
        item.analysis,
        item.source,
        undefined
      )
      // 保存原始题目ID
      examDetail.id = String(item.id)
      return examDetail
    })
  }

  //洗牌
  private shuffleArray(array: ExamDetail[]): ExamDetail[] {
    let m = array.length
    let t: ExamDetail
    let i: number
    while (m) {
      i = Math.floor(Math.random() * m--)
      t = array[m]
      array[m] = array[i]
      array[i] = t
    }
    return array;
  }

  //数据清洗
  private cleanOptionText(text: string): string{
    return text.replace(/^[A-Z0-9][\.\．\、]\s*/i, "").trim()
  }
}
