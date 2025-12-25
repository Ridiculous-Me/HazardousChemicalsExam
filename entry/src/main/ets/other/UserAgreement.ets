import { AppStorageV2 } from "@kit.ArkUI"
import web_webview from '@ohos.web.webview'

@Builder
export function UserAgreementBuilder() {
  UserAgreement()
}

interface Open{
  callback: () => void
}

@Preview
@Component
export struct UserAgreement {
  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack, "navPathStack", () => new NavPathStack())!

  webviewController: web_webview.WebviewController = new web_webview.WebviewController();

  @State open: Open = {callback: () => {}}

  build() {
    NavDestination(){
      Column() {
        Row() {
          Image($r('app.media.iv_back'))
            .width(30)
            .position({ left: 10, bottom: 5 })
            .onClick(() => {
              // if(this.open){
              //   this.open.callback()
              // }
              if(this.pathStack){
                this.pathStack.pop()
              }
            })
          Text('用户协议')
            .fontSize(22)
            .fontColor('#010101')
        }
        .width('100%')
        .height(80)
        .padding({ top: 10, bottom: 10 })
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Bottom)
        .backgroundColor('#ffffff')

        Web({
          src: 'http://privacy.csweimei.cn/user/yhxy.html?appname=危险化学品考试通过王',
          controller: this.webviewController
        })
          .width('100%')
          .height('88%')
          .padding({ top: 10 });
      }
      .height('100%')
      .width('100%')
    }
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.open = context.pathInfo.param as Open
    })
    .hideTitleBar(true)

  }

  aboutToDisappear(): void {
    if(this.open){
      this.open.callback()
    }
  }
}