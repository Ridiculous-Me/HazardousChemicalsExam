import { ApiService, ListItem, ListParams, PromptMessage, AddParams, DetailsParam } from "common"
import { AppStorageV2 } from "@kit.ArkUI"
import { param } from "../../Home/Search/Seek" // 假设 param 是定义的传递给详情页的接口类型

@Builder
export function CollectionPageBuilder() {
  CollectionPage()
}

@Component
export struct CollectionPage {
  // 路由栈
  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack, () => new NavPathStack())!
  @StorageLink('userId') userid: string = ''

  @State searchContent: string = ''
  @State isLoading: boolean = false

  // --- 核心数据源 ---
  @State bankList: ListItem[] = []
  @State judgeList: ListItem[] = []
  @State manyList: ListItem[] = []

  // 总表
  @State likeList: ListItem[] = []

  @State currentIndex: number = 0
  private controller: TabsController = new TabsController()

  build() {
    NavDestination() {
      Column() {
        // 1. 顶部
        this.buildHeader()
        // 2. 搜索
        this.buildSearchBar()

        // 3. 内容区
        if (this.isLoading) {
          Column() {
            LoadingProgress().width(40).height(40).color(Color.Blue)
          }
          .width('100%').margin({ top: 50 }).justifyContent(FlexAlign.Center)
        } else {
          Column() {
            Tabs({ barPosition: BarPosition.Start, controller: this.controller }) {

              // --- 单选题 Tab ---
              TabContent() {
                CollectionListComponent({
                  list: $bankList,
                  icon: $r('app.media.bankList_1'),
                  currentUserId: this.userid,
                  // 【新增】传递点击回调
                  onItemClick: (item: ListItem) => {
                    this.getProblemInfo(item)
                  }
                })
              }.tabBar('单选')

              // --- 判断题 Tab ---
              TabContent() {
                CollectionListComponent({
                  list: $judgeList,
                  icon: $r('app.media.judgeList_1'),
                  currentUserId: this.userid,
                  // 【新增】传递点击回调
                  onItemClick: (item: ListItem) => {
                    this.getProblemInfo(item)
                  }
                })
              }.tabBar('判断')

              // --- 多选题 Tab ---
              TabContent() {
                CollectionListComponent({
                  list: $manyList,
                  icon: $r('app.media.manyList_1'),
                  currentUserId: this.userid,
                  // 【新增】传递点击回调
                  onItemClick: (item: ListItem) => {
                    this.getProblemInfo(item)
                  }
                })
              }.tabBar('多选')

            }
            .barMode(BarMode.Fixed)
            .barWidth('100%')
            .barHeight(50)
            .onChange((index: number) => {
              this.currentIndex = index
            })
          }
          .layoutWeight(1)
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#f5f5f5')
    }
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
    .hideTitleBar(true)
  }

  @Builder
  buildHeader() {
    Row() {
      Row() {
        Image($r('app.media.iv_back')).width(30)
      }
      .onClick(() => { this.pathStack.pop() })

      Row() {
        Text('我的收藏').fontSize(24).fontWeight(FontWeight.Medium)
      }
      .layoutWeight(1).padding({ right: 30 }).justifyContent(FlexAlign.Center)
    }
    .width('100%').padding({ top: 40, bottom: 10, left: 10, right: 10 }).backgroundColor(Color.White)
  }

  @Builder
  buildSearchBar() {
    Row() {
      Row() { Image($r('app.media.search')).width(26) }.margin({ right: 5, bottom: 4 })
      Row() {
        TextInput({ placeholder: '请输入搜索内容', text: this.searchContent })
          .borderRadius(10).backgroundColor('#F9F9F9').fontSize(14).height(36).width('100%')
          .onChange((value: string) => {
            this.searchContent = value
            if (value.length === 0) this.getLikeList()
          })
      }.layoutWeight(1).margin({ left: 10, right: 10 })
      Row() {
        Text('搜索').fontSize(16).fontColor(Color.Blue)
      }.margin({ left: 5, bottom: 6 })
      .onClick(() => { this.searchLikeList() })
    }
    .width('100%').height(60).alignItems(VerticalAlign.Bottom).padding({ bottom: 10, left: 20, right: 20 }).backgroundColor(Color.White)
  }

  aboutToAppear(): void {
    this.getLikeList()
  }

  processData(data: ListItem[]) {
    this.bankList = []
    this.judgeList = []
    this.manyList = []
    this.likeList = data
    for (let i = 0; i < this.likeList.length; i++) {
      if (this.likeList[i].cate === '单选') this.bankList.push(this.likeList[i])
      else if (this.likeList[i].cate === '判断') this.judgeList.push(this.likeList[i])
      else if (this.likeList[i].cate === '多选') this.manyList.push(this.likeList[i])
    }
  }

  async getLikeList() {
    this.isLoading = true
    try {
      const res = await ApiService.GetLikeList({ sign: 'dd', userid: this.userid })
      this.processData(res.data)
    } catch (error) {
      PromptMessage.showMessage('获取数据失败')
    } finally {
      this.isLoading = false
    }
  }

  async searchLikeList() {
    this.isLoading = true
    try {
      const res = await ApiService.getSearchCollect({ sign: 'dd', userid: this.userid, keyword: this.searchContent })
      this.processData(res.data)
    } catch (error) {
      PromptMessage.showMessage('搜索失败')
    } finally {
      this.isLoading = false
    }
  }

  // 获取收藏题目的信息并跳转
  async getProblemInfo(item: ListItem) {
    // 1. 准备请求参数
    let requestParam = {
      sign: 'dd',
      id: item.id
    } as DetailsParam

    // 2. 准备颜色
    let color = ''
    switch (item.cate) {
      case '单选':
        color = '#1afa29'
        break
      case '判断':
        color = '#1296db'
        break
      case '多选':
        color = '#f4ea2a'
        break
    }

    // 3. 准备跳转参数容器
    let navParam = {
      list: {},
      color: color,
      type: item.cate
    } as param

    this.isLoading = true // 建议加个loading状态
    try {
      const res = await ApiService.getSearchDetails(requestParam)

      // 填充数据
      navParam.list = res.data

      navParam.list.isLike = true

      console.log('nav'+navParam.list.isLike)

      // 4. 跳转页面
      // 注意：这里应该传递包含数据的 navParam，而不是 requestParam
      this.pathStack.pushPathByName('SeekDetails', navParam, false)
    } catch (error) {
      PromptMessage.showMessage('获取题目信息失败')
    } finally {
      this.isLoading = false
    }
  }
}

// =========================================================================
//  独立子组件
// =========================================================================
@Component
struct CollectionListComponent {
  @Link list: ListItem[]
  @Prop icon: Resource
  @Prop currentUserId: string
  @StorageLink('likeLength') LikeLength: number = 0
  // 【新增】定义一个函数属性，用于接收父组件传递的点击逻辑
  onItemClick: (item: ListItem) => void = () => {}

  async cancelLike(item: ListItem) {
    let param = {
      sign: 'dd',
      userid: parseInt(this.currentUserId) || 0,
      cate: item.cate,
      problemid: item.problemId?.toString()
    } as AddParams

    try {
      const res = await ApiService.AddLike(param)
      if (res.issucc) {
        PromptMessage.showMessage('取消收藏成功')
        // 使用 filter 过滤掉被删除的项
        this.list = this.list.filter(i => i !== item)

        if(this.LikeLength > 0) {
          this.LikeLength--
        }
      } else {
        PromptMessage.showMessage(res.msg || '取消失败')
      }
    } catch (error) {
      console.error('取消失败', error)
      PromptMessage.showMessage('网络异常')
    }
  }

  @Builder
  SwipeItemBuilder(item: ListItem) {
    Row() {
      Text('取消收藏')
        .fontColor(Color.White)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
    }
    .width('40%')
    .height('100%')
    .borderRadius(15)
    .backgroundColor(Color.Red)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.cancelLike(item)
    })
  }

  build() {
    if (this.list.length === 0) {
      Column() {
        Text('暂无相关收藏').fontColor(Color.Gray).fontSize(14).margin({ top: 50 })
      }.width('100%').height('100%').alignItems(HorizontalAlign.Center)
    } else {
      List({ space: 10 }) {
        ForEach(this.list, (item: ListItem) => {
          ListItem() {
            Row() {
              Image(this.icon).width(24).height(24).objectFit(ImageFit.Contain).margin({ right: 12 })
              Column() {
                Text(item.title || '无标题')
                  .fontSize(16)
                  .fontColor('#333333')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            }
            .width('100%').padding(15).backgroundColor(Color.White).borderRadius(8)
            // 【新增】绑定点击事件
            .onClick(() => {
              if (this.onItemClick) {
                this.onItemClick(item)
              }
            })
          }
          .swipeAction({
            end: this.SwipeItemBuilder(item)
          })
        }, (item: ListItem) => JSON.stringify(item))
      }
      .width('100%').height('100%').padding({ left: 15, right: 15, top: 10, bottom: 10 })
    }
  }
}
