import { AppStorageV2, componentSnapshot } from "@kit.ArkUI";
import { ClassificationTypeEnum, Exam, ExamController, ExamDetail, ExamManager, QuestionTypeEnum } from "exam"; // 假设这是你的本地包

import { common } from "@kit.AbilityKit";
import { fileIo as fs, fileUri } from '@kit.CoreFileKit'
import { image } from "@kit.ImageKit";
import { systemShare } from "@kit.ShareKit";
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { ExamParam } from "./RandomPractice"; // 引用第一段代码定义的接口
import { PaperName } from "../../../exam/ExamComponent";
import { ApiService, getDataParams, LoadingComponent, QuestionDataResponse, QuestionItem } from "common";


// --- 绘图相关接口 (保持第二段代码结构) ---
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

interface QuestionDrawingState {
  history: DrawPath[]
  redoStack: DrawPath[]
}

@Builder
export function RandomExamPageBuilder() {
  RandomExamPage()
}

@Component
export struct RandomExamPage {
  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack, () => new NavPathStack())!

  // --- 接收参数配置 ---
  @State examConfig: ExamParam = { types: [], count: 0, timeLimit: 0 }

  @State isLoading: boolean = true
  private examController: ExamController = ExamController.instance

  // --- 状态变量 (UI控制) ---
  @State isSelectEraser: boolean = false
  @State isSelectPen: boolean = false
  @State isShowSetting: boolean = false

  // --- 绘图数据 ---
  @State history: DrawPath[] = []
  @State redoStack: DrawPath[] = []
  private allDrawingsMap: Map<number, QuestionDrawingState> = new Map()
  private currentQuestionIndex: number = 0
  private currentPath: DrawPath | null = null
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)

  // --- 核心管理器 ---
  private examManager: ExamManager = new ExamManager('随机练习', [])

  aboutToAppear(): void {
    // 监听题目切换 (保持第二段代码逻辑)
    this.examController.onIndexChange = (newIndex: number) => {
      this.handleQuestionChange(newIndex)
    }
  }

  build() {
    NavDestination() {
      Column() {
        this.buildTopToolbar()

        if (!this.isLoading) {
          Stack() {
            // 底层：答题区域
            Exam({
              appPathStack: this.pathStack,
              examManager: this.examManager
            })
              .layoutWeight(1)
              .width('100%')
              .height('100%')

            // 顶层：绘图遮罩
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
      // 倒计时模式下，拦截返回
      if (this.examConfig.timeLimit !== 0) {
        this.examController.isShowMockExamDialog = true
        return true
      }
      return false
    })
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      // 1. 获取上一页传来的参数
      const param = context.pathInfo.param as ExamParam
      if (param) {
        this.examConfig = param
        // 2. 根据参数加载数据
        this.loadRandomData()
      }
    })
  }

  // --- 核心业务逻辑：根据配置加载数据 ---
  async loadRandomData() {
    this.isLoading = true
    try {
      const totalCount = this.examConfig.count
      const selectedTypes = this.examConfig.types

      // 计算每种类型需要请求的数量 (向上取整，多出来的后面切掉)
      // 例如：总数10，选了[单选, 判断]，则各请求 5 题
      const countPerType = Math.ceil(totalCount / selectedTypes.length)

      const requestPromises: Promise<ExamDetail[]>[] = []

      // 根据选择的类型，并发请求不同的接口 (使用第三段代码的 API 逻辑)
      if (selectedTypes.includes('单选题')) {
        requestPromises.push(this.fetchQuestions(QuestionTypeEnum.RADIO, countPerType))
      }
      if (selectedTypes.includes('判断题')) {
        requestPromises.push(this.fetchQuestions(QuestionTypeEnum.JUDGE, countPerType))
      }
      if (selectedTypes.includes('多选题')) {
        requestPromises.push(this.fetchQuestions(QuestionTypeEnum.CHECK_BOX, countPerType))
      }

      // 等待所有请求完成
      const results = await Promise.all(requestPromises)

      // 合并结果
      let allQuestions: ExamDetail[] = []
      results.forEach(list => {
        allQuestions = allQuestions.concat(list)
      })

      // 洗牌 (随机打乱)
      allQuestions = this.shuffleArray(allQuestions)

      // 截取用户指定的总数量 (因为向上取整可能导致多出几题)
      if (allQuestions.length > totalCount) {
        allQuestions = allQuestions.slice(0, totalCount)
      }

      // 初始化 ExamManager
      this.examManager = new ExamManager('随机练习', allQuestions)

      // 设置时间限制 (0为不限时)
      this.examManager.timeLimit = this.examConfig.timeLimit

      // 初始化索引
      this.currentQuestionIndex = this.examManager.currentQuestionId

    } catch (error) {
      console.error('加载题目失败:', JSON.stringify(error))
      // 这里可以加一个 Toast 提示
    } finally {
      this.isLoading = false
    }
  }

  // 封装单个类型的请求逻辑
  async fetchQuestions(type: QuestionTypeEnum, num: number): Promise<ExamDetail[]> {
    const params: getDataParams = {
      sign: 'dd',
      type: PaperName,
      num: num
    }

    try {
      let res: QuestionDataResponse
      // 根据类型调用不同的 API (参考第三段代码)
      switch (type) {
        case QuestionTypeEnum.RADIO:
          res = await ApiService.GetBankData(params)
          break
        case QuestionTypeEnum.JUDGE:
          res = await ApiService.GetJudgeData(params)
          break
        case QuestionTypeEnum.CHECK_BOX:
          res = await ApiService.GetManyData(params)
          break
      }

      if (res.issucc && res.data) {
        // 转换数据格式
        return this.transformQuestions(res.data, ClassificationTypeEnum.SIMPLE, type)
      }
    } catch (e) {
      console.error(`Fetch ${type} error:`, e)
    }
    return []
  }

  // --- 数据转换逻辑 (结合第二段和第三段代码的清洗逻辑) ---
  private transformQuestions(items: QuestionItem[], classification: ClassificationTypeEnum, type: QuestionTypeEnum): ExamDetail[] {
    if (!items || items.length === 0) return []

    return items.map(item => {
      // 1. 选项清洗
      let options: string[] = []
      if (item.option1) options.push(this.cleanOptionText(item.option1))
      if (item.option2) options.push(this.cleanOptionText(item.option2))
      if (item.option3) options.push(this.cleanOptionText(item.option3))
      if (item.option4) options.push(this.cleanOptionText(item.option4))

      // 2. 答案解析
      let answerList: string[] = []

      if (type === QuestionTypeEnum.JUDGE) {
        // 判断题特殊处理
        if (item.correct === 'A' || item.correct === '正确') {
          answerList = [options[0]] // 假设 options[0] 是 "正确"
        } else {
          answerList = [options[1]] // 假设 options[1] 是 "错误"
        }
      }
      else if (type === QuestionTypeEnum.CHECK_BOX) {
        // 多选题处理 (如 "ABC")
        const correctChars = item.correct.split('')
        correctChars.forEach(char => {
          const index = this.mapAnswerToIndex(char)
          if (index !== -1 && index < options.length) {
            answerList.push(options[index])
          }
        })
      }
      else {
        // 单选题处理
        const index = this.mapAnswerToIndex(item.correct)
        if (index !== -1 && index < options.length) {
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

  // --- 工具函数 ---

  // 数据清洗 (正则来自第三段代码思路，但保留第二段的简洁)
  private cleanOptionText(text: string): string {
    // 去除 "A. ", "A、" 等前缀
    return text.replace(/^[A-Z0-9][\.\．\、]\s*/i, "").trim()
  }

  // 答案映射
  private mapAnswerToIndex(correctChar: string): number {
    const upperChar = correctChar.toUpperCase().trim()
    if (!isNaN(Number(upperChar))) {
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

  private shuffleArray(array: ExamDetail[]): ExamDetail[] {
    let m = array.length, t: ExamDetail, i: number
    while (m) {
      i = Math.floor(Math.random() * m--)
      t = array[m]
      array[m] = array[i]
      array[i] = t
    }
    return array
  }

  // --- 绘图功能 (完全保留第二段代码) ---
  @Builder
  buildDrawingCanvas() {
    Canvas(this.context)
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(255, 255, 255, 0.3)')
      .hitTestBehavior(HitTestMode.Block)
      .onReady(() => {
        this.redraw()
      })
      .onTouch((event: TouchEvent) => {
        this.handleTouch(event)
      })
  }

  handleQuestionChange(newIndex: number) {
    if (this.currentQuestionIndex === newIndex) return
    // 保存旧题
    this.allDrawingsMap.set(this.currentQuestionIndex, {
      history: [...this.history],
      redoStack: [...this.redoStack]
    })
    // 切换索引
    this.currentQuestionIndex = newIndex
    // 加载新题
    const savedState = this.allDrawingsMap.get(newIndex)
    if (savedState) {
      this.history = savedState.history
      this.redoStack = savedState.redoStack
    } else {
      this.history = []
      this.redoStack = []
    }
    if (this.isSelectPen) {
      this.redraw()
    }
  }

  handleTouch(event: TouchEvent) {
    event.stopPropagation()
    const x = event.touches[0].x
    const y = event.touches[0].y

    switch (event.type) {
      case TouchType.Down:
        this.context.beginPath()
        this.context.moveTo(x, y)
        this.context.lineCap = 'round'
        this.context.lineJoin = 'round'
        if (this.isSelectEraser) {
          this.context.lineWidth = 20
          this.context.globalCompositeOperation = 'destination-out'
        } else {
          this.context.lineWidth = 3
          this.context.strokeStyle = '#FF0000'
          this.context.globalCompositeOperation = 'source-over'
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
          this.allDrawingsMap.set(this.currentQuestionIndex, {
            history: [...this.history],
            redoStack: [...this.redoStack]
          })
        }
        break
    }
  }

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

  undo() {
    if (this.history.length > 0) {
      const lastPath = this.history.pop()
      if (lastPath) {
        this.redoStack.push(lastPath)
        this.redraw()
        this.allDrawingsMap.set(this.currentQuestionIndex, {
          history: [...this.history],
          redoStack: [...this.redoStack]
        })
      }
    }
  }

  redo() {
    if (this.redoStack.length > 0) {
      const path = this.redoStack.pop()
      if (path) {
        this.history.push(path)
        this.redraw()
        this.allDrawingsMap.set(this.currentQuestionIndex, {
          history: [...this.history],
          redoStack: [...this.redoStack]
        })
      }
    }
  }

  // --- 顶部工具栏 (保持第二段代码结构) ---
  @Builder
  buildTopToolbar() {
    Row() {
      // 返回
      Row() {
        Image($r('app.media.iv_back')).width(30)
      }
      .onClick(() => {
        if (this.examConfig.timeLimit !== 0) {
          this.examController.isShowMockExamDialog = true
        } else {
          this.pathStack.pop()
        }
      })

      // 撤销
      Row() {
        Image($r('app.media.back_drawing'))
          .width(20)
          .opacity(this.history.length > 0 ? 1 : 0.3)
      }
      .onClick(() => { if (this.isSelectPen) this.undo() })

      // 重做
      Row() {
        Image($r('app.media.next_drawing'))
          .width(20)
          .opacity(this.redoStack.length > 0 ? 1 : 0.3)
      }
      .onClick(() => { if (this.isSelectPen) this.redo() })

      // 橡皮擦
      Row() {
        Image(this.isSelectEraser ? $r('app.media.Eraser_true') : $r('app.media.Eraser_false'))
          .width(20)
      }
      .onClick(() => { if (this.isSelectPen) this.isSelectEraser = !this.isSelectEraser })

      // 画笔开关
      Row() {
        Image($r('app.media.Paint'))
          .width(26)
          .opacity(this.isSelectPen ? 1 : 0.3)
      }
      .onClick(() => {
        this.isSelectPen = !this.isSelectPen
        if (!this.isSelectPen) this.isSelectEraser = false
        else this.redraw()
      })

      // 分享
      Row() {
        Image($r('app.media.ic_share')).width(25)
      }
      .onClick(() => { this.handleShare() })

      // 设置
      Row() {
        Image($r('app.media.setting')).width(28)
      }
      .bindSheet($$this.isShowSetting, this.showSettingSheet(), {
        height: '25%',
        width: '100%',
        title: { title: '设置' },
        backgroundColor: Color.White,
      })
      .onClick(() => { this.isShowSetting = !this.isShowSetting })
    }
    .width('100%')
    .backgroundColor('#ffffff')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ left: 10, right: 10, top: 40, bottom: 10 })
  }

  @Builder
  showSettingSheet() {
    Column({ space: 20 }) {
      Row() {
        Text('答对自动下一题').fontSize(16).fontColor('rgba(0,0,0,0.90)');
        Blank();
        Toggle({ type: ToggleType.Switch, isOn: this.examController.showNext })
          .selectedColor($r('sys.color.comp_background_emphasize'))
          .onChange((isOn: boolean) => {
            this.examController.showNext = isOn;
          });
      }
      .width(360).padding(10);

      Row() {
        Text('字体大小').fontSize(16).fontColor('rgba(0,0,0,0.90)');
        Blank();
        Row() {
          Slider({
            value: this.examController.fontSize,
            min: 14, max: 22, step: 1,
            style: SliderStyle.OutSet,
          })
            .blockStyle({ type: SliderBlockType.IMAGE, image: $r('app.media.font_setting') })
            .blockSize({ width: 16, height: 16 })
            .onChange((value: number) => {
              this.examController.fontSize = value;
            });
        }
        .width('70%');
        Blank();
        Text(this.examController.fontSize.toString()).fontSize(16).fontColor('rgba(0,0,0,0.90)');
      }
      .padding(10).width(360);
    }
    .height('100%').margin({ left: '4%', right: '4%' });
  }

  async handleShare() {
    try {
      const pixelMap = await componentSnapshot.get('drawing_board')
      const context = getContext(this) as common.UIAbilityContext
      const fileName = `drawing_${new Date().getTime()}.png`
      const filePath = context.cacheDir + '/' + fileName
      const file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      const packer = image.createImagePacker()
      await packer.packToFile(pixelMap, file.fd, { format: 'image/png', quality: 100 })
      fs.closeSync(file.fd)
      const uri = fileUri.getUriFromPath(filePath)
      const shareData = new systemShare.SharedData({
        utd: utd.UniformDataType.PNG,
        uri: uri,
        title: '随机练习',
        description: '我的练习记录'
      })
      shareData.addRecord({
        utd: utd.UniformDataType.PNG,
        uri: uri,
        title: '随机练习',
        description: '我的练习记录'
      })
      const controller = new systemShare.ShareController(shareData)
      controller.show(context, {
        previewMode: systemShare.SharePreviewMode.DEFAULT,
        selectionMode: systemShare.SelectionMode.SINGLE
      })
    } catch (e) {
      console.error('Share Error:', JSON.stringify(e))
    }
  }
}
