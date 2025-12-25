import mobShare from "@zztsdk/sharesdk"

import { shaEncryptSync } from '@abner/security'

import { common } from "@kit.AbilityKit"
import { HashMap } from "@kit.ArkTS"
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

//QQ请求的路径
export function getLogin(params: loginParams) {
  return instance({
    url: 'harmonyos.pub_qq_login',
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

//qq登录类

export class QQLogin {

  public  userInfo: userInfoType = {} //登录后返回的用户信息

  public sign: string = ''

  public loginUser: LoginUser = {
    account: 0,
    nickName: '',
    imgurl: '',
    appname: ''
  }





  //加密方法(40位）
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

  //执行的QQ登录，返回用户信息
  async getQQUserinfo(context: common.UIAbilityContext): Promise<userInfoType> {
    return new Promise(async (resolve,reject) => {
      try {
        mobShare.ShareSDK.getInstance().setUIAbilityContext(context)
        let plat = await mobShare.ShareSDK.getInstance().getPlatformAsync(mobShare.Platform.QQ)

        let receive: mobShare.PlatformActionListener = {
          onComplete: async (platform: mobShare.IPlatform, action: number, res: Map<string, Object>) => {

            try {
              const openId = platform.getDb().getOpenID()
              const userName = platform.getDb().getUserName()
              const userIcon = platform.getDb().getUserIcon()

              console.log('QQ登录请求原始参数：', JSON.stringify({
                openId: openId || 'undefined',
                userName: userName || 'undefined',
                userIcon: userIcon || 'undefined'
              }))



              let loginStr =`nickname=${userName}&open_id=${openId}&headurl=${userIcon}&appid=jPYhiT6vx4M0HthE` //登录请求id
              let sign = await this.doMd(loginStr) //等待加密完成

              const loginRes: AxiosResponse = await getLogin({
                open_id: openId,
                nickname: userName,
                headurl: userIcon,
                appid: 'jPYhiT6vx4M0HthE', //登录请求id
                sign: sign
              })

              this.userInfo = loginRes.data

              console.log('QQ登录结果：', JSON.stringify(loginRes.data))


              // 发起获取用户信息请求
              let userSign = await this.doMd(this.userInfo.user_id?.toString())

              const userInfoRes: AxiosResponse = await getUserInfo({
                userid: this.userInfo.user_id?.toString(),
                sign: userSign
              })


              this.userInfo = userInfoRes.data

              this.sign = sign  //加密结果

              //非登录主要
              const Imgurl = await this.doMd32(this.userInfo.headimg)
              this.loginUser = {
                account: this.userInfo.user_id!,
                nickName: this.userInfo.nickname!,
                imgurl: Imgurl,
                appname: '涂鸦绘画板'
              }

              console.log('QQ登录用户信息：', JSON.stringify(this.userInfo))

              // 持久化存储用户信息
              PersistentStorage.persistProp(`UserInfoData`, this.userInfo)

              PromptMessage.showMessage('登录成功')
              // 登录成功，将用户信息作为结果 resolve

              resolve(this.userInfo)


            }catch (error) {
              PromptMessage.showMessage(`登录失败: ${error.message}`)
              console.log('错误'+error)
              reject(error)
            }
          },
          onError: (platform: mobShare.IPlatform, action: number, error: Error) => {
            PromptMessage.showMessage(`登录失败: ${error.message}`)
            reject(error)
          },
          onCancel: (platform: mobShare.IPlatform, action: number) => {
            PromptMessage.showMessage('取消登录')
            reject(new Error('用户取消登录'))
          }
        }

        plat.setPlatformActionListener(receive)
        plat.showUser()
      } catch (error) {
        PromptMessage.showMessage(`登录失败: ${error.message}`)
        reject(error)
      }

    })
  }




  //登录页面一开始就要加载
  async setQQDevInfo(): Promise<boolean> {
    let map = new HashMap<string, Object>()
    map.set(mobShare.Platform_Info.APP_ID, "102022239") //QQId
    map.set(mobShare.Platform_Info.APP_KEY, "NhpnZ9XjjX8YjhQt") //QQKey
    map.set(mobShare.Platform_Info.REDIRECT_URL, "www")
    return mobShare.ShareSDK.getInstance().setPlatformDevInfoAsync(mobShare.Platform.QQ, map)
  }

}


