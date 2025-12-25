import { App, AppStorageV2 } from '@kit.ArkUI'
import { ApiService, ListParams } from 'common'


@Builder
export function IndexBuilder() {
  Index()
}


//是否登录
PersistentStorage.persistProp('isLogin',false)

//是否同意隐私政策和服务协议
PersistentStorage.persistProp('isAgree',false)

//用户id
PersistentStorage.persistProp('userId','')

PersistentStorage.persistProp('sign','')

//历史存储
PersistentStorage.persistProp('history',[])

PersistentStorage.persistProp('likeLength',0)
PersistentStorage.persistProp('WrongLength',0)

PersistentStorage.persistProp('userInfo',{
  nickName: '',
  imgurl: ''
})




@Entry
@Component
struct Index {

  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack,() => new NavPathStack())!


  @StorageLink('isLogin') isLogin: boolean = false

  @StorageLink('isAgree') isAgree: boolean = false

  @StorageLink('likeLength') LikeLength: number = 0
  @StorageLink('WrongLength') wrongLength: number = 0
  @StorageLink('userId') userId: string = ''

  build() {
    Navigation(this.pathStack){

    }
    .onAppear(() => {
      console.log("app appear")
      if(this.isAgree){

        console.log('111')
        if(this.isLogin){
          this.pathStack.pushPathByName("Layout",null,false)
        }
        else {
          this.pathStack.replacePathByName("Layout",null,false)
        }
      }
      else {
        console.log('222')
        this.pathStack.pushPathByName("Splash",null,false)
      }
    })
    .hideTitleBar(true)

  }


  aboutToAppear(): void {
    this.getLikeList()
    this.getWrongList()
  }

  async getLikeList() {
    try {
      const res = await ApiService.GetLikeList({ sign: 'dd', userid: this.userId })
      this.LikeLength = res.data.length
    } catch (error) {
      console.error('MinePage: 获取收藏失败')
    }
  }

  async getWrongList() {
    let param = { sign: 'dd', userid: this.userId } as ListParams
    try {
      const res = await ApiService.GetWrongList(param)
      this.wrongLength = res.data.length
    } catch (error) {
      console.error('MinePage: 获取错题失败')
    }
  }

}