import { promptAction, SymbolGlyphModifier } from '@kit.ArkUI';
import common from '@ohos.app.ability.common';
import { UserPreferencesManager } from 'common';
// ⚠️ 请根据你的实际路径修改以下 Import
import { chemicalKnowledgeList } from '../SpecificFunctions/Knowledge/KnowledgeData';

// --- 类型定义 ---
// 修改：增加了 date 字段用于记录日期
interface NoteItem {
  id: number;
  content: string;
  time: string; // HH:mm
  date: string; // YYYY-MM-DD
}

@Component
export struct KnowledgeBase {
  // 1. 数据源
  private allKnowledge: string[] = chemicalKnowledgeList;

  // 【关键修改】添加 @Watch 监听器
  // 当 PersistentStorage 中的 userId 初始化完成或发生变化时，触发 onUserChange
  @StorageLink('userId') @Watch('onUserChange') userId: string = '';

  // 2. 状态变量
  @State searchText: string = '';
  @State currentRandomIndex: number = 0;

  @State myNotes: NoteItem[] = [];
  @State myFavorites: string[] = [];

  @State searchResults: string[] = [];
  @State isSearchMode: boolean = false;
  @State isShowAllMode: boolean = false;
  @State isRecitingMode: boolean = false;

  // 3. 控制器配置
  favDialogController: CustomDialogController = new CustomDialogController({
    builder: FavoritesDialog({
      favorites: this.myFavorites,
      onDelete: (item: string): void => this.toggleFavorite(item),
      onStartRecite: (): void => {
        this.startRecitation()
      }
    }),
    alignment: DialogAlignment.Bottom,
    offset: { dx: 0, dy: 0 },
    autoCancel: true,
    customStyle: true,
    backgroundColor: 'transparent'
  })

  dialogController: CustomDialogController = new CustomDialogController({
    builder: AddNoteDialog({
      onConfirm: (content: string): void => {
        this.addNote(content)
      }
    }),
    alignment: DialogAlignment.Bottom,
    offset: { dx: 0, dy: -20 },
    autoCancel: true,
    customStyle: true
  })

  // --- 生命周期与初始化 ---
  aboutToAppear(): void {
    this.refreshRandomKnowledge();
    // 如果页面加载时 userId 已经存在（非空），立即加载数据
    if (this.userId) {
      this.initData();
    }
  }

  // 【关键逻辑】监听用户切换
  async onUserChange() {
    if (this.userId) {
      console.info(`[KnowledgeBase] 监测到用户切换: ${this.userId}，正在刷新数据...`);
      await this.initData();
    } else {
      // 如果 userId 变为空（例如退出登录），清空当前展示的数据
      this.myNotes = [];
      this.myFavorites = [];
      promptAction.showToast({ message: '已退出登录' });
    }
  }

  // 初始化数据：根据 userId 加载对应的 Preferences
  async initData() {
    if (!this.userId) return;
    const context = getContext(this) as common.UIAbilityContext;

    // 1. 初始化该用户的专属仓库 (store_{userId})
    await UserPreferencesManager.getInstance().initUser(context, this.userId);

    // 2. 读取数据
    // 注意：虽然 Key 叫 'my_notes_store'，但因为文件不同，实现了用户隔离
    this.myNotes = await UserPreferencesManager.getInstance().getValue<NoteItem[]>('my_notes_store', []);
    this.myFavorites = await UserPreferencesManager.getInstance().getValue<string[]>('my_fav_store', []);
  }

  // --- 持久化存储 ---
  async saveNotesToDisk() {
    if (!this.userId) return;
    await UserPreferencesManager.getInstance().setValue('my_notes_store', this.myNotes);
  }

  async saveFavToDisk() {
    if (!this.userId) return;
    await UserPreferencesManager.getInstance().setValue('my_fav_store', this.myFavorites);
  }

