import { AppStorageV2, componentSnapshot, PromptAction } from "@kit.ArkUI";
import { ClassificationTypeEnum, Exam, ExamController, ExamDetail, ExamManager, QuestionTypeEnum } from "exam"; // 您的 exam 包
import { common } from "@kit.AbilityKit";
import { fileIo as fs, fileUri } from '@kit.CoreFileKit'
import { image } from "@kit.ImageKit";
import { systemShare } from "@kit.ShareKit";
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { ApiService, DetailsParam, ListItem, ListParams, LoadingComponent, QuestionItem } from "common"; // 您的 common 包
import { AutoExamParams } from "./WrongPage"; // 引用参数接口


interface FlexibleItem {
  type?: string
  cate?: string
}

// --- 1. 定义绘图数据结构 (保持参考代码一致) ---
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
export function AutoExamPageBuilder() {
  AutoExamPage()
}

@Component
export struct AutoExamPage {
  // 接收用户ID
  @StorageLink('userId') userId: string = ''

  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack, () => new NavPathStack())!
  @State isLoading: boolean = true
  private examController: ExamController = ExamController.instance

  // --- 2. 状态变量 ---
  @State isSelectEraser: boolean = false
  @State isSelectPen: boolean = false
  @State isShowSetting: boolean = false

  // 绘图历史
  @State history: DrawPath[] = []
  @State redoStack: DrawPath[] = []

  // 绘图缓存 Map
  private allDrawingsMap: Map<number, QuestionDrawingState> = new Map()
  private currentQuestionIndex: number = 0

  // 绘图上下文
  private currentPath: DrawPath | null = null
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)

  // 考试管理器
  private examManager: ExamManager = new ExamManager('错题组卷', [])

  // 组卷数量参数
  @State examCount: number = 15
  // 标记是否有数据
  @State hasData: boolean = false

  aboutToAppear(): void {
    // 监听题目切换
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
            if (this.hasData) {
              Exam({
                appPathStack: this.pathStack,
                examManager: this.examManager
              })
                .layoutWeight(1)
                .width('100%')
                .height('100%')
            } else {
              // 空状态
              Column() {
                //Image($r('app.media.ic_empty_data')).width(120).margin({ bottom: 10 }) // 请确保资源存在
                Text('未获取到题目数据').fontColor('#999')
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
            }

            // 顶层：绘图遮罩
            if (this.isSelectPen) {
              this.buildDrawingCanvas()
            }
          }
          .layoutWeight(1)
          .width('100%')
          .alignContent(Alignment.TopStart)
          .id('auto_exam_board') // 截图ID
        } else {
          LoadingComponent()
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      this.pathStack.pop()
      return true
    })
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      // 获取参数
      const params = context.pathInfo.param as AutoExamParams
      if (params && params.count) {
        this.examCount = params.count
      }
      // 开始加载数据
      this.generateWrongPaper()
    })
  }

  // --- 3. 核心逻辑：加载错题数据 ---
  // 替代了参考代码中的 getMockData
  async generateWrongPaper() {
    this.isLoading = true
    this.hasData = false

    try {
      // 1. 获取错题列表
      const listParams: ListParams = {
        sign: 'dd',
        userid: this.userId
      }
      const listRes = await ApiService.GetWrongList(listParams)

      // 这里的 simpleList 类型就是您提供的 ListItem[]
      let simpleList: ListItem[] = listRes.data || []

      if (simpleList.length === 0) {
        this.isLoading = false
        return
      }

      // 2. 随机打乱
      simpleList = this.shuffleListArray(simpleList)

      // 3. 截取数量
      if (simpleList.length > this.examCount) {
        simpleList = simpleList.slice(0, this.examCount)
      } else {
        //PromptAction.showToast({ message: `错题数量不足，为您生成 ${simpleList.length} 道题目` })
      }

      // 4. 并发获取详情
      // 注意：Promise.all 保证返回数组的顺序与 simpleList 的顺序是一一对应的
      const detailPromises = simpleList.map((item) => {
        const detailParam: DetailsParam = { sign: 'dd', id: item.id }
        return ApiService.getWrongDetails(detailParam)
      })

      const responses = await Promise.all(detailPromises)

      // 5. 提取有效数据并【修正题型】
      const validItems: QuestionItem[] = []

      responses.forEach((res, index) => {
        if (res.issucc && res.data) {
          // res.data 是详情 (QuestionItem)
          let detailItem = res.data

          // simpleList[index] 是列表项 (ListItem)
          const originalItem = simpleList[index]

          // 【核心修复】：
          // 详情接口的 type 经常不准，但列表接口的 cate 是准的。
          // 我们直接用列表的 cate 覆盖详情的 type。
          // 这样 transformMixedQuestions 方法就能读到 "单选"、"多选"、"判断" 了
          if (originalItem.cate) {
            detailItem.type = originalItem.cate
          }

          validItems.push(detailItem)
        }
      })

      if (validItems.length === 0) {
        this.isLoading = false
        return
      }

      // 6. 数据清洗与转换
      // 此时 validItems 里的每一项，其 type 字段都已经被修正为 "单选"/"多选"/"判断"
      const allQuestions = this.transformMixedQuestions(validItems)

      // 7. 初始化管理器
      this.examManager = new ExamManager('错题练习', allQuestions)
      this.examManager.timeLimit = 0
      this.currentQuestionIndex = this.examManager.currentQuestionId
      this.hasData = true

    } catch (error) {
      console.error('错题组卷错误', error)
      //PromptAction.showToast({ message: '获取数据失败' })
    } finally {
      this.isLoading = false
    }
  }

  // --- 数据转换逻辑 (基于参考代码修改适配混合列表) ---
  private transformMixedQuestions(items: QuestionItem[]): ExamDetail[] {
    if (!items || items.length === 0) return []

    return items.map(item => {
      // 1. 动态确定题型 (因为列表是混合的)
      let type = QuestionTypeEnum.RADIO
      // 兼容 item.type 或 item.cate 字段
      const flexItem = item as FlexibleItem
      // 优先取 type，没有则取 cate，最后兜底为空字符串
      const typeStr = (flexItem.type || flexItem.cate || '').toString()

      if (typeStr.includes('判断')) {
        type = QuestionTypeEnum.JUDGE
      } else if (typeStr.includes('多选')) {
        type = QuestionTypeEnum.CHECK_BOX
      } else {
        type = QuestionTypeEnum.RADIO
      }

      // 2. 选项清洗 (完全复用参考代码)
      let options: string[] = []
      if (item.option1) options.push(this.cleanOptionText(item.option1))
      if (item.option2) options.push(this.cleanOptionText(item.option2))
      if (item.option3) options.push(this.cleanOptionText(item.option3))
      if (item.option4) options.push(this.cleanOptionText(item.option4))

      // 3. 答案解析 (完全复用参考代码)
      let answerList: string[] = []
      if (type === QuestionTypeEnum.JUDGE) {
        if (item.correct === 'A' || item.correct === '正确') {
          answerList = [options[0]] // 假设 options[0] 是正确/A
        } else {
          answerList = [options[1]]
        }
      }
      else if (type === QuestionTypeEnum.CHECK_BOX) {
        const correctChars = item.correct.split('')
        correctChars.forEach(char => {
          const index = this.mapAnswerToIndex(char)
          if (index != -1 && index < options.length) {
            answerList.push(options[index])
          }
        })
      }
      else {
        const index = this.mapAnswerToIndex(item.correct)
        if (index != -1 && index < options.length) {
          answerList = [options[index]]
        }
      }

      // 4. 构建对象
      const examDetail = new ExamDetail(
        item.title,
        '',
        options,
        answerList,
        type,
        ClassificationTypeEnum.SIMPLE,
        item.analysis,
        item.source || '错题本',
        undefined
      )
      examDetail.id = String(item.id)
      return examDetail
    })
  }

  // --- 工具方法 (完全复用参考代码) ---

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
      case 'E': return 4
      case 'F': return 5
      default: return -1
    }
  }

  // 选项正则清洗
  private cleanOptionText(text: string): string {
    return text ? text.replace(/^[A-Z0-9][\.\．\、]\s*/i, "").trim() : ""
  }

  // 列表洗牌 (ListParams用)
  private shuffleListArray(array: ListItem[]): ListItem[] {
    let m = array.length, t: ListItem, i: number
    while (m) {
      i = Math.floor(Math.random() * m--)
      t = array[m]
      array[m] = array[i]
      array[i] = t
    }
    return array
  }

  // --- 4. 绘图相关逻辑 (完全复用参考代码) ---

  @Builder
  buildDrawingCanvas() {
    Canvas(this.context)
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(255, 255, 255, 0.3)')
      .hitTestBehavior(HitTestMode.Block) // 关键：拦截事件
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

    // 更新索引
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
      setTimeout(() => {
        this.redraw()
      }, 10)
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

  // --- 5. 工具栏 (复用参考代码) ---
  @Builder
  buildTopToolbar() {
    Row() {
      // 返回
      Row() { Image($r('app.media.iv_back')).width(30) }
      .onClick(() => { this.pathStack.pop() })

      // 撤销
      Row() {
        Image($r('app.media.back_drawing')).width(20).opacity(this.history.length > 0 ? 1 : 0.3)
      }
      .onClick(() => { if (this.isSelectPen) this.undo() })

      // 重做
      Row() {
        Image($r('app.media.next_drawing')).width(20).opacity(this.redoStack.length > 0 ? 1 : 0.3)
      }
      .onClick(() => { if (this.isSelectPen) this.redo() })

      // 橡皮擦
      Row() {
        Image(this.isSelectEraser ? $r('app.media.Eraser_true') : $r('app.media.Eraser_false')).width(20)
      }
      .onClick(() => { if (this.isSelectPen) this.isSelectEraser = !this.isSelectEraser })

      // 画笔开关
      Row() {
        Image($r('app.media.Paint')).width(26).opacity(this.isSelectPen ? 1 : 0.3)
      }
      .onClick(() => {
        this.isSelectPen = !this.isSelectPen
        if (!this.isSelectPen) {
          this.isSelectEraser = false
        } else {
          this.redraw()
        }
      })

      // 分享
      Row() { Image($r('app.media.ic_share')).width(25) }
      .onClick(() => { this.handleShare() })

      // 设置
      Row() { Image($r('app.media.setting')).width(28) }
      .bindSheet($$this.isShowSetting, this.showSettingSheet(), {
        height: '25%', width: '100%', title: { title: '设置' }, backgroundColor: Color.White,
      })
      .onClick(() => { this.isShowSetting = !this.isShowSetting })
    }
    .width('100%').backgroundColor('#ffffff')
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
          .onChange((isOn: boolean) => { this.examController.showNext = isOn; });
      }.width(360).padding(10);

      Row() {
        Text('字体大小').fontSize(16).fontColor('rgba(0,0,0,0.90)');
        Blank();
        Row() {
          Slider({ value: this.examController.fontSize, min: 14, max: 22, step: 1 })
            .blockStyle({ type: SliderBlockType.IMAGE, image: $r('app.media.font_setting') })
            .blockSize({ width: 16, height: 16 })
            .onChange((value: number) => { this.examController.fontSize = value; });
        }.width('70%');
        Blank();
        Text(this.examController.fontSize.toString()).fontSize(16).fontColor('rgba(0,0,0,0.90)');
      }.padding(10).width(360);
    }.height('100%').margin({ left: '4%', right: '4%' });
  }

  async handleShare() {
    try {
      const pixelMap = await componentSnapshot.get('auto_exam_board')
      const context = getContext(this) as common.UIAbilityContext
      const fileName = `wrong_exam_${new Date().getTime()}.png`
      const filePath = context.cacheDir + '/' + fileName
      const file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      const packer = image.createImagePacker()
      await packer.packToFile(pixelMap, file.fd, { format: 'image/png', quality: 100 })
      fs.closeSync(file.fd)
      const uri = fileUri.getUriFromPath(filePath)
      const shareData = new systemShare.SharedData({
        utd: utd.UniformDataType.PNG,
        uri: uri,
        title: '错题练习',
        description: '我的错题记录'
      })
      shareData.addRecord({
        utd: utd.UniformDataType.PNG,
        uri: uri,
        title: '错题练习',
        description: '我的错题记录'
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
