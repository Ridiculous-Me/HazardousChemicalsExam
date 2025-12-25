import { AppStorageV2 } from "@kit.ArkUI"
import { common } from "@kit.AbilityKit"
import { PromptMessage } from "common"


@Builder
export function SplashBuilder() {
  Splash()
}

@Component
export struct Splash {

  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack,() => new NavPathStack())!
  @State checked: boolean = false
  @StorageLink('isAgree') isAgree: boolean = false


  build() {
    NavDestination() {
      Column() {
        // 弹窗内容
        Column() {
          // 标题
          Text("用户隐私协议弹窗")
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .margin({ top: 10, bottom: 8 })

          // 内容文本
          Text("感谢您使用本软件！为了帮助您安全使用产品和服务，请您在使用前务必仔细阅读《用户协议》与《隐私政策》，我们将严格遵守您同意的各项条款使用您的信息")
            .width('100%')
            .fontSize(12).padding(10)

          // 协议选择区域
          Row() {
            Checkbox({ name: '', group: '' })
              .width(20)
              .height(20)
              .select(this.checked)
              .onChange((isChecked: boolean) => {
                this.checked = isChecked
              })

            Text("我已阅读并同意")
              .fontSize(12)
              .fontColor(Color.Blue)
              .margin({ left: 5 })

            Text("《用户协议》")
              .fontSize(12)
              .fontColor(Color.Blue)
              .onClick(() => {
                this.pathStack.pushPathByName('UserAgreement',null,false)
              })

            Text("和")
              .fontSize(12)
              .fontColor(Color.Blue)

            Text("《隐私政策》")
              .fontSize(12)
              .fontColor(Color.Blue)
              .onClick(() => {
                this.pathStack.pushPathByName('PrivacyPolicy',null,false)
              })
          }
          .margin({ top: 12, bottom: 27 })

          // 底部按钮区域
          Row() {
            Text("不同意")
              .fontSize(16)
              .fontColor(Color.Gray)
              .onClick(() => {
                const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext
                context.terminateSelf()
              })
              .width('50%')
              .height(41)
              .textAlign(TextAlign.Center)

            Text("同意")
              .fontSize(16)
              .fontColor(Color.Blue)
              .onClick(() => {
                if(this.checked){
                  this.isAgree = true
                  this.pathStack.replacePathByName('Login',null,false)
                }
                else{
                  PromptMessage.showMessage('请先阅读并同意协议')
                }
              })
              .width('50%')
              .height(41)
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

        }
        .width(320)
        .backgroundColor(Color.White)
        .borderRadius(20)
      }
      .height('100%')
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundImage($r('app.media.entry'))
      .backgroundImageSize(ImageSize.Cover)
    }
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
    .onBackPressed(() => {
      return true
    })
    .hideTitleBar(true)
  }
}