  // --- 业务逻辑 ---
  toggleFavorite(content: string) {
    if (!this.userId) {
      promptAction.showToast({ message: '请先登录后收藏' });
      return;
    }
    const index = this.myFavorites.indexOf(content);
    if (index !== -1) {
      this.myFavorites.splice(index, 1);
      promptAction.showToast({ message: '已取消收藏' });
    } else {
      this.myFavorites.push(content);
      promptAction.showToast({ message: '已收藏' });
    }
    this.saveFavToDisk();
  }

  isFavorited(content: string): boolean {
    return this.myFavorites.includes(content);
  }

  refreshRandomKnowledge(): void {
    if (this.allKnowledge.length === 0) return;
    let newIndex = Math.floor(Math.random() * this.allKnowledge.length);
    while (newIndex === this.currentRandomIndex && this.allKnowledge.length > 1) {
      newIndex = Math.floor(Math.random() * this.allKnowledge.length);
    }
    this.currentRandomIndex = newIndex;
  }

  addNote(content: string): void {
    if (!content.trim()) return;
    if (!this.userId) {
      promptAction.showToast({ message: '请先登录以保存笔记' });
      return;
    }

    const now = new Date();
    // 格式化时间 HH:mm
    const timeStr = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
    // 格式化日期 YYYY-MM-DD
    const dateStr = `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}-${now.getDate().toString().padStart(2, '0')}`;

    const newNote: NoteItem = {
      id: Date.now(),
      content: content,
      time: timeStr,
      date: dateStr // 保存日期
    };

    this.myNotes.unshift(newNote);
    this.saveNotesToDisk();
    promptAction.showToast({ message: '笔记已保存' });
  }

  deleteNote(index: number) {
    this.myNotes.splice(index, 1);
    this.saveNotesToDisk();
    promptAction.showToast({ message: '已删除' });
  }

  handleSearch(value: string) {
    this.searchText = value;
    if (!value.trim()) {
      this.isSearchMode = false;
      this.searchResults = [];
      return;
    }
    this.isSearchMode = true;
    this.searchResults = this.allKnowledge.filter(item => item.includes(value));
  }

  startRecitation() {
    if (this.myFavorites.length === 0) {
      promptAction.showToast({ message: '收藏夹为空，无法背诵' });
      return;
    }
    animateTo({ duration: 400, curve: Curve.FastOutSlowIn }, () => {
      this.isRecitingMode = true;
    })
  }

