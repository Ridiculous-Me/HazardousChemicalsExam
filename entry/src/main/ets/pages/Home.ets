import { AppStorageV2 } from "@kit.ArkUI";
import { ApiService, getDataParams, LoadingComponent, QuestionDataResponse, QuestionItem,
  UserPreferencesManager } from 'common'; // 请确保路径正确
import { PaperName } from "../exam/ExamComponent"; // 请确保路径正确
import { ExamParam } from "../SpecificFunctions/Home/Random/RandomPractice"; // 请确保路径正确
import { common } from "@kit.AbilityKit";

// 1. 定义样式类 (放在 struct 外面，解决 ArkTS 报错)
class OptionStyle {
  bgColor: ResourceColor = '#F5F5F5'     // 默认背景色
  fontColor: ResourceColor = '#333333'   // 默认文字颜色
  borderColor: ResourceColor = 'transparent' // 默认边框颜色
}

@Component
export struct Home {

  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack,() => new NavPathStack())!

  // === 每日一题状态 ===
  @State isLoading: boolean = false
  @State QuestionType: string = ''
  @State questionInfo: QuestionItem | null  = null

  // === 交互状态 ===
  @State selectedOptions: string[] = [] // 用户选中的选项
  @State isSubmitted: boolean = false   // 是否已点击确定
  @State standardCorrect: string[] = [] // 标准化的正确答案数组

  // === 【新增】城市选择状态监听 ===
  // 监听全局 CurrentCity 变量，默认值为 '北京'
  // 当 CitySelectPage 修改了 AppStorage 里的值，这里会自动刷新
  @StorageProp('CurrentCity') currentCity: string = '北京'

  async aboutToAppear(){
    // 1. 先初始化 & 读取本地存储的城市
    // 注意：这里为了快，先假设是默认用户 'default_user'
    // 如果还没存过，就默认返回 '北京'
    try {
      await UserPreferencesManager.getInstance().initUser(getContext(this) as common.UIAbilityContext, 'default_user');
      const savedCity = await UserPreferencesManager.getInstance().getValue<string>('SelectedCity', '北京');

      // 2. 更新内存，UI 会自动刷新
      AppStorage.setOrCreate('CurrentCity', savedCity);
    } catch (err) {
      console.error('读取城市失败:', err);
    }

    // 3. 原有的获取题目逻辑
    this.getQuestion()
  }

  build() {
    Column(){
      Scroll(){
        Column({space: 5}){
          // 顶部大标题
          Row(){
            Text('危险化学品考试通关王')
              .fontSize(24)
              .fontWeight(FontWeight.Bold) // 加粗更显眼
              .fontColor(Color.White)
          }
          .margin({left: 20, top: 10, bottom: 5})
          .width('100%')

          // 城市选择入口
          //this.gotoSelectCity()

          // Banner 轮播
          Swiper(){
            Image($r('app.media.banner_1'))
              .objectFit(ImageFit.Auto)
              .width('90%')
              .margin({ left: 12, right: 12 })
              .borderRadius(10)

            Image($r('app.media.banner_2'))
              .objectFit(ImageFit.Auto)
              .width('90%')
              .margin({ left: 12, right: 12 })
              .borderRadius(10)
          }
          .loop(true)
          .autoPlay( true)
          .margin({ top: 5 })

          // 功能模块入口 (四宫格)
          this.chooseType()


          // === 每日一题卡片 ===
          Column() {
            Row(){
              Row(){
                Text('每日一题')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)

                Text(this.QuestionType ? ` [${this.QuestionType}]` : '')
                  .fontSize(14)
                  .fontColor('#666666')
                  .margin({left: 4})
              }

              Row({space: 4}){
                Image($r('app.media.Change')) // 确保你有这个图标
                  .width(16)
                  .height(16)
                  .fillColor('#1890FF') // 如果是svg可以使用颜色填充
                Text('换一换')
                  .fontSize(14)
                  .fontColor('#1890FF') // 主题蓝
              }
              .onClick(() => {
                this.getQuestion()
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            .padding({ bottom: 10 })


            // 每日一题显示区域
            if(this.isLoading)
            {
              LoadingComponent()
                .height(200)
            }
            else {
              Scroll(){
                Column(){
                  // 题目标题
                  Row(){
                    Text(`${this.questionInfo?.title}`)
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .lineHeight(24)
                      .fontColor('#333')
                  }
                  .width('100%')
                  .margin({bottom: 15, top: 5})

                  // 选项列表
                  Column({space: 12}){ // 增加一点间距
                    // === 渲染选项 A ===
                    this.OptionItem('A', this.questionInfo?.option1)

                    // === 渲染选项 B ===
                    this.OptionItem('B', this.questionInfo?.option2)

                    // === 渲染选项 C ===
                    if(this.questionInfo?.option3) {
                      this.OptionItem('C', this.questionInfo?.option3)
                    }

                    // === 渲染选项 D ===
                    if(this.questionInfo?.option4) {
                      this.OptionItem('D', this.questionInfo?.option4)
                    }
                  }

                  // === 底部按钮与结果展示 ===
                  Column() {
                    if (!this.isSubmitted) {
                      // 提交按钮
                      Button('确定')
                        .width('80%')
                        .height(40)
                        .margin({ top: 25 })
                        .backgroundColor('#1890FF')
                        .shadow({ radius: 4, color: '#881890FF', offsetY: 2 }) // 增加按钮阴影
                        .onClick(() => {
                          if (this.selectedOptions.length > 0) {
                            this.isSubmitted = true
                          }
                        })
                    } else {
                      // 结果展示
                      Column({ space: 8 }) {
                        Row() {
                          Text('正确答案：').fontSize(15).fontColor('#666')
                          Text(this.standardCorrect.join(''))
                            .fontSize(18)
                            .fontWeight(FontWeight.Bold)
                            .fontColor('#52C41A') // 绿色
                        }

                        Row() {
                          Text('您的答案：').fontSize(15).fontColor('#666')
                          Text(this.selectedOptions.join(''))
                            .fontSize(18)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(
                              JSON.stringify(this.selectedOptions) === JSON.stringify(this.standardCorrect)
                                ? '#52C41A' : '#FF4D4F' // 绿或红
                            )
                        }

                        // 这里可以加一个解析入口
                        if(this.questionInfo?.analysis) {
                          Text(`解析：${this.questionInfo.analysis}`)
                            .fontSize(13)
                            .fontColor('#999')
                            .margin({top: 5})
                        }

                      }
                      .width('100%')
                      .alignItems(HorizontalAlign.Start)
                      .padding(15)
                      .margin({ top: 20 })
                      .backgroundColor('#F9F9F9')
                      .borderRadius(8)
                    }
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Center)

                }
                .padding({ bottom: 10 })
              }
              .scrollable(ScrollDirection.Vertical)
              .layoutWeight(1)
              .scrollBar(BarState.Off)
            }
          }
          .width('90%')
          .constraintSize({minHeight: 280}) // 稍微加高
          .backgroundColor(Color.White)
          .borderRadius(16)
          .padding(16)
          .shadow({ radius: 20, color: 'rgba(0,0,0,0.05)', offsetY: 5 }) // 增加卡片阴影，更有质感

          // === 自定义练习区域 ===
          Column({space: 12}){
            Row({space: 8}){
              Row()
                .width(4)
                .height(18)
                .backgroundColor('#1890FF') // 蓝色竖条装饰
                .borderRadius(2)

              Row(){
                Text('自定义练习')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#333')
              }
            }
            .width('90%')
            .margin({top: 10})

            // 单选题入口
            this.PracticeEntry('单选题', $r('app.media.bank2'), '#1afa29', () => {
              this.startPractice('单选题')
            })

            // 判断题入口
            this.PracticeEntry('判断题', $r('app.media.judge2'), '#1296db', () => {
              this.startPractice('判断题')
            })

            // 多选题入口
            this.PracticeEntry('多选题', $r('app.media.many2'), '#f4ea2a', () => {
              this.startPractice('多选题')
            })
          }
          .margin({top: 5, bottom: 40}) // 底部留白

        }
        .padding({top: 40 + 20, bottom: 20}) // Top padding 留给沉浸式状态栏
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

    }
    .width('100%')
    .height('100%')
    // === 【重要修改】使用线性渐变背景 ===
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [
        ['#1890FF', 0.0],  // 顶部深蓝，衬托标题
        ['#3CA9FF', 0.25], // 过渡蓝
        ['#F5F7FA', 0.4],  // 开始变灰白，衬托卡片
        ['#F5F7FA', 1.0]   // 底部保持灰白
      ]
    })
  }

  // === 抽取：单个选项的渲染逻辑 ===
  @Builder
  OptionItem(label: string, text: string | undefined) {
    if (text) {
      Row(){
        // 选项标号 (A/B...)
        Text(label)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getOptionStyle(label).fontColor)
          .margin({right: 10})

        // 选项内容
        Text(text)
          .fontSize(15)
          .fontColor(this.getOptionStyle(label).fontColor)
          .layoutWeight(1)
      }
      .width('100%')
      .padding(14)
      .borderRadius(10) // 圆角更圆润
      .backgroundColor(this.getOptionStyle(label).bgColor)
      .border({ width: 1, color: this.getOptionStyle(label).borderColor })
      .onClick(() => this.handleOptionClick(label))
    }
  }

  // === 抽取：自定义练习入口条目 ===
  @Builder
  PracticeEntry(title: string, icon: Resource, btnColor: string, onClick: () => void) {
    Row(){
      Row({space: 12}){
        Image(icon)
          .width(40)
          .height(40)

        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
      }

      Row(){
        Text('去练习')
          .fontSize(14)
          .padding({left: 12, right: 12, top: 6, bottom: 6})
          .backgroundColor(btnColor)
          .fontColor(Color.White)
          .borderRadius(16) // 胶囊按钮
      }
    }
    .width('90%')
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .padding(12)
    .shadow({
      radius: 10,
      color: 'rgba(0,0,0,0.05)',
      offsetY: 2
    })
    .onClick(onClick)
  }

  // === 城市选择入口 ===
  @Builder
  gotoSelectCity() {
    Row() {
      Row() {
        Image($r('app.media.locations'))
          .width(16)
          .height(16)
          .margin({ right: 6 })
          .fillColor('#333') // 尝试给图标着色

        // 【关键】这里使用了 @StorageProp 的 currentCity
        Text(this.currentCity)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333')
      }

      Row() {
        Text('去选择')
          .fontSize(12)
          .fontColor('#999')
          .margin({ right: 4 })
        Image($r('app.media.ic_right_arrow_lined')) // 确保有这个图标
          .height(12)
          .width(12)
          .fillColor('#999')
      }
    }
    .width('90%')
    .margin({ top: 5, bottom: 10 })
    .height(44)
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor('rgba(255,255,255,0.95)') // 微透明的白色
    .borderRadius(22) // 胶囊形状
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      // 跳转到城市选择页面
      this.pathStack.pushPathByName('CitySelectPage', null,false)
    })
  }

  // 模式选择 (四宫格)
  @Builder
  chooseType() {
    GridRow({
      columns: selectModule.length
    }){
      ForEach(selectModule,(item: SelectModule,index: number) => {
        GridCol(){
          Column({space: 8}){
            Image(item.image)
              .height(42)
              .width(42)
              .margin({top: 10, bottom: 5})

            Row(){
              Text(item.text)
                .fontColor('#333')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
            }
          }
          .layoutWeight(1)
          .width('100%')
        }
        .onClick(() => {
          switch (index) {
            case 0:
              this.pathStack.pushPathByName('ExamComponent',null,false)
              break
            case 1:
              this.pathStack.pushPathByName('RandomPractice',null,false)
              break
            case 2:
              this.pathStack.pushPathByName('LimitedTimeTraining',null,false)
              break
            case 3:
              this.pathStack.pushPathByName('Seek',null,false)
              break
            default :
              return
          }
        })
      })
    }
    .backgroundColor(Color.White)
    .borderRadius(16)
    .padding(12)
    .width('90%')
    .height(110)
    .margin(12)
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.05)', offsetY: 2 })
  }

  // === 逻辑方法 ===

  // 辅助跳转方法
  startPractice(type: string) {
    let practiceData: ExamParam = {
      types: [type],
      count: 300,
      timeLimit: 0
    }
    this.pathStack.pushPathByName('RandomExamPage', practiceData, false)
  }

  // 重置题目状态
  resetState() {
    this.selectedOptions = [];
    this.isSubmitted = false;
    this.standardCorrect = [];
  }

  //获取题目
  async getQuestion() {
    this.isLoading = true;
    this.resetState();

    const params = {
      sign: 'dd',
      type: PaperName,
      num: 1
    } as getDataParams

    try {
      let res = {} as QuestionDataResponse
      let index = Math.floor(Math.random()*3)

      switch (index) {
        case 0:
          res = await ApiService.GetBankData(params)
          this.QuestionType = '单选题'
          break;
        case 1:
          res = await ApiService.GetJudgeData(params)
          this.QuestionType = '判断题'
          break;
        case 2:
          res = await ApiService.GetManyData(params)
          this.QuestionType = '多选题'
          break;
      }

      if(res.issucc && res.data && res.data.length > 0) {
        const rawData = res.data[0]
        this.questionInfo = this.formatQuestion(rawData)
        this.standardCorrect = this.parseCorrectAnswer(this.questionInfo)
      }
    } catch (error) {
      console.log('Error getting question:', error)
    } finally {
      this.isLoading = false;
    }
  }

  //解析正确答案
  parseCorrectAnswer(info: QuestionItem): string[] {
    if (!info || !info.correct) return [];
    const correct = info.correct.trim();
    if (/[A-Z]/.test(correct)) {
      return correct.split('');
    }
    if (/[0-9]/.test(correct)) {
      const num = parseInt(correct);
      const map = ['A', 'B', 'C', 'D'];
      if (num >= 1 && num <= 4) {
        return [map[num - 1]];
      }
    }
    return [correct];
  }

  // 处理选项点击
  handleOptionClick(optionLabel: string) {
    if (this.isSubmitted) return;

    if (this.QuestionType === '多选题') {
      const index = this.selectedOptions.indexOf(optionLabel);
      if (index !== -1) {
        this.selectedOptions.splice(index, 1);
      } else {
        this.selectedOptions.push(optionLabel);
      }
      this.selectedOptions.sort();
    } else {
      this.selectedOptions = [optionLabel];
    }
  }

  // 获取选项的样式 (蓝-绿-红 逻辑)
  getOptionStyle(optionLabel: string): OptionStyle {
    const isSelected = this.selectedOptions.includes(optionLabel);
    const isCorrect = this.standardCorrect.includes(optionLabel);
    let style = new OptionStyle();

    // === 未提交 ===
    if (!this.isSubmitted) {
      if (isSelected) {
        style.bgColor = '#E6F7FF';  // 选中：浅蓝背景
        style.fontColor = '#1890FF'; // 选中：深蓝字
        style.borderColor = '#1890FF';
      } else {
        style.bgColor = '#F5F5F5';
        style.fontColor = '#333333';
        style.borderColor = 'transparent';
      }
      return style;
    }

    // === 已提交 ===
    // 1. 正确答案 (标绿)
    if (isCorrect) {
      style.bgColor = '#F6FFED';
      style.fontColor = '#52C41A';
      style.borderColor = '#52C41A';
      return style;
    }

    // 2. 错选 (标红)
    if (isSelected && !isCorrect) {
      style.bgColor = '#FFF1F0';
      style.fontColor = '#FF4D4F';
      style.borderColor = '#FF4D4F';
      return style;
    }

    // 3. 其他 (灰)
    style.bgColor = '#F5F5F5';
    style.fontColor = '#999999';
    style.borderColor = 'transparent';
    return style;
  }

  // 数据清洗
  formatQuestion(item: QuestionItem): QuestionItem {
    const processOption = (text: string | undefined): string => {
      if (!text) return '';
      // 移除可能存在的 "A. ", "A、" 前缀
      return text.replace(/^[A-Z][.、]\s*/, '');
    };

    let newItem: QuestionItem = {
      id: item.id,
      type: item.type,
      title: item.title,
      option1: processOption(item.option1),
      option2: processOption(item.option2),
      option3: item.option3 ? processOption(item.option3) : undefined,
      option4: item.option4 ? processOption(item.option4) : undefined,
      correct: item.correct,
      analysis: item.analysis,
      source: item.source
    };
    return newItem;
  }
}

// 静态数据
export const selectModule: SelectModule[] = [
  { image: $r('app.media.icon_tab_mn'), text: '模拟考试' },
  { image: $r('app.media.icon_tab_zt'), text: '随机练习' },
  { image: $r('app.media.icon_tab_zj'), text: '限时训练' },
  { image: $r('app.media.seek'), text: '极速搜题' }
]

interface SelectModule {
  image: Resource,
  text: string,
}
