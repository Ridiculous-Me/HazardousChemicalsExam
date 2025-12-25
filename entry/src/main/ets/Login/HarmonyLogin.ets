import mobShare from "@zztsdk/sharesdk"
import { shaEncryptSync } from '@abner/security'

import { common } from "@kit.AbilityKit"
import { AxiosResponse } from "@ohos/axios"
import { instance, PromptMessage } from "common"


//请求登录参数
export interface loginParams {
  open_id: string,
  nickname?: string,
  sex?: string,
  headurl?: string,
  appid: string,
  sign: string
}

//鸿蒙请求的路径
export function gethmLogin(params: loginParams) {
  return instance({
    url: 'harmonyos.pub_hw_login',
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


//登录调用的接口（登录成功后调用，非主要）
interface LoginUser {
  account:  number,
  nickName: string,
  imgurl: string,
  appname: string
}


//Harmony登录类

export class HarmonyLogin {

  public userInfo: userInfoType = {} //登录后返回的用户信息

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

  //执行的鸿蒙登录，返回用户信息
  async getHarmonyUserinfo(context: common.UIAbilityContext): Promise<userInfoType> {
    return new Promise(async (resolve, reject) => {
      try {
        let plat = await mobShare.ShareSDK.getInstance().getPlatformAsync(mobShare.Platform.HUAWEI)
        mobShare.ShareSDK.getInstance().setUIAbilityContext(context)

        let receive: mobShare.PlatformActionListener = {
          onComplete: async (platform: mobShare.IPlatform, action: number, res: Map<string, Object>) => {
            try {
              const openId = platform.getDb().getOpenID()
              const userName = platform.getDb().getUserName()
              const userIcon = platform.getDb().getUserIcon()

              const appid = 'yJYlW2CsTEayDYxJ'
              let loginStr = `nickname=${userName}&open_id=${openId}&headurl=${userIcon}&appid=${appid}`
              let sign = await this.doMd(loginStr)

              //发起登录请求
              const loginRes: AxiosResponse = await gethmLogin({
                open_id: openId,
                nickname: userName,
                headurl: userIcon,
                appid: appid,
                sign: sign
              })

              this.userInfo = loginRes.data

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
                account: this.userInfo.user_id || 0,
                nickName: this.userInfo.nickname || '',
                imgurl: Imgurl || '',
                appname: '危险化学品考试通关王'
              }


              console.log('鸿蒙登录用户信息:'+JSON.stringify(this.userInfo))

              PersistentStorage.persistProp('UserInfoData',this.userInfo)

              PromptMessage.showMessage('登录成功')
              resolve(this.userInfo)

            } catch (error) {
              const errorMsg = `登录失败`
              PromptMessage.showMessage(errorMsg)
              reject(error)
            }
          },
          onError: (platform: mobShare.IPlatform, action: number, error: Error) => {
            const errorMsg = `登录失败`
            PromptMessage.showMessage(errorMsg)
            reject(error)
          },
          onCancel: (platform: mobShare.IPlatform, action: number) => {
            const cancelMsg = `登录取消`
            PromptMessage.showMessage(cancelMsg)
            reject(new Error(cancelMsg))
          }

        }
        plat.setPlatformActionListener(receive)
        plat.showUser()
      } catch (error) {
        const errorMsg = `登录失败`
        PromptMessage.showMessage(errorMsg)
        reject(error)
      }
    })
  }




}