import { AppStorageV2 } from '@kit.ArkUI';
import { UserPreferencesManager } from 'common';

@Builder
export function CitySelectPageBuilder() {
  CitySelectPage()
}

// ================== 1. 定义数据结构与静态数据 ==================
class CityGroup {
  key: string = ''      // 索引字母：热, A, B, C...
  cities: string[] = [] // 城市列表
}

// 内置的完整数据源
const CITY_DATA: CityGroup[] = [
  { key: '热', cities: ['北京', '上海', '广州', '深圳', '杭州', '成都', '武汉', '西安'] },
  { key: 'A', cities: ['安庆', '安阳', '鞍山', '安康', '阿克苏', '澳门'] },
  { key: 'B', cities: ['北京', '保定', '包头', '本溪', '蚌埠', '北海', '滨州'] },
  { key: 'C', cities: ['成都', '重庆', '长沙', '长春', '常州', '沧州', '赤峰'] },
  { key: 'D', cities: ['大连', '东莞', '大庆', '德阳', '大同', '丹东', '大理'] },
  { key: 'E', cities: ['鄂尔多斯', '恩施', '鄂州'] },
  { key: 'F', cities: ['福州', '佛山', '抚顺', '阜阳', '防城港'] },
  { key: 'G', cities: ['广州', '贵阳', '桂林', '赣州', '广元', '广安'] },
  { key: 'H', cities: ['杭州', '合肥', '哈尔滨', '海口', '呼和浩特', '邯郸', '惠州', '黄山'] },
  { key: 'J', cities: ['济南', '嘉兴', '金华', '吉林', '九江', '景德镇', '江门'] },
  { key: 'K', cities: ['昆明', '开封', '喀什', '克拉玛依'] },
  { key: 'L', cities: ['兰州', '拉萨', '洛阳', '柳州', '临沂', '连云港', '丽江'] },
  { key: 'M', cities: ['绵阳', '梅州', '马鞍山', '茂名'] },
  { key: 'N', cities: ['南京', '宁波', '南宁', '南昌', '南通', '南阳'] },
  { key: 'P', cities: ['平顶山', '盘锦', '莆田', '攀枝花'] },
  { key: 'Q', cities: ['青岛', '泉州', '秦皇岛', '齐齐哈尔', '衢州'] },
  { key: 'S', cities: ['上海', '深圳', '沈阳', '石家庄', '苏州', '三亚', '汕头', '绍兴'] },
  { key: 'T', cities: ['天津', '太原', '唐山', '泰安', '台州', '泰州'] },
  { key: 'W', cities: ['武汉', '无锡', '温州', '乌鲁木齐', '威海', '潍坊', '芜湖'] },
  { key: 'X', cities: ['西安', '厦门', '西宁', '徐州', '襄阳', '新乡', '许昌', '咸阳'] },
  { key: 'Y', cities: ['银川', '宜昌', '烟台', '扬州', '盐城', '营口', '岳阳', '延安'] },
  { key: 'Z', cities: ['郑州', '珠海', '淄博', '中山', '湛江', '张家口', '株洲', '遵义'] },
]
// =============================================================


