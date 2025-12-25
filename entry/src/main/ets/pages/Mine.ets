import { common } from "@kit.AbilityKit"
import { AppStorageV2 } from "@kit.ArkUI"
import axios, { AxiosResponse } from "@ohos/axios"
import mobShare from "@zztsdk/sharesdk"
import { ClipboardUtil, PromptMessage, ShareUtils, UserPreferencesManager } from "common"

export interface userInfo {
  nickname: string,
  headimg: string,
}

@Observed
class Particle {
  x: number = 0
  y: number = 0
  size: number = 0
  opacity: number = 0
  duration: number = 0

  constructor(x: number, y: number, size: number, opacity: number, duration: number) {
    this.x = x
    this.y = y
    this.size = size
    this.opacity = opacity
    this.duration = duration
  }
}

@Component
export struct Mine {

  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack,() => new NavPathStack())!

  @StorageLink('userId') userId: string = ''
  @StorageLink('sign') sign: string = ''
  @State qqAccount: string = '1050325088'

  // 动画状态
  @State bgAngle: number = 0
  @State animateState: boolean = false
  @State floatY: number = 0
  @State particles: Particle[] = []

  @StorageLink('userInfo') userInfo: userInfo = {
    nickname: '',
    headimg: ''
  }

  @StorageLink('isLogin') isLogin: boolean = false

  build() {
    Stack() {
      // 1. 安全底色
      Rect().width('100%').height('100%').fill(Color.White)

      // 2. 渐变背景
      Rect()
        .width('150%')
        .height('150%')
        .linearGradient({
          angle: this.bgAngle,
          colors: [
            ['#E0C3FC', 0.0],
            ['#8EC5FC', 0.5],
            ['#FFFFFF', 1.0]
          ]
        })
        .opacity(0.6)
        .animation({
          duration: 10000,
          curve: Curve.Linear,
          iterations: -1,
          playMode: PlayMode.Normal
        })
        .position({ x: '-25%', y: '-25%' })

      // 3. 粒子动画
      ForEach(this.particles, (item: Particle, index: number) => {
        Circle({ width: item.size, height: item.size })
          .fill('#8EC5FC')
          .position({
            x: item.x + '%',
            y: this.animateState ? (item.y - 30) + '%' : item.y + '%'
          })
          .opacity(this.animateState ? 0 : item.opacity)
          .animation({
            duration: item.duration,
            curve: Curve.Linear,
            iterations: -1,
            playMode: PlayMode.Normal
          })
      })

      // 4. 内容区域
      Column() {
        // 头像区
        Row() {
          Row() {
            Image(this.userInfo.headimg)
              .width(84)
              .height(84)
              .borderRadius(42)
              .border({ width: 4, color: '#FFFFFF' })
              .shadow({ radius: 15, color: 'rgba(142, 197, 252, 0.5)' })
          }
          .margin({ right: 20 })

          Column({ space: 8 }) {
            Text(this.userInfo.nickname)
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333')

            Text('探索未知的每一天')
              .fontSize(14)
              .fontColor('#666666')
              .fontWeight(FontWeight.Normal)
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .padding({ left: 30 })
        .margin({ top: 80, bottom: 40 }) // 调整了间距
        .translate({ y: this.floatY })

        // 功能面板
        Column() {
          // 列表项
          Column({ space: 0 }) {

            // 检查更新
            Row() {
              Row({ space: 15 }) {
                Image($r('app.media.check_updata')).width(22).fillColor('#FF6B6B')
                Text('检查更新').fontSize(16).fontColor('#333333')
              }
              Image($r('app.media.ic_my_details')).width(14).fillColor('#CCCCCC')
            }
            .width('100%')
            .padding(20)
            .justifyContent(FlexAlign.SpaceBetween)
            .onClick(() => {
              PromptMessage.showMessage('当前已是最新版本')
            })

            // 分享好友
            this.ListItem('分享好友', 'app.media.share', () => {
              const contxt = getContext(this) as common.UIAbilityContext
              let share: ShareUtils = new ShareUtils()
              share.shareApp(contxt)
            })

            // 意见反馈
            this.ListItem('意见反馈', 'app.media.feedback', () => {
              this.pathStack.pushPathByName('Feedback', null, false)
            })

            // 关于我们
            this.ListItem('关于我们', 'app.media.aboutUs', () => {
              this.pathStack.pushPathByName('AboutUs', null, false)
            })

            // 客服QQ
            Row() {
              Row({ space: 15 }) {
                Image($r('app.media.waterGroup')).width(22).fillColor('#8EC5FC')
                Text('客服QQ群').fontSize(16).fontColor('#333333')
              }
              Row({space: 10}) {
                Text(this.qqAccount).fontSize(14).fontColor('#999999')
                Text('复制')
                  .fontSize(12)
                  .fontColor('#FFFFFF')
                  .fontWeight(FontWeight.Medium)
                  .backgroundColor('#8EC5FC')
                  .padding({left:12, right: 12, top: 5, bottom: 5})
                  .borderRadius(14)
              }
            }
            .width('100%')
            .padding(20)
            .justifyContent(FlexAlign.SpaceBetween)
            .border({ width: { bottom: 0.5 }, color: '#F9F9F9' })
            .onClick(async () => {
              let isCopy = await ClipboardUtil.Clipboard(this.qqAccount)
              if (isCopy) PromptMessage.showMessage('已复制')
              else PromptMessage.showMessage('复制失败')
            })

            // 退出登录
            Row() {
              Row({ space: 15 }) {
                Image($r('app.media.exit')).width(22).fillColor('#FF6B6B')
                Text('退出登录').fontSize(16).fontColor('#333333')
              }
              Image($r('app.media.ic_my_details')).width(14).fillColor('#CCCCCC')
            }
            .width('100%')
            .padding(20)
            .justifyContent(FlexAlign.SpaceBetween)
            .onClick(() => {
              this.isLogin = false
              this.remove()
              this.remove1()
              this.remove2()
              this.pathStack.clear()
              this.pathStack.replacePathByName('Login', null, false)
            })

            // 注销账号
            Row() {
              Row({ space: 15 }) {
                Image($r('app.media.iv_cancellation_account')).width(22).fillColor('#FF6B6B')
                Text('注销账号').fontSize(16).fontColor('#333333')
              }
              Image($r('app.media.ic_my_details')).width(14).fillColor('#CCCCCC')
            }
            .width('100%')
            .padding(20)
            .justifyContent(FlexAlign.SpaceBetween)
            .onClick(async () => {

              // 1. 获取上下文 context (Preferences 需要用到)
              const context = getContext(this) as common.UIAbilityContext;

              // 2. 【新增】调用 UserPreferencesManager 删除该用户专属的存储文件
              // 注意：这里传入当前的 this.userId
              await UserPreferencesManager.getInstance().deleteUserStore(context, this.userId);
              console.log(`[Mine] 已清除用户 ${this.userId} 的 Preferences 数据`);

              this.remove()
              this.remove1()
              this.remove2()
              try {
                console.log('注销账号')
                await this.deleteAccount()
                PromptMessage.showMessage(this.deleteAccountResponse.msg)
                console.log(JSON.stringify(this.deleteAccountResponse))

                this.clearPersistentStorage()


                this.pathStack.clear()
                this.pathStack.pushPathByName('Login',null,false)
              } catch (error) {
                throw Error(error)
              }
            })

          }
          .width('100%')
        }
        .width('92%')
        .backgroundColor(Color.White)
        .borderRadius(24)
        .shadow({ radius: 30, color: 'rgba(142, 197, 252, 0.2)', offsetY: 10 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .onAppear(() => {
      this.initParticles()

      animateTo({ duration: 15000, curve: Curve.Linear, iterations: -1 }, () => {
        this.bgAngle = 360
      })
      this.animateState = true
      animateTo({ duration: 3000, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
        this.floatY = -15
      })
    })
  }

  async remove() {
    (await mobShare.ShareSDK.getInstance().getPlatformAsync(mobShare.Platform.QQ)).removeAccount()
  }
  async remove1() {
    (await mobShare.ShareSDK.getInstance().getPlatformAsync(mobShare.Platform.Wechat)).removeAccount()
  }
  async remove2() {
    (await mobShare.ShareSDK.getInstance().getPlatformAsync(mobShare.Platform.HUAWEI)).removeAccount()
  }

  private clearPersistentStorage() {
    const keysToDelete = [
      'isLogin','userId','sign','userInfo','history'
    ]
    keysToDelete.forEach(key => {
      PersistentStorage.deleteProp(key);
      // 同时删除 AppStorage 里的对应值，避免残留
      AppStorage.delete(key);
    });
    console.log('所有持久化数据已清理');
  }

  //注销账号
  @State deleteAccountParam: DeleteAccountParam = {
    userid: parseInt(this.userId),
    sign: this.sign
  }
  @State deleteAccountResponse: DeleteAccountRespoonse = {
    issucc: false,
    msg: '',
    code: ''
  }
  async deleteAccount(){
    try {
      const response:AxiosResponse<DeleteAccountRespoonse> = await axios.create({})
        .get<DeleteAccountRespoonse>('http://query.csweimei.cn/app/harmonyos.delete_login',{params: this.deleteAccountParam})
      this.deleteAccountResponse = response.data
    } catch (error) {
      console.error(error)
    }
  }


  // 通用列表项样式
  @Builder ListItem(text: string, icon: string, clickEvent: () => void) {
    Row() {
      Row({ space: 15 }) {
        Image($r(icon)).width(22).fillColor('#8EC5FC')
        Text(text).fontSize(16).fontColor('#333333')
      }
      Image($r('app.media.ic_my_details')).width(14).fillColor('#CCCCCC')
    }
    .width('100%')
    .padding(20)
    .justifyContent(FlexAlign.SpaceBetween)
    .border({ width: { bottom: 0.5 }, color: '#F9F9F9' })
    .onClick(clickEvent)
  }

  // 初始化粒子
  initParticles() {
    let tempParticles: Particle[] = []
    for (let i = 0; i < 20; i++) {
      let p = new Particle(
        Math.random() * 100,
        Math.random() * 100,
        Math.random() * 10 + 5,
        Math.random() * 0.5 + 0.1,
        Math.random() * 4000 + 3000
      )
      tempParticles.push(p)
    }
    this.particles = tempParticles
  }
}

interface DeleteAccountParam {
  userid: number
  sign: string
}

interface DeleteAccountRespoonse {
  issucc: boolean,
  msg: string
  code: string
}
