import mobShare from "@zztsdk/sharesdk"
import { shaEncryptSync } from '@abner/security'
import { PreferencesUtil } from '@pura/harmony-utils'
import { common } from "@kit.AbilityKit"
import { HashMap } from "@kit.ArkTS"
import { AxiosResponse } from "@ohos/axios"
import { HashonHelper } from "@zztsdk/zztcore"
import { instance, PromptMessage } from "common"

interface islogin {
  isLogin:  boolean
}

//请求登录参数
export interface loginParams {
  open_id: string,
  nickname?: string,
  sex?: string,
  headurl?: string,
  appid: string,
  sign: string
}

//微信请求的路径
export function getWXLogin(params: loginParams) {
  return instance({
    url: 'harmonyos.pub_wechat_login',
    baseURL: "http://query.csweimei.cn/app/",
    method: "get",
    params: params
  })
}

//服务器返回的用户参数
export interface userInfoType {
  user_id?: number
  app_id?: number
  tel?: string
  name?: string
  uid?: string
  pwd?: string
  headimg?: string
  src?: string
  ctime?: string
  lastip?: string
  lastapp?: string
  lasttime?: string
  ukey?: string
  agent?: string
  wx_openid?: string
  deviceid?: string
  mac?: string
  nickname?: string
  sex?: number

}

export interface isUserInfoType{
  userid?: string,
  sign: string
}

export function getUserInfo(params: isUserInfoType) {
  return instance({
    url: 'app/harmonyos.get_userinfo',
    baseURL: 'http://query.csweimei.cn/',
    method: 'get',
    params: params
  })
}

//微信返回的用户信息结构
export interface headImgType{
  openid?: string,
  nickname?: string,
  sex?: number,
  language?: string,
  city?: string,
  province?: string,
  country?: string,
  headimgurl?: string,
  privilege?: string[],
  unionid?: string
}

//登录调用的接口（登录成功后调用，非主要）
interface LoginUser {
  account:  number,
  nickName: string,
  imgurl: string,
  appname: string
}


//微信登录类

export class WechatLogin {

  public  userInfo: userInfoType = {} //登录后返回的用户信息

  public sign: string = ''

  public loginUser: LoginUser = {
    account: 0,
    nickName: '',
    imgurl: '',
    appname: ''
  }



  //加密方法
  async doMd(str: string | undefined): Promise<string> {
    let sha1 = shaEncryptSync(str,'SHA1')
    console.log('加密后结果',sha1)
    return sha1.toString()
  }

  //32位加密
  async doMd32(str: string | undefined): Promise<string> {
    let md5 = shaEncryptSync(str, 'MD5'); // 关键：算法改为MD5
    console.log('MD5加密后（32位）：', md5);
    return md5.toString();
  }

  //执行的微信登录，返回用户信息

  async getWXUserinfo(context: common.UIAbilityContext): Promise<userInfoType> {
    return new Promise(async (resolve, reject) => {
      try {
        let plat = await mobShare.ShareSDK.getInstance().getPlatformAsync(mobShare.Platform.Wechat)
        mobShare.ShareSDK.getInstance().setUIAbilityContext(context)

        let receive: mobShare.PlatformActionListener = {
          onComplete: async (platform: mobShare.IPlatform, action: number, res: Map<string, Object>) => {
            try {
              //解析微信返回的原始用户信息
              const rawUserInfo = JSON.parse(HashonHelper.fromMap(res)) as headImgType
              const openId = rawUserInfo.openid || platform.getDb().getOpenID()
              const nickname = rawUserInfo.nickname || platform.getDb().getUserName()
              const headimgurl = rawUserInfo.headimgurl || platform.getDb().getUserIcon()

              //更改为自己的appid
              const appid = 'jPYhiT6vx4M0HthE'
              let loginStr = `nickname=${nickname}&open_id=${openId}&headurl=${headimgurl}&appid=${appid}`
              let sign = await this.doMd(loginStr)

              //发送登录请求
              const loginRes: AxiosResponse = await getWXLogin({
                open_id: openId,
                nickname: nickname,
                headurl: headimgurl,
                appid: appid,
                sign: sign
              })

              this.userInfo = loginRes.data

              //发起获取用户信息的请求
              let userSign = await this.doMd(this.userInfo.user_id?.toString())
              const userInfoRes: AxiosResponse = await getUserInfo({
                userid: this.userInfo.user_id?.toString(),
                sign: userSign
              })

              this.userInfo = userInfoRes.data

              this.sign = sign

              //非登录主要
              const Imgurl = await this.doMd32(this.userInfo.headimg)
              this.loginUser = {
                account: this.userInfo.user_id!,
                nickName: this.userInfo.nickname!,
                imgurl: Imgurl,
                appname: '涂鸦绘画板'
              }

              console.log('微信登录用户信息：', JSON.stringify(this.userInfo))

              PersistentStorage.persistProp('UserInfoData',this.userInfo)

              PromptMessage.showMessage('登录成功')

              resolve(this.userInfo)
            } catch (error) {
              const errorMsg = `登录失败：${error}`
              PromptMessage.showMessage(errorMsg)
              reject(new Error(errorMsg))
            }
          },
          onError: (platform: mobShare.IPlatform, action: number, error: Error) => {
            const errorMsg = `登录失败：${error.message}`
            PromptMessage.showMessage(errorMsg)
            reject(new Error(errorMsg))
          },
          onCancel: (platform: mobShare.IPlatform, action: number) => {
            const errorMsg = '用户取消登录'
            PromptMessage.showMessage(errorMsg)
            reject(new Error(errorMsg))
          }
        }

        plat.setPlatformActionListener(receive)
        plat.showUser()

      } catch (error) {
        const errorMsg = `登录失败：${error}`
        PromptMessage.showMessage(errorMsg)
        reject(new Error(errorMsg))
      }
    })
  }



  //登录页面一开始就要加载
 async setWechatDevInfo(): Promise<boolean> {
    let map = new HashMap<string, Object>()
    map.set(mobShare.Platform_Info.APP_KEY, "wx436ee03014c5a74e") //微信id
    map.set(mobShare.Platform_Info.APP_SECRET, "f6045999002265a8023dd2c56efd9010") //微信key
    return mobShare.ShareSDK.getInstance().setPlatformDevInfoAsync(mobShare.Platform.Wechat, map)
  }

}