@Component
export struct CitySelectPage {
  // 获取路由栈，用于返回上一页
  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack, () => new NavPathStack())!

  // 列表滚动控制器
  private scroller: Scroller = new Scroller()

  // 提取索引数组 ['热', 'A', 'B', ...]
  private alphabets: string[] = CITY_DATA.map(item => item.key)

  // 当前选中的索引位置（用于高亮右侧字母）
  @State selectedIndex: number = 0

  /**
   * 核心逻辑：选择城市并处理存储
   */
  async handleSelect(city: string) {
    try {
      // 1. 更新内存状态 (UI会立即响应)
      AppStorage.setOrCreate('CurrentCity', city)

      // 2. 持久化存储到本地文件 (下次打开还在)
      await UserPreferencesManager.getInstance().setValue('SelectedCity', city)

      console.info(`[CitySelectPage] City selected and saved: ${city}`)
    } catch (e) {
      console.error(`[CitySelectPage] Save failed: ${e}`)
    }

    // 3. 返回上一页
    this.pathStack.pop()
  }

  build() {
    NavDestination(){
      Column() {
        // === 1. 顶部标题栏 ===
        Row() {
          // 返回按钮
          Row() {
            Image($r('app.media.iv_back')) // ⚠️请确保您有这个返回图标资源
              .width(24)
              .height(24)
              .fillColor('#333')
          }
          .width(40)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.pathStack.pop()
          })

          Text('选择城市')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333')
            .layoutWeight(1) // 让文字居中或者占满
            .textAlign(TextAlign.Start)
            .margin({ left: 4 })
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 16,top: 30})
        .backgroundColor(Color.White)
        .shadow({ radius: 2, color: 'rgba(0,0,0,0.05)', offsetY: 1 }) // 浅阴影
        .zIndex(10) // 保证标题在最上层


        // === 2. 主体内容：Stack 堆叠 ===
        Stack({ alignContent: Alignment.End }) {

          // --- 左侧：城市列表 ---
          List({ scroller: this.scroller }) {
            ForEach(CITY_DATA, (group: CityGroup) => {
              // 分组头部 (A, B, C...)
              ListItemGroup({ header: this.GroupHeader(group.key) }) {

                if (group.key === '热') {
                  // === 样式A：热门城市 (网格布局) ===
                  ListItem() {
                    Flex({ wrap: FlexWrap.Wrap }) {
                      ForEach(group.cities, (city: string) => {
                        Text(city)
                          .width('29%') // 一行三个
                          .height(36)
                          .backgroundColor('#F5F7FA') // 浅灰蓝背景
                          .fontColor('#333')
                          .fontSize(14)
                          .borderRadius(6)
                          .textAlign(TextAlign.Center)
                          .margin({ right: '4%', bottom: 12 })
                          .onClick(() => this.handleSelect(city))
                      })
                    }
                    .padding({ top: 16, left: 16, right: 16, bottom: 4 })
                  }
                } else {
                  // === 样式B：普通城市 (列表布局) ===
                  ForEach(group.cities, (city: string) => {
                    ListItem() {
                      Column() {
                        Text(city)
                          .fontSize(16)
                          .fontColor('#333')
                          .width('100%')
                          .padding({ top: 16, bottom: 16, left: 20 })

                        // 细分割线
                        Divider()
                          .color('#F0F0F0')
                          .margin({ left: 20 })
                          .strokeWidth(0.5)
                      }
                      .backgroundColor(Color.White)
                      .onClick(() => this.handleSelect(city))
                    }
                  })
                }
              }
            })
          }
          .width('100%')
          .height('100%')
          .sticky(StickyStyle.Header) // 开启吸顶效果
          .scrollBar(BarState.Off) // 隐藏列表自带的滚动条
          .onScrollIndex((firstIndex: number) => {
            this.selectedIndex = firstIndex
          })

          // --- 右侧：字母索引条 ---
          AlphabetIndexer({ arrayValue: this.alphabets, selected: 0 })
            .selected(this.selectedIndex)
            .itemSize(18)
            // ✅ 修复：显式声明为 Font 类型，或者直接传符合 Font 接口的对象
            .font({ size: 11, color: '#666666' } as Font)
            .selectedFont({ size: 14, color: '#1890FF', weight: FontWeight.Bold } as Font)
            .popupColor('#1890FF')
            .popupFont({ size: 24, color: Color.White } as Font)
            .alignStyle(IndexerAlign.Right)
            .margin({ right: 4 })
            .onSelect((index: number) => {
              this.selectedIndex = index
              this.scroller.scrollToIndex(index)
            })
        }
        .layoutWeight(1) // 占满剩余高度
        .backgroundColor(Color.White)
      }
      .height('100%')
      .backgroundColor(Color.White)
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }

  // === 分组头部 Builder (热, A, B...) ===
  @Builder
  GroupHeader(key: string) {
    Row() {
      Text(key === '热' ? '热门推荐' : key)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1890FF') // 标题用主题色点缀一下
    }
    .width('100%')
    .height(36)
    .backgroundColor('#F2F4F8') // 稍微深一点的灰，区分内容
    .padding({ left: 16 })
  }
}
