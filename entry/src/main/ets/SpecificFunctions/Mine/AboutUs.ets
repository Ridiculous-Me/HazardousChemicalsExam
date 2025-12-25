
import { bundleManager, common, Want } from "@kit.AbilityKit"
import { AppStorageV2 } from "@kit.ArkUI"


@Builder
export function AboutUsBuilder() {
  AboutUs()
}

@Component
export struct AboutUs {

  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack,() => new NavPathStack())!

  @State version: string = ''

  aboutToAppear(): void {
    this.about()
  }

  async about() {
    // 获取应用版本名称
    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
      this.version = bundleInfo.versionName
    } catch (error) {
      console.error('Failed to get version name: ' + JSON.stringify(error))
    }
  }

  // 打开反馈页面
  static openFeedbackUrl(){
    try {
      // 使用系统默认浏览器打开反馈页面
      let want: Want = {
        action: "ohos.want.action.viewData",
        entities: ["entity.system.browsable"],
        uri: "https://beian.miit.gov.cn/#/home"
      }
      let context = getContext() as common.UIAbilityContext
      context.startAbility(want)
    } catch (error) {
      console.error("Failed to open feedback URL: " + JSON.stringify(error))
    }
  }


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
          })



          Row(){
            Text('关于我们')
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
          Image($r('app.media.app'))
            .width(80)
        }
        .margin({top: 40,bottom: 70})

        Column({space: 15}){
          Row(){
            Text('用户协议')
              .fontSize(16)
            Image($r('app.media.ic_news_details'))
              .width(20)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .borderWidth({bottom: 1})
          .borderColor(Color.Gray)
          .padding({bottom: 8})
          .onClick(() => {
            this.pathStack.pushPathByName('UserAgreement',null,false)
          })

          Row(){
            Text('隐私政策')
              .fontSize(16)
            Image($r('app.media.ic_news_details'))
              .width(20)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .borderWidth({bottom: 1})
          .borderColor(Color.Gray)
          .padding({bottom: 8})
          .onClick(() => {
            this.pathStack.pushPathByName('PrivacyPolicy',null,false)
          })

          Row(){
            Text('当前版本')
              .fontSize(16)
            Text(this.version)
              .fontSize(16)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .borderWidth({bottom: 1})
          .borderColor(Color.Gray)
          .padding({bottom: 8})
        }
        .padding({left: 20,right: 20})

        Row(){
          Text('备案号：湘ICP备2025150496号-4A')
            .fontSize(18)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({top: 70})
        .onClick(() => {
          console.info('点击了备案号')
          AboutUs.openFeedbackUrl()
        })

      }
    }
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
    .hideTitleBar(true)
  }
}