import { AppStorageV2 } from "@kit.ArkUI"
import { PromptMessage } from "common"
import { common } from "@kit.AbilityKit"
import { HarmonyLogin } from "./HarmonyLogin"
import { userInfo } from "../pages/Mine"

@Builder
export function LoginBuilder() {
  Login()
}

@Component
export struct Login {

  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack,() => new NavPathStack())!

  @State isClick: boolean = false

  private  harmonyLogin: HarmonyLogin = new HarmonyLogin()

  @StorageLink('userId') userId: string = ''

  @StorageLink('isLogin') isLogin: boolean = false

  @StorageLink('sign') sign: string = ''

  @StorageLink('userInfo') userInfo: userInfo = {
    nickname: '',
    headimg: ''
  }

  build() {
    NavDestination(){
      Stack({ alignContent: Alignment.Bottom }) {
        // ---------------------------------------------------------
        // 1. 背景层：使用代码绘制的渐变背景
        // 不需要找背景图，直接用代码生成的高级感渐变
        // ---------------------------------------------------------
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 180, // 垂直向下渐变
            colors: [
              ['#E0F7FA', 0.0], // 顶部：极浅的青色，类似天空
              ['#FFFFFF', 0.5], // 中间：白色过渡
              ['#E3F2FD', 1.0]  // 底部：浅蓝色，呼应科技/学习感
            ]
          })

        // ---------------------------------------------------------
        // 2. 内容层：Slogan + 底部登录按钮
        // ---------------------------------------------------------
        Column() {
         Column(){
           // --- 顶部 Slogan 区域 ---
           Column() {
             Text('危险化学品')
               .fontSize(36)
               .fontWeight(FontWeight.Bold)
               .fontColor('#0D47A1') // 深蓝字，显眼
               .margin({ bottom: 10 })
               .letterSpacing(2)
             Text('考试通过王')
               .fontSize(40)
               .fontWeight(FontWeight.Bold)
               .fontColor('#0D47A1') // 深蓝字，显眼
               .margin({ bottom: 10 })
               .letterSpacing(2)

             Text("让考试更简单，更高效")
               .fontSize(16)
               .fontColor('#546E7A')
               .letterSpacing(1)
               .opacity(0.8)
           }
           .margin({ top: '30%' }) // 距离顶部的位置


           // --- 底部 登录区域 ---
           Column({space: 30}) {

             Row(){
               Image($r('app.media.ic_login_wechat'))
                 .width('70%')
             }
             .visibility(Visibility.Hidden)

             Row(){
               Image($r('app.media.ic_login_qq'))
                 .width('70%')
             }
             .visibility(Visibility.Hidden)

             Row(){
               Image($r('app.media.135'))
                 .width('70%')
             }
             .margin({top: -110})
             .zIndex(-9)
             .onClick(async () => {

               if(!this.isClick){
                 PromptMessage.showMessage('请勾选用户协议和隐私政策')
                 return
               }

               PromptMessage.showMessage('正在登录...')

               try {
                 const context = getContext(this) as common.UIAbilityContext

                 await this.harmonyLogin.getHarmonyUserinfo(context)

                 this.userId = this.harmonyLogin.userInfo.user_id!.toString()

                 this.sign = this.harmonyLogin.sign

                 this.isLogin = true


                 this.userInfo.nickname = this.harmonyLogin.loginUser.nickName
                 this.userInfo.headimg = this.harmonyLogin.loginUser.imgurl




                 this.pathStack.replacePathByName("Layout", null,false)

               } catch (error) {
                 PromptMessage.showMessage('登录失败')
               }
             })

           }
           .margin({top: '20%'})
         }

          Row(){
            Checkbox()
              .shape(CheckBoxShape.ROUNDED_SQUARE)
              .onChange((checked) => {
                this.isClick = checked
              })

            Row(){
              Text(){
                Span('请先阅读并同意')
                Span('用户协议')
                  .fontColor(Color.Blue)
                  .onClick(() => {
                    this.pathStack.pushPathByName('UserAgreement',null,false)
                  })
                Span('和')
                Span('隐私政策')
                  .fontColor(Color.Blue)
                  .onClick(() => {
                    this.pathStack.pushPathByName('PrivacyPolicy',null,false)
                  })
              }
            }
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({bottom: 20})
      }
    }
    .onBackPressed(() => {
      return true
    })
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
    .hideTitleBar(true)
  }

  // 封装登录按钮组件
  // 包含：图标 + 下方小文字 + 玻璃拟态背景效果
  @Builder LoginBtn(imgRes: Resource, text: string) {
    Column() {
      // 图标圆圈背景
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Image(imgRes)
          .width(32)
          .height(32)
          .objectFit(ImageFit.Contain)
      }
      .width(60)
      .height(60)
      .backgroundColor(Color.White) // 纯白背景
      .shadow({ radius: 10, color: '#1A000000', offsetY: 5 }) // 添加轻微阴影，增加立体感
      .onClick(() => {
        console.info(`点击了${text}登录`);
      })

      // 图标下方的文字
      Text(text)
        .fontSize(12)
        .fontColor('#78909C')
        .margin({ top: 8 })
    }
  }
}
