import { AppStorageV2 } from "@kit.ArkUI";
import { Login } from "../Login/Login";
import { Home } from "./Home";
import { KnowledgeBase } from "./KnowledgeBase";
import { Mine } from "./Mine";
import { PunchIn } from "./PunchIn";
import { Splash } from "./Splash";


@Builder
export function LayoutBuilder() {
  Layout()
}

@Component
export struct Layout {

  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack,() => new NavPathStack())!

  @State currentIndex: number = 0

  aboutToAppear(): void {
    console.log("Layout aboutToAppear")
  }

  build() {
    NavDestination(){
      Tabs({barPosition: BarPosition.End}){
        ForEach(basicBottom, (item: BasicBottom, index: number)=> {
          TabContent(){
            this.BottomTabsPage(index)
          }
          .tabBar(this.BottomTabsSet(item,index))
          .borderColor(Color.Gray)
          .borderWidth({bottom: 0.5})
          .expandSafeArea([SafeAreaType.SYSTEM],[SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
        })
      }
      .scrollable(false)
      .animationDuration(0)
      .onChange((index: number) => {
        this.currentIndex = index
      })
      .padding({bottom: 13})
      .backgroundColor(Color.White)
      .cachedMaxCount(1,TabsCacheMode.CACHE_BOTH_SIDE)
      .expandSafeArea([SafeAreaType.SYSTEM],[SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])

    }
    .onBackPressed(() => {
      return true
    })
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
    .hideTitleBar(true)
  }


  // 底部导航变换逻辑
  @Builder
  BottomTabsSet(item: BasicBottom, index: number) {
    Column(){
      Row(){
        Image(this.currentIndex === index ? item.click_icon : item.start_icon)
          .height(index === 2? 34:40)
      }
      .height(40)
      Text(item.icon_name)
        .fontSize(14)
        .fontColor(this.currentIndex === index ? Color.Black : Color.Gray)
    }
  }

  @Builder
  BottomTabsPage(index: number) {
    if (index === 0) {
      Home()
    }
    else  if(index === 1){
      KnowledgeBase()
    }
    else if (index === 2) {
      PunchIn()
    }
    else {
      Mine()
    }
  }

}

interface BasicBottom {
  start_icon: Resource,
  click_icon: Resource,
  icon_name: string
}

const basicBottom: BasicBottom[] = [
  {
    start_icon: $r("app.media.ic_tab1_false"),
    click_icon: $r("app.media.ic_tab1_true"),
    icon_name: "首页"
  },
  {
    start_icon: $r('app.media.ic_tab2_false'),
    click_icon: $r('app.media.ic_tab2_true'),
    icon_name: '知识库'
  },
  {
    start_icon: $r('app.media.static_false'),
    click_icon: $r('app.media.static_true'),
    icon_name: '统计'
  },
  {
    start_icon: $r("app.media.ic_tab4_false"),
    click_icon: $r("app.media.ic_tab4_true"),
    icon_name: "我的"
  }
]