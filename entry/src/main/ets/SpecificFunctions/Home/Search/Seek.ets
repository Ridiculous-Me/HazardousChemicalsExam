import { AppStorageV2, Type } from "@kit.ArkUI"
import { ApiService, ListItem,
  ListParams,
  LoadingComponent, PromptMessage, QuestionItem, QuestionSearchParams } from "common"
import { PaperName } from "../../../exam/ExamComponent"


export interface param {
  list: QuestionItem,
  color: string,
  type: string //单选、多选、判断
}

@Builder
export function SeekBuilder() {
  Seek()
}

@Component
export struct Seek{

  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack,() => new NavPathStack())!

  @State isLoading: boolean = false

  @State isContent: boolean = false
  @State searchContent: string = ''

  @StorageLink('history') History: string[] = []

  @StorageLink('userId') userid: string = ''

  @State isSearch: boolean = false

  @State isClickBank: boolean = false
  @State isClickJudge: boolean = false
  @State isClickMany: boolean = false

  build() {
    NavDestination(){
      Column(){
        Row(){
          Row(){
            Image($r('app.media.iv_back'))
              .width(30)
          }
          .margin({right: 10, bottom: 4})
          .onClick(() => {
            this.pathStack.pop()
          })

          Row(){
            TextInput({placeholder: '请输入您想要搜索的内容',text: this.searchContent})
              .borderRadius(10)
              .backgroundColor('transparent')
              .borderWidth(1)
              .borderColor(Color.Gray)
              .fontSize(16)
              .placeholderFont()
              .height(36)
              .width('100%')
              .onChange(async (value: string) => {
                this.isContent = value.length > 0
                this.searchContent = value
              })

          }
          .layoutWeight(1)
          .margin({left: 10, right: 10})

          Row(){
            Text('搜索')
              .fontSize(18)
              .fontColor(Color.Black)
          }
          .margin({left: 10, bottom: 6})
          .onClick(async () => {
            if(!this.isContent) {
              PromptMessage.showMessage('请输入您想要搜索的内容')
            }
            else {
              this.History.push(this.searchContent)
              this.isSearch = true
              this.search()
            }
          })


        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .height(70)
        .alignItems(VerticalAlign.Bottom)
        .padding({bottom: 10, left: 20, right: 20})
        .margin({top: 20})


        if(!this.isSearch){
          Row(){
            Row(){
              Text('历史记录')
                .fontColor(Color.Gray)
                .fontSize(18)
                .margin({right: 15})
              Image($r('app.media.p110'))
                .width(18)
                .onClick(() => {
                  this.History = [] //删除历史记录
                })
            }
          }
          .width('100%')
          .height(30)
          .alignItems(VerticalAlign.Center)
          .padding({left: 20})
          .justifyContent(FlexAlign.Start)
          //换行显示历史记录

          Column(){
            if(this.History.length > 0) {
              Flex({wrap: FlexWrap.Wrap, direction: FlexDirection.Row, justifyContent: FlexAlign.Start}) {
                ForEach(this.History, (item: string, index:number) => {
                  Row(){
                    Text(item)
                      .fontSize(16)
                      .fontColor(Color.Black)
                  }
                  .backgroundColor('#b5a9d2')
                  .padding({left: 15, right: 15, top: 5, bottom: 5})
                  .borderRadius(10)
                  .margin({right: 10, bottom: 10})
                  .onClick(async () => {
                    //点击填充搜索框
                    this.searchContent = item
                    this.isSearch = true

                    this.search()
                  })
                })
              }
            }
          }
          .margin({left: 30, right: 10, top: 15})
        }
        else {
          if(this.isLoading){
            LoadingComponent()
          }
          else {
            if(this.bankList.length === 0&&this.judgeList.length === 0&&this.manyList.length === 0) {
              Row(){
                Text('暂无搜索结果')
                  .fontSize(18)
                  .fontColor(Color.Gray)
              }
            }
            else {
              Scroll() {
                Column({space: 10}) {
                  Column({space: 8}) {
                    Row(){
                      Row({space: 8}){
                        Image($r('app.media.bankList'))
                          .width(24)
                        Text('单选题')
                          .fontSize(20)
                      }

                      Row(){
                        Image(this.isClickBank? $r('app.media.pull_down_true') : $r('app.media.pull_down_false'))
                          .width(18)
                      }
                    }
                    .width('100%')
                    .padding({left: 10, right: 10})
                    .justifyContent(FlexAlign.SpaceBetween)
                    .backgroundColor(Color.White)
                    .borderRadius({topLeft: 15, topRight: 15})
                    .height(50)
                    .onClick(() => {
                      this.isClickBank = !this.isClickBank
                    })


                    if(this.isClickBank) {
                      Column({space: 8}){
                        ForEach(this.bankList, (item: QuestionItem, index: number) => {
                          Row({space: 8}){
                            Image($r('app.media.bankList_1'))
                              .width(20)

                            Text(item.title)
                              .fontSize(20)
                              .maxLines(1)
                              .layoutWeight(1)
                              .textOverflow({overflow: TextOverflow.Ellipsis})

                            Image(item.isLike? $r('app.media.like_true'): $r('app.media.like_false'))
                              .width(20)
                          }
                          .width('100%')
                          .padding({left: 10, right: 10})
                          .height(40)
                          .borderRadius(10)
                          .backgroundColor(Color.White)
                          .onClick(() => {

                            let param: param = {
                              list: item,
                              color: '#1afa29',
                              type: '单选'
                            }

                            this.pathStack.pushPathByName('SeekDetails',param,false)
                          })
                        })
                      }
                      .padding({left: 8, right: 8})
                    }
                  }

                  Column({space: 8}) {
                    Row(){
                      Row({space: 8}){
                        Image($r('app.media.judgeList'))
                          .width(24)
                        Text('判断题')
                          .fontSize(20)
                      }

                      Row(){
                        Image(this.isClickJudge? $r('app.media.pull_down_true') : $r('app.media.pull_down_false'))
                          .width(18)
                      }
                    }
                    .width('100%')
                    .padding({left: 10, right: 10})
                    .justifyContent(FlexAlign.SpaceBetween)
                    .backgroundColor(Color.White)
                    .borderRadius(15)
                    .borderRadius({topLeft: 15, topRight: 15})
                    .height(50)
                    .onClick(() => {
                      this.isClickJudge = !this.isClickJudge
                    })

                    if(this.isClickJudge) {
                      //判断题搜索展示
                      Column({space: 8}){
                        ForEach(this.judgeList, (item: QuestionItem, index: number) => {
                          Row({space: 8}){
                            Image($r('app.media.judgeList_1'))
                              .width(20)

                            Text(item.title)
                              .fontSize(20)
                              .maxLines(1)
                              .layoutWeight(1)
                              .textOverflow({overflow: TextOverflow.Ellipsis})

                            Image(item.isLike? $r('app.media.like_true'): $r('app.media.like_false'))
                              .width(20)
                          }
                          .width('100%')
                          .padding({left: 10, right: 10})
                          .height(40)
                          .borderRadius(10)
                          .backgroundColor(Color.White)
                          .onClick(() => {

                            let param: param = {
                              list: item,
                              color: '#1296db',
                              type: '判断'
                            }

                            this.pathStack.pushPathByName('SeekDetails',param,false)
                          })
                        })
                      }
                      .padding({left: 8, right: 8})
                    }
                  }


                  Column({space: 8}) {
                    Row(){
                      Row({space: 8}){
                        Image($r('app.media.manyList'))
                          .width(24)
                        Text('多选题')
                          .fontSize(20)
                      }

                      Row(){
                        Image(this.isClickMany? $r('app.media.pull_down_true') : $r('app.media.pull_down_false'))
                          .width(18)
                      }
                    }
                    .width('100%')
                    .padding({left: 10, right: 10})
                    .justifyContent(FlexAlign.SpaceBetween)
                    .backgroundColor(Color.White)
                    .borderRadius({topLeft: 15, topRight: 15})
                    .height(50)
                    .onClick(() => {
                      this.isClickMany = !this.isClickMany
                    })

                    if(this.isClickMany) {
                      //多选题搜索展示
                      Column({space: 8}){
                        ForEach(this.manyList, (item: QuestionItem, index: number) => {
                          Row({space: 8}){
                            Image($r('app.media.manyList_1'))
                              .width(20)

                            Text(item.title)
                              .fontSize(20)
                              .maxLines(1)
                              .layoutWeight(1)
                              .textOverflow({overflow: TextOverflow.Ellipsis})

                            Image(item.isLike? $r('app.media.like_true'): $r('app.media.like_false'))
                              .width(20)
                          }
                          .width('100%')
                          .padding({left: 10, right: 10})
                          .height(40)
                          .borderRadius(10)
                          .backgroundColor(Color.White)
                          .onClick(() => {
                            let param: param = {
                              list: item,
                              color: '#f4ea2a',
                              type: '多选'
                            }
                            this.pathStack.pushPathByName('SeekDetails',param,false)
                          })
                        })
                      }
                      .padding({left: 8, right: 8})
                    }
                  }
                }
                .padding({left: 10, right: 10,bottom: 100})
              }
              .scrollable(ScrollDirection.Vertical)
            }
          }
        }

      }
      .width('100%')
      .height('100%')
      .backgroundColor('#fdfafe')
    }
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
    .hideTitleBar(true)
  }

  //单选搜索显示
  @State bankList: QuestionItem[] = []
  //判断搜索显示
  @State judgeList: QuestionItem[] = []
  //多选搜索显示
  @State manyList: QuestionItem[] = []
  //搜索
  async search() {
    this.isLoading = true

    const paramsBank = {
      sign: 'dd',
      cate: '单选',
      type: PaperName,
      keyword: this.searchContent,
      pageindex: '1',
      pagesize: '300'
    } as QuestionSearchParams

    const paramsJudge = {
      sign: 'dd',
      cate: '判断',
      type: PaperName,
      keyword: this.searchContent,
      pageindex: '1',
      pagesize: '300'
    } as QuestionSearchParams

    const paramsMany = {
      sign: 'dd',
      cate: '多选',
      type: PaperName,
      keyword: this.searchContent,
      pageindex: '1',
      pagesize: '300'
    } as QuestionSearchParams

    try {
      const resBank = await ApiService.Search(paramsBank)
      if(resBank.issucc){
        this.bankList = resBank.data.splice(0, 200)
        this.bankList.forEach(item => {
          item.isLike = this.likeList.some(likeItem => likeItem.problemId == item.id)
          console.log('单选搜索结果'+item.isLike)
        })
      }

      const resJudge = await ApiService.Search(paramsJudge)
      if(resJudge.issucc){
        this.judgeList = resJudge.data.splice(0, 200)
        this.judgeList.forEach(item => {
          item.isLike = this.likeList.some(likeItem => likeItem.problemId === item.id)
        })
      }

      const resMany = await ApiService.Search(paramsMany)
      if(resMany.issucc){
        this.manyList = resMany.data.splice(0, 200)
        this.manyList.forEach(item => {
          item.isLike = this.likeList.some(likeItem => likeItem.problemId === item.id)
        })
      }

      console.log('单选搜索结果'+JSON.stringify(this.bankList))
      console.log('判断搜索结果'+JSON.stringify(this.judgeList))
      console.log('多选搜索结果'+JSON.stringify(this.manyList))

    } catch (error) {
      throw Error(error)
    } finally {
      this.isLoading = false
    }

  }


  aboutToAppear(): void {
    this.getLikeList()
  }

  //收藏列表
  @State likeList: ListItem[] = []
  async getLikeList() {
    let param = {
      sign: 'dd',
      userid: this.userid
    } as ListParams
    try {
      const res = await ApiService.GetLikeList( param)

      this.likeList = res.data

      console.log('收藏列表'+JSON.stringify(this.likeList))
    } catch (error) {
      throw Error(error)
    }
  }


}