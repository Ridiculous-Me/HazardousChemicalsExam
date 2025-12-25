import { AppStorageV2 } from "@kit.ArkUI"
import axios, { AxiosResponse } from "@ohos/axios"
import { PromptMessage } from "common"


@Builder
export function FeedbackBuilder() {
  Feedback()
}

@Component
export struct Feedback {
  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack, "navPathStack", () => new NavPathStack())!


  @State suggest: string = ''

  @State contact: string = ''

  @State isSuggest: boolean = false

  @State isContact: boolean = false

  @StorageLink('account') account: number = 0


  build() {
    NavDestination(){
      Column(){
        Row(){
          Row(){
            Image($r('app.media.iv_back'))
              .width(30)
          }
          .onClick(() => {
            this.pathStack.pop()
            console.log('返回')
          })



          Row(){
            Text('意见反馈')
              .fontSize(24)
          }
          .layoutWeight(1)
          .padding({right: 34})
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .padding({top: 40,bottom: 10})
        .margin({bottom: 30})
        .backgroundColor(Color.White)



        Row(){
          TextArea({placeholder: '欢迎您提出宝贵的意见，我们将会为您提供更优质的服务'})
            .width('92%')
            .height(250)
            .borderRadius(10)
            .backgroundColor(Color.White)
            .onChange((value: string) => {
              this.suggest = value
              this.isSuggest = value.length > 0
            })
        }
        .margin({bottom: 20})

        Row(){
          TextInput({placeholder: '请留下您的联系方式（QQ或电话）'})
            .width('92%')
            .height(40)
            .padding({top: 10})
            .backgroundColor(Color.White)
            .borderRadius(10)
            .onChange((value: string) => {
              this.contact = value
              this.isContact = value.length > 0
            })
        }


        Row(){
          Text('提交反馈')
            .fontColor(Color.White)
            .fontSize(24)
        }
        .width('92%')
        .backgroundColor('#fe9068')
        .borderRadius(20)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .margin({top: '70%'})
        .onClick(async () => {
          if(!this.isSuggest){
            PromptMessage.showMessage('请填写反馈内容')
          }
          else if(this.isSuggest && (!this.isContact  || !(/^\d+$/.test(this.contact)))){
            PromptMessage.showMessage('联系方式格式错误，请重新输入')
          }
          else {
            try {
              await this.submitSuggest()
              this.pathStack.pop()
              PromptMessage.showMessage(this.submitRespone.msg)
            } catch (error) {
              console.log(error)
            }
          }
        })

      }
      .width('100%')
      .height('100%')
      .backgroundColor('#fafafa')
    }
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
    .hideTitleBar(true)
  }


  //提交意见
  @State submitParam: SubmitParmas = {
    uid: this.account,
    phone: this.contact,
    content: this.suggest,
    appname: '涂鸦绘本',
    sign: ''
  }
  @State submitRespone: SubmitResponse = {
    issucc: false,
    msg: '',
    code: ''
  }
  async submitSuggest(){
    try {
      const response: AxiosResponse<SubmitResponse> = await axios.create({})
        .post('http://query.csweimei.cn/app/feeback.tyhhb', this.submitParam)
      this.submitRespone = response.data
    } catch (error) {
      console.log(error)
    }
  }
}

interface SubmitParmas {
  uid: number,
  phone: string,
  content:  string,
  appname: string,
  sign:  string
}

interface SubmitResponse {
  issucc: boolean,
  msg: string,
  code: string
}