  // --- UI 构建 ---
  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {

      // 层级1: 主界面内容
      Column() {
        this.HeaderTitle()
        this.HeaderSearch()

        List({ space: 16 }) {
          if (this.isSearchMode) {
            // --- 搜索模式 ---
            ListItem() { Text(`搜索结果: 共 ${this.searchResults.length} 条`).fontSize(14).fontColor(Color.Gray).margin({left:4}) }
            ForEach(this.searchResults, (text: string, index: number) => {
              ListItem() { this.SearchResultItem(text, index) }
            })

          } else if (this.isShowAllMode) {
            // --- 查看所有知识点模式 ---
            ListItem() { Text(`知识库全集: 共 ${this.allKnowledge.length} 条`).fontSize(14).fontColor(Color.Gray).margin({left:4}) }
            ForEach(this.allKnowledge, (text: string, index: number) => {
              ListItem() { this.SearchResultItem(text, index) }
            })

          } else {
            // --- 默认 Dashboard 模式 ---
            ListItem() { this.RandomCard() }
            ListItem() { this.FavoriteEntryCard() }

            // 笔记标题
            ListItem() {
              Row() {
                Text("我的速记").fontSize(18).fontWeight(FontWeight.Bold)
                Blank()
                Text(`共 ${this.myNotes.length} 条`).fontSize(12).fontColor(Color.Gray)
              }
              .width('100%').padding({ left: 4 })
            }

            // 笔记列表
            if (this.myNotes.length === 0) {
              ListItem() {
                Column() {
                  Text("暂无笔记").fontSize(14).fontColor('#CCC').margin({top: 20})
                }.width('100%').alignItems(HorizontalAlign.Center)
              }
            } else {
              ForEach(this.myNotes, (item: NoteItem, index: number) => {
                ListItem() { this.NoteItemView(item) }
                .swipeAction({ end: this.DeleteButton(index) })
              }, (item: NoteItem) => item.id.toString())
            }
          }
          ListItem().height(80)
        }
        .width('100%').layoutWeight(1).padding({ left: 16, right: 16 }).scrollBar(BarState.Off)
      }
      .width('100%').height('100%')
      .backgroundColor('#F1F3F5')
      .visibility(this.isRecitingMode ? Visibility.Hidden : Visibility.Visible)

      // 层级2: 悬浮添加按钮
      if (!this.isSearchMode && !this.isRecitingMode && !this.isShowAllMode) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.plus')).fontSize(30).fontColor([Color.White]).fontWeight(FontWeight.Bold)
        }
        .width(56).height(56).backgroundColor('#007DFF')
        .shadow({ radius: 10, color: 'rgba(0,125,255,0.4)', offsetY: 4 })
        .margin({ right: 24, bottom: 30 })
        .onClick(() => { this.dialogController.open() })
      }

      // 层级3: 沉浸式背诵全屏视图
      if (this.isRecitingMode) {
        ImmersiveRecitationView({
          list: $myFavorites,
          onExit: () => {
            animateTo({ duration: 300 }, () => {
              this.isRecitingMode = false;
            })
          },
          onRemoveItem: (item: string) => {
            this.toggleFavorite(item);
          }
        })
          .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
          .zIndex(999)
      }
    }
    .width('100%').height('100%')
  }

  // --- 子组件 Builder ---
  @Builder HeaderTitle() {
    Row() {
      if (this.isShowAllMode) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24).fontColor(['#333']).fontWeight(FontWeight.Bold)
        }
        .backgroundColor('transparent').width(40).height(40).margin({ right: 8, left: -10 })
        .onClick(() => {
          animateTo({ duration: 300 }, () => { this.isShowAllMode = false })
        })
      }

      Text(this.isShowAllMode ? "所有知识点" : "危险化学品知识库")
        .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#333')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 4 })
    .backgroundColor('#F1F3F5')
    .margin({top: 30})
    .alignItems(VerticalAlign.Center)
  }

  @Builder HeaderSearch() {
    Row() {
      Search({ value: this.searchText, placeholder: '搜：运输、储存、腐蚀...' })
        .width('100%').height(40).backgroundColor(Color.White).placeholderColor('#999')
        .onChange((value) => { this.handleSearch(value) })
    }
    .padding({ top: 8, bottom: 12, left: 16, right: 16 }).backgroundColor('#F1F3F5')
  }

  @Builder
  RandomCard() {
    Column() {
      Row() {
        Text("💡 每日一学").fontColor('#FF9800').fontWeight(FontWeight.Bold).fontSize(14)
        Blank()
        Row() {
          Text("更多").fontSize(13).fontColor('#666')
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor(['#666'])
        }
        .onClick(() => {
          animateTo({ duration: 300 }, () => { this.isShowAllMode = true })
        })
      }
      .width('100%').margin({ bottom: 12 })

      if (this.allKnowledge.length > 0) {
        Text(this.allKnowledge[this.currentRandomIndex]).fontSize(16).fontColor('#333').lineHeight(26).margin({ bottom: 16 })
      }

      Row() {
        Row() {
          Text("换一条 ").fontSize(12).fontColor('#007DFF')
          SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(14).fontColor(['#007DFF'])
        }
        .backgroundColor('rgba(0,125,255,0.08)')
        .padding({left: 10, right: 10, top: 6, bottom: 6})
        .borderRadius(14)
        .onClick(() => { animateTo({ duration: 300 }, () => { this.refreshRandomKnowledge() }) })

        Blank()

        if (this.allKnowledge.length > 0) {
          SymbolGlyph(this.isFavorited(this.allKnowledge[this.currentRandomIndex]) ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
            .fontSize(22)
            .fontColor(this.isFavorited(this.allKnowledge[this.currentRandomIndex]) ? ['#FFB900'] : ['#CCC'])
            .onClick(() => { this.toggleFavorite(this.allKnowledge[this.currentRandomIndex]) })
        }
      }
      .width('100%')
    }
    .width('100%').padding(20).backgroundColor(Color.White).borderRadius(16).shadow({ radius: 12, color: 'rgba(0,0,0,0.06)', offsetY: 4 })
  }

  @Builder
  FavoriteEntryCard() {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.star_fill')).fontSize(18).fontColor(['#FFB900']).margin({ right: 8 })
        Text("我的知识收藏夹").fontSize(16).fontWeight(FontWeight.Medium)
      }
      Blank()
      Row() {
        Text(`${this.myFavorites.length} 条内容`).fontSize(13).fontColor('#999').margin({ right: 4 })
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor(['#CCC'])
      }
    }
    .width('100%').padding(16).backgroundColor(Color.White).borderRadius(12).onClick(() => { this.favDialogController.open() })
  }

  @Builder SearchResultItem(text: string, index: number) {
    Column() {
      Row() {
        Text(`${index + 1}`)
          .fontSize(12).fontColor(Color.White).backgroundColor('#007DFF')
          .constraintSize({ minWidth: 20 }).padding({ left: 6, right: 6 }).height(20)
          .textAlign(TextAlign.Center).borderRadius(10).margin({ right: 10, top: 2 })

        Text(text).fontSize(15).fontColor('#333').lineHeight(24).layoutWeight(1)
        SymbolGlyph(this.isFavorited(text) ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
          .fontSize(20).fontColor(this.isFavorited(text) ? ['#FFB900'] : ['#DDD']).margin({ left: 8 })
          .onClick(() => { this.toggleFavorite(text) })
      }
      .alignItems(VerticalAlign.Top)
    }
    .width('100%').padding(16).backgroundColor(Color.White).borderRadius(12).margin({ bottom: 4 })
  }

  @Builder NoteItemView(item: NoteItem) {
    Column() {
      Text(item.content).fontSize(15).fontColor('#333').lineHeight(22).margin({ bottom: 8 })
      Row() {
        // 修正：显示日期和时间
        Text(item.date).fontSize(12).fontColor('#999').margin({ right: 8 })
        Text(item.time).fontSize(12).fontColor('#999')
      }
    }
    .width('100%').padding(16).backgroundColor(Color.White).borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder DeleteButton(index: number) {
    Button() { SymbolGlyph($r('sys.symbol.trash')).fontSize(24).fontColor([Color.White]) }
    .type(ButtonType.Normal).width(60).height('100%').backgroundColor('#FF3B30').borderRadius({ topLeft: 0, bottomLeft: 0, topRight: 12, bottomRight: 12 }).margin({ left: 10 })
    .onClick(() => { this.deleteNote(index) })
  }
}

// ----------------------------------------------------
// 组件：ImmersiveRecitationView (沉浸式背诵)
// ----------------------------------------------------
@Component
struct ImmersiveRecitationView {
  @Link list: string[];
  onExit: () => void = () => {};
  onRemoveItem: (item: string) => void = () => {};

  @State currentIndex: number = 0;

  handleRemoveCurrent() {
    if (this.list.length === 0) return;
    const itemToRemove = this.list[this.currentIndex];
    this.onRemoveItem(itemToRemove);
    if (this.list.length === 0) {
      this.onExit();
      promptAction.showToast({ message: '收藏夹已清空' });
    } else {
      if (this.currentIndex >= this.list.length) {
        this.currentIndex = this.list.length - 1;
      }
      promptAction.showToast({ message: '已取消收藏' });
    }
  }

  build() {
    Column() {
      // 1. 顶部
      Row() {
        if (this.list.length > 0) {
          Row() {
            Text(`${this.currentIndex + 1} / ${this.list.length}`).fontColor(Color.White).fontSize(14).fontWeight(FontWeight.Medium)
          }
          .backgroundColor('rgba(255,255,255,0.2)').padding({ left: 12, right: 12, top: 6, bottom: 6 }).borderRadius(16)
        }
        Blank()
        Button() { Text("退出").fontColor('rgba(255,255,255,0.8)').fontSize(15) }
        .type(ButtonType.Normal).backgroundColor(Color.Transparent).onClick(() => { this.onExit() })
      }
      .width('100%').padding({ left: 24, right: 24, top: 60, bottom: 20 })

      // 2. 中间卡片
      Column() {
        if (this.list.length > 0) {
          Stack({ alignContent: Alignment.TopEnd }) {
            Column() {
              SymbolGlyph($r('sys.symbol.bookmark')).fontSize(30).fontColor(['rgba(255,255,255,0.6)']).margin({bottom: 24})
              Text(this.list[this.currentIndex]).fontSize(22).fontWeight(FontWeight.Medium).fontColor(Color.White).textAlign(TextAlign.Center).lineHeight(34).opacity(0.95)
            }
            .width('100%').padding({ top: 40, bottom: 40, left: 30, right: 30 })

            Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.star_fill')).fontSize(24).fontColor(['#FFB900']) }
            .width(44).height(44).backgroundColor('rgba(255,255,255,0.15)').margin({ top: 10, right: 10 })
            .onClick(() => { this.handleRemoveCurrent() })
          }
          .width('100%').backgroundColor('rgba(255,255,255, 0.1)').backdropBlur(20).borderRadius(32)
          .border({ width: 1, color: 'rgba(255,255,255,0.1)' }).shadow({ radius: 20, color: 'rgba(0,0,0,0.2)', offsetY: 10 })
          .onClick(() => {
            if (this.currentIndex < this.list.length - 1) {
              animateTo({ duration: 300, curve: Curve.EaseInOut }, () => { this.currentIndex++ })
            } else {
              animateTo({ duration: 300, curve: Curve.EaseInOut }, () => { this.currentIndex = 0 })
              promptAction.showToast({ message: '已从头开始', bottom: 100 })
            }
          })
        } else {
          Text("已全部背诵完成！").fontSize(20).fontColor(Color.White)
        }
      }
      .layoutWeight(1).width('86%').justifyContent(FlexAlign.Center).margin({bottom: 40})

      // 3. 底部
      Row() {
        Button() { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(28).fontColor(['rgba(255,255,255,0.9)']) }
        .type(ButtonType.Circle).backgroundColor('rgba(0,0,0,0.2)').width(60).height(60)
        .enabled(this.list.length > 0)
        .onClick(() => {
          if (this.currentIndex > 0) {
            animateTo({ duration: 300 }, () => { this.currentIndex-- })
          } else {
            promptAction.showToast({ message: '这是第一条', bottom: 100 })
          }
        })

        Column() {
          Text("点击卡片切换").fontSize(12).fontColor('rgba(255,255,255,0.4)')
          Text("点击星号移除").fontSize(12).fontColor('rgba(255,255,255,0.4)').margin({top: 4})
        }
        .margin({ left: 30, right: 30 })

        Button() { SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(28).fontColor(['rgba(255,255,255,0.9)']) }
        .type(ButtonType.Circle).backgroundColor('rgba(0,0,0,0.2)').width(60).height(60)
        .enabled(this.list.length > 0)
        .onClick(() => {
          if (this.currentIndex < this.list.length - 1) {
            animateTo({ duration: 300 }, () => { this.currentIndex++ })
          } else {
            promptAction.showToast({ message: '学习完成！', bottom: 100 })
          }
        })
      }
      .margin({ bottom: 60 })
    }
    .width('100%').height('100%')
    .linearGradient({ direction: GradientDirection.RightBottom, colors: [['#2E1437', 0.0], ['#2C3E50', 0.6], ['#4CA1AF', 1.0]] })
  }
}

// ----------------------------------------------------
// 组件：FavoritesDialog (收藏夹)
// ----------------------------------------------------
@CustomDialog
struct FavoritesDialog {
  controller?: CustomDialogController
  @Link favorites: string[]
  onDelete: (item: string) => void = () => {}
  onStartRecite: () => void = () => {}

  build() {
    Column() {
      Row().width(40).height(5).backgroundColor('#E0E0E0').borderRadius(3).margin({ top: 10, bottom: 20 })
      Row() {
        Column() {
          Text("我的知识收藏").fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333')
          Text(`共 ${this.favorites.length} 条重点知识`).fontSize(13).fontColor('#999').margin({top: 4})
        }.alignItems(HorizontalAlign.Start)
        Blank()
        Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.xmark')).fontSize(16).fontColor(['#999']) }
        .width(30).height(30).backgroundColor('#F5F5F5').onClick(() => { this.controller?.close() })
      }
      .width('100%').padding({ left: 24, right: 24, bottom: 20 })

      if (this.favorites.length > 0) {
        Button() {
          Row() {
            SymbolGlyph($r('sys.symbol.play_circle_fill')).fontSize(20).fontColor([Color.White]).margin({right: 8})
            Text("开始沉浸背诵").fontSize(16).fontColor(Color.White).fontWeight(FontWeight.Bold)
          }
        }
        .width('90%').height(50).linearGradient({ direction: GradientDirection.Right, colors: [['#007DFF', 0.0], ['#00B4FF', 1.0]] })
        .shadow({ radius: 10, color: 'rgba(0,125,255,0.3)', offsetY: 5 }).margin({ bottom: 20 })
        .onClick(() => { this.controller?.close(); this.onStartRecite(); })
      }

      if (this.favorites.length === 0) {
        Column() {
          Text("📂").fontSize(50).margin({bottom: 10})
          Text("还没有收藏任何内容").fontSize(15).fontColor('#999')
          Text("去每日一学或者搜索里找找吧").fontSize(12).fontColor('#CCC').margin({top: 5})
        }
        .height(200).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.favorites, (item: string, index: number) => {
            ListItem() {
              Row() {
                Text(`${index + 1}`.padStart(2, '0')).fontSize(14).fontColor('#DDD').fontWeight(FontWeight.Bold).margin({ right: 12 })
                Text(item).fontSize(15).fontColor('#333')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
                  .lineHeight(22)

                Button({ type: ButtonType.Circle }) {
                  Text("×").fontSize(18).fontColor('#999')
                }
                .backgroundColor('transparent')
                .width(30).height(30)
                .onClick(() => {
                  this.onDelete(item)
                })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(16)
              .shadow({ radius: 8, color: 'rgba(0,0,0,0.03)', offsetY: 2 })
            }
          })
        }
        .width('100%')
        .height(350)
        .padding({ left: 16, right: 16 })
        .scrollBar(BarState.Auto)
      }
    }
    .backgroundColor('#F9F9F9')
    .borderRadius({ topLeft: 24, topRight: 24 })
    .width('100%')
    .padding({ bottom: 20 })
  }
}

// ----------------------------------------------------
// 组件：AddNoteDialog (添加笔记)
// ----------------------------------------------------
@CustomDialog
struct AddNoteDialog {
  controller?: CustomDialogController
  onConfirm: (content: string) => void = (content: string): void => {}
  @State noteContent: string = ''

  build() {
    Column() {
      Text("添加安全笔记")
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 16 })
        .fontColor('#333')

      TextArea({ placeholder: '记录隐患或知识点...', text: this.noteContent })
        .height(120)
        .backgroundColor('#F5F5F5')
        .borderRadius(12)
        .fontSize(15)
        .onChange((value) => { this.noteContent = value })
        .margin({ bottom: 20 })

      Row() {
        Button("取消")
          .backgroundColor('#F2F2F2')
          .fontColor('#666')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .height(40)
          .margin({ right: 12 })
          .onClick(() => {
            if (this.controller) { this.controller.close() }
          })

        Button("保存")
          .backgroundColor('#007DFF')
          .fontColor(Color.White)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .height(40)
          .onClick(() => {
            this.onConfirm(this.noteContent);
            if (this.controller) { this.controller.close() }
          })
      }
      .width('100%')
    }
    .padding(24)
    .backgroundColor(Color.White)
    .borderRadius(24)
    .width('90%')
    .shadow({ radius: 20, color: 'rgba(0,0,0,0.1)', offsetY: 10 })
  }
}
