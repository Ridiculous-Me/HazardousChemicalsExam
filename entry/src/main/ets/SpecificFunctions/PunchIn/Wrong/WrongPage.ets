import { AppStorageV2, PromptAction } from "@kit.ArkUI";
import { AddParams, ApiService, DetailsParam, ListItem, ListParams, PromptMessage, QuestionItem } from "common";
import { param } from "../../Home/Search/Seek";

// 导出参数接口，供 AutoExamPage 使用
export interface AutoExamParams {
  count: number
}

@Builder
export function WrongPageBuilder() {
  WrongPage()
}

@Component
export struct WrongPage {
  @State currentIndex: number = 0
  @StorageLink('userId') userId: string = ''
  @StorageLink('WrongLength') wrongLength: number = 0
  @StorageLink('likeLength') LikeLength: number = 0
  private controller: TabsController = new TabsController()
  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack, () => new NavPathStack())!

  // --- 核心状态 ---
  @State WrongList: ListItem[] = []
  @State likeList: ListItem[] = []
  @State isLoading: boolean = false

  // --- 弹窗控制器 ---
  dialogController: CustomDialogController = new CustomDialogController({
    builder: AutoExamDialog({
      // 使用 $ 传递引用，确保弹窗内能获取最新的 WrongList 长度用于校验
      wrongList: $WrongList,
      onConfirm: (count: number) => {
        this.startAutoExam(count)
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true,
    width: '85%'
  })

  aboutToAppear(): void {
    this.getWrongList()
    this.getLikeList()
  }

  // --- 获取错题列表 ---
  async getWrongList() {
    let param = { sign: 'dd', userid: this.userId } as ListParams
    try {
      const res = await ApiService.GetWrongList(param)
      console.log('错题列表'+JSON.stringify(res.data))
      this.WrongList = res.data || []
    } catch (error) {
      console.log('error' + error)
    }
  }

  // --- 获取收藏列表 ---
  async getLikeList() {
    let param = { sign: 'dd', userid: this.userId } as ListParams
    try {
      const res = await ApiService.GetLikeList(param)
      this.likeList = res.data || []
    } catch (error) {
      console.log('error' + error)
    }
  }

  // --- 业务逻辑 ---
  isLiked(item: ListItem): boolean {
    return this.likeList.some((likeItem) => likeItem.problemId?.toString() === item.problemId?.toString())
  }

  async getWrongInfo(item: ListItem) {
    let requestParam = { sign: 'dd', id: item.id } as DetailsParam
    let color = ''
    switch (item.cate) {
      case '单选': color = '#1afa29'; break
      case '判断': color = '#1296db'; break
      case '多选': color = '#f4ea2a'; break
      default: color = '#1afa29'; break
    }
    try {
      const res = await ApiService.getWrongDetails(requestParam)
      let questionData = res.data as QuestionItem
      if (questionData) {
        questionData.isLike = this.isLiked(item)
        let navParam: param = { list: questionData, color: color, type: item.cate }
        this.pathStack.pushPathByName('SeekDetails', navParam, false)
      }
    } catch (error) {
      console.error(error)
    }
  }

  async deleteWrong(item: ListItem) {
    let param = { sign: 'dd', id: item.id } as DetailsParam
    try {
      const res = await ApiService.deleteWrong(param)
      if (res.issucc) {
        PromptMessage.showMessage('删除成功')
        this.WrongList = this.WrongList.filter(i => i.id !== item.id)
        if(this.wrongLength > 0) {
          this.wrongLength--
        }
      }
    } catch (error) {
      console.log('error' + error)
    }
  }

  async cancelLike(item: ListItem) {
    let param = { sign: 'dd', userid: parseInt(this.userId), cate: item.cate, problemid: item.problemId?.toString() } as AddParams
    try {
      const res = await ApiService.AddLike(param)
      if (res.issucc) {
        PromptMessage.showMessage(res.msg)
        if (this.isLiked(item)) {
          this.likeList = this.likeList.filter(i => i.problemId?.toString() !== item.problemId?.toString())
          if(this.LikeLength > 0) {
            this.LikeLength--
          }
        } else {
          this.likeList.push(item)
          this.LikeLength++
        }
      }
    } catch (error) {
      console.log('error' + error)
    }
  }

  // --- 自动组卷跳转 ---
  startAutoExam(count: number) {
    // 再次校验双重保险
    if (this.WrongList.length === 0) {
      PromptMessage.showMessage('当前没有错题可组卷')
      return
    }
    const params: AutoExamParams = { count: count }
    this.pathStack.pushPathByName('AutoExamPage', params, false)
  }

  // --- UI 构建 ---
  @Builder DeleteActionBuilder(item: ListItem) {
    Column() {
      Text('删除').fontColor(Color.White).fontSize(16).fontWeight(FontWeight.Medium)
    }
    .width(80).height('100%').backgroundColor('#FF3B30').justifyContent(FlexAlign.Center)
    .borderRadius({ topLeft: 12, bottomLeft: 12 })
    .onClick(() => this.deleteWrong(item))
  }

  @Builder LikeActionBuilder(item: ListItem) {
    Column() {
      Text(this.isLiked(item) ? '取消收藏' : '收藏').fontColor(Color.White).fontSize(16).fontWeight(FontWeight.Medium)
    }
    .width(100).height('100%').backgroundColor('#ff9900').justifyContent(FlexAlign.Center)
    .borderRadius({ topRight: 12, bottomRight: 12 })
    .onClick(() => this.cancelLike(item))
  }

  getCateColor(cate: string): string {
    if (cate.includes('单选')) return '#3b5998'
    if (cate.includes('多选')) return '#ff9900'
    if (cate.includes('判断')) return '#19be6b'
    return '#999999'
  }

  @Builder TabBuilder(index: number, name: string) {
    Column() {
      Text(name)
        .fontColor(this.currentIndex === index ? '#007DFF' : '#666666')
        .fontSize(15)
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Normal)
        .margin({ top: 10, bottom: 8 })
      Divider()
        .strokeWidth(2)
        .color('#007DFF')
        .width(20)
        .opacity(this.currentIndex === index ? 1 : 0)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
  }

  @Builder WrongListContent(filterType: string) {
    Column() {
      if (this.WrongList.length === 0) {
        Column() {
          //Image($r('app.media.ic_empty_data')).width(100).margin({ bottom: 10 }) // 假设有空图
          Text('暂无错题数据').fontColor('#999').fontSize(14)
        }
        .width('100%')
        .margin({ top: 100 })
        .alignItems(HorizontalAlign.Center)
      } else {
        List({ space: 15 }) {
          ForEach(this.WrongList.filter(item => filterType === '全部' || item.cate === filterType), (item: ListItem) => {
            ListItem() {
              Column() {
                Row() {
                  Text(item.cate)
                    .fontSize(12).fontWeight(FontWeight.Medium).fontColor(Color.White)
                    .backgroundColor(this.getCateColor(item.cate))
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .borderRadius(4).margin({ right: 10 }).flexShrink(0)

                  Text(item.title)
                    .fontSize(16).fontColor('#333333').fontWeight(FontWeight.Medium)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)

                  Image(this.isLiked(item) ? $r('app.media.like_true') : $r('app.media.like_false'))
                    .width(20).height(20).margin({ left: 10 }).objectFit(ImageFit.Contain)
                }
                .alignItems(VerticalAlign.Center).width('100%')
              }
              .width('100%').padding(16).backgroundColor(Color.White).borderRadius(12)
              .shadow({ radius: 6, color: '#1a000000', offsetX: 0, offsetY: 2 })
              .onClick(() => { this.getWrongInfo(item) })
            }
            .swipeAction({ start: this.DeleteActionBuilder(item), end: this.LikeActionBuilder(item), edgeEffect: SwipeEdgeEffect.Spring })
          }, (item: ListItem) => JSON.stringify(item))
        }
        .width('100%').height('100%').padding({ left: 16, right: 16, top: 16, bottom: 16 })
      }
    }
    .width('100%').height('100%')
  }

  @Builder
  buildHeader() {
    Row() {
      // 返回
      Row() { Image($r('app.media.iv_back')).width(24).height(24) }
      .width(60).justifyContent(FlexAlign.Start)
      .onClick(() => { this.pathStack.pop() })

      // 标题
      Row() { Text('我的错题').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333333') }
      .layoutWeight(1).justifyContent(FlexAlign.Center)

      // 自动组卷按钮
      Row() {
        Text('自动组卷')
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor('#007DFF')
          .borderRadius(14)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .onClick(() => {
            if (this.WrongList.length === 0) {
              PromptMessage.showMessage('当前没有错题可组卷')
              return
            }
            this.dialogController.open()
          })
      }
      .width(80).justifyContent(FlexAlign.End)
    }
    .width('100%').padding({ top: 40, bottom: 10, left: 16, right: 16 })
    .backgroundColor(Color.White)
    .border({ width: { bottom: 0.5 }, color: '#e0e0e0' })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    NavDestination() {
      Column() {
        this.buildHeader()
        Column() {
          Tabs({ barPosition: BarPosition.Start, controller: this.controller }) {
            TabContent() { this.WrongListContent('全部') }.tabBar(this.TabBuilder(0, '全部'))
            TabContent() { this.WrongListContent('单选') }.tabBar(this.TabBuilder(1, '单选题'))
            TabContent() { this.WrongListContent('判断') }.tabBar(this.TabBuilder(2, '判断题'))
            TabContent() { this.WrongListContent('多选') }.tabBar(this.TabBuilder(3, '多选题'))
          }
          .vertical(false)
          .barMode(BarMode.Fixed)
          .barWidth('100%')
          .barHeight(44)
          .barBackgroundColor(Color.White)
          .backgroundColor('#f1f3f5')
          .onChange((index: number) => { this.currentIndex = index })
        }
        .layoutWeight(1).width('100%').backgroundColor('#f1f3f5')
      }
      .width('100%').height('100%').backgroundColor('#f1f3f5')
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }
}

// ----------------------------------------------------
// 自定义弹窗组件 (包含校验逻辑和自定义输入)
// ----------------------------------------------------
@CustomDialog
struct AutoExamDialog {
  controller: CustomDialogController
  onConfirm: (count: number) => void = () => {}

  // 接收父组件的错题列表引用，用于校验
  @Link wrongList: ListItem[]

  @State selectedCount: number = 10
  @State customCountStr: string = ''
  @State isCustom: boolean = false

  counts: number[] = [5, 10, 15, 20]

  build() {
    Column() {
      // 标题
      Text('自动组卷配置')
        .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333')
        .margin({ top: 20, bottom: 5 })

      // 实时显示总数
      Text(`当前共有 ${this.wrongList.length} 道错题`)
        .fontSize(12).fontColor('#007DFF').margin({ bottom: 20 })

      Text('选择或输入题数').fontSize(14).fontColor('#666').width('100%').margin({ bottom: 10 })

      // 预设选项
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(this.counts, (item: number) => {
          Text(`${item}题`)
            .fontSize(14)
            .fontColor((!this.isCustom && this.selectedCount === item) ? Color.White : '#666')
            .backgroundColor((!this.isCustom && this.selectedCount === item) ? '#007DFF' : '#f5f5f5')
            .padding({ top: 8, bottom: 8, left: 15, right: 15 })
            .borderRadius(20)
            .margin({ bottom: 10 })
            .onClick(() => {
              this.isCustom = false
              this.selectedCount = item
              this.customCountStr = ''
            })
        })
      }.width('100%').padding({ left: 10, right: 10 })

      // 自定义输入框
      Row() {
        Text('自定义:')
          .fontSize(14).fontColor('#333').margin({ right: 10 })

        TextInput({ placeholder: '输入题目数量', text: this.customCountStr })
          .type(InputType.Number)
          .layoutWeight(1)
          .height(40)
          .borderRadius(8)
          .backgroundColor(this.isCustom ? '#e6f2ff' : '#f5f5f5')
          .border({ width: 1, color: this.isCustom ? '#007DFF' : 'transparent' })
          .onChange((value: string) => {
            this.isCustom = true
            this.customCountStr = value
          })
          .onFocus(() => {
            this.isCustom = true
          })
      }
      .width('100%')
      .padding({ left: 10, right: 10 })
      .margin({ top: 5 })

      // 底部按钮
      Row() {
        Button('取消')
          .backgroundColor('#f5f5f5').fontColor('#666')
          .width('40%').margin({ right: 10 })
          .onClick(() => {
            this.controller.close()
          })

        Button('开始组卷')
          .backgroundColor('#007DFF').fontColor(Color.White)
          .width('40%')
          .onClick(() => {
            let finalCount = 0

            // 1. 获取用户意图的数字
            if (this.isCustom) {
              if (!this.customCountStr) {
                PromptMessage.showMessage('请输入题目数量')
                return
              }
              finalCount = parseInt(this.customCountStr)
            } else {
              finalCount = this.selectedCount
            }

            // 2. 基础合法性校验
            if (isNaN(finalCount) || finalCount <= 0) {
              PromptMessage.showMessage('题目数量必须大于0')
              return
            }

            // 3. 核心业务校验：不能超过总题数
            if (finalCount > this.wrongList.length) {
              // 提示用户，并 return 阻止关闭弹窗
              PromptMessage.showMessage(`数量不足，您只有 ${this.wrongList.length} 道错题`)
              return
            }

            // 4. 校验通过
            this.onConfirm(finalCount)
            this.controller.close()
          })
      }.margin({ top: 20, bottom: 20 })
    }
    .backgroundColor(Color.White)
    .borderRadius(16)
    .padding(16)
  }
}
