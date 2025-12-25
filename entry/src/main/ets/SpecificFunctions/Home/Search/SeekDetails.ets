import { AppStorageV2 } from "@kit.ArkUI";
import { AddParams, ApiService, PromptMessage, QuestionItem } from "common";
import { param } from "./Seek";


@Builder
export function SeekDetailsBuilder() {
  SeekDetails()
}

@Component
export struct SeekDetails {

  pathStack: NavPathStack = AppStorageV2.connect(NavPathStack,() => new NavPathStack())!

  @StorageLink('userId') userId: string = ''

  @State questionData: QuestionItem | null = null
  @State bagColor: string = ''
  @State type: string = ''

  build() {
    NavDestination(){

      Column({space: 15}){

        Row(){
          Row(){
            Image($r('app.media.iv_back'))
              .width(30)
          }
          .onClick(() => {
            this.pathStack.pop()
          })

          Row(){
            Text('题目信息')
              .fontSize(22)
          }

          Row(){
            Image(this.questionData?.isLike? $r('app.media.like_true'): $r('app.media.like_false'))
              .width(30)
          }
          .onClick(async () => {
            let param = {
              sign: 'dd',
              userid: parseInt(this.userId),
              cate: this.type,//单选、多选、判断
              problemid: this.questionData?.id.toString()
            } as AddParams


            console.log('题目信息'+JSON.stringify(param))

            try {
              const res = await ApiService.AddLike(param)

              if(res.issucc){
                this.questionData!.isLike = !this.questionData?.isLike
                PromptMessage.showMessage(res.msg)
              }
            } catch (error) {
              console.log('收藏失败'+error)
            }
          })

        }
        .width('100%')
        .padding({top:40,left: 15,right: 15,bottom: 8})
        .justifyContent(FlexAlign.SpaceBetween)
        .backgroundColor(Color.White)

        //题目显示区域
        Column({space: 8}){
          Row(){
            Text('题目')
              .fontSize(20)
              .borderRadius(8)
              .backgroundColor(this.bagColor)
              .padding({left: 8,right: 8,bottom: 4,top: 4})
          }
          .width('100%')
          Row(){
            Text(this.questionData?.title)
              .fontSize(20)
          }
          .width('100%')

          Column({space: 10}){
            //选项A
            Row(){
              Text(this.questionData?.option1)
                .fontSize(20)
            }
            .width('100%')
            //选项B
            Row(){
              Text(this.questionData?.option2)
                .fontSize(20)
            }
            .width('100%')
            //选项C
            if(this.questionData?.option3){
              Row(){
                Text(this.questionData?.option3)
                  .fontSize(20)
              }
              .width('100%')
            }
            //选项D
            if(this.questionData?.option4){
              Row(){
                Text(this.questionData?.option4)
                  .fontSize(20)
              }
              .width('100%')
            }
          }
          .width('100%')

        }
        .backgroundColor(Color.White)
        .padding(15)
        .borderRadius(10)
        .margin({left: 15,right: 15})

        //答案显示区域
        Row(){

          Row({space: 10}){
            Text('答案')
              .fontSize(20)
              .borderRadius(8)
              .backgroundColor(this.bagColor)
              .padding({left: 8,right: 8,bottom: 4,top: 4})
            Text(this.questionData?.correct)
              .fontSize(20)
          }
          .width('100%')
        }
        .backgroundColor(Color.White)
        .padding(15)
        .borderRadius(10)
        .margin({left: 15,right: 15})

        //题目解析
        Column({space: 10}){
          Row(){
            Text('解析')
              .fontSize(20)
              .borderRadius(8)
              .backgroundColor(this.bagColor)
              .padding({left: 8,right: 8,bottom: 4,top: 4})
          }
          .width('100%')
          Row(){
            Text(this.questionData?.analysis)
              .fontSize(20)
          }
          .width('100%')
        }
        .backgroundColor(Color.White)
        .padding(15)
        .borderRadius(10)
        .margin({left: 15,right: 15})

        //题目来源
        Column({space: 10}){
          Row(){
            Text('来源')
              .fontSize(20)
              .borderRadius(8)
              .backgroundColor(this.bagColor)
              .padding({left: 8,right: 8,bottom: 4,top: 4})
          }
          .width('100%')
          Row(){
            Text(this.questionData?.source)
              .fontSize(20)
          }
          .width('100%')
        }
        .backgroundColor(Color.White)
        .padding(15)
        .borderRadius(10)
        .margin({left: 15,right: 15})

      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.bagColor)

    }
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      const par = context.pathInfo.param as param

      console.log('多选'+JSON.stringify(par))

      this.questionData = this.formatQuestion(par.list)



      this.questionData.correct = this.parseCorrectAnswer(par.list).join('')


      this.bagColor = par.color

      this.type = par.type

      console.log('多选'+JSON.stringify(this.questionData))

    })
    .hideTitleBar(true)
  }

  //解析正确答案为标准数组 ['A', 'B']
  parseCorrectAnswer(info: QuestionItem): string[] {
    if (!info || !info.correct) return [];

    const correct = info.correct.trim();

    // 如果包含字母，直接分割
    if (/[A-Z]/.test(correct)) {
      return correct.split('');
    }

    // 如果是数字
    if (/[0-9]/.test(correct)) {
      const num = parseInt(correct);
      const map = ['A', 'B', 'C', 'D'];
      if (num >= 1 && num <= 4) {
        return [map[num - 1]];
      }
    }

    return [correct]; //兜底
  }

  // 数据清洗：统一处理题目选项格式
  formatQuestion(item: QuestionItem): QuestionItem {
    const processOption = (text: string | undefined, prefix: string): string => {
      if (!text) return '';
      let cleanText = text.replace(/^[A-Z][.、]\s*/, '');
      return `${prefix}. ${cleanText}`;
    };

    let newItem: QuestionItem = {
      id: item.id,
      type: item.type,
      title: item.title,
      option1: processOption(item.option1, 'A'),
      option2: processOption(item.option2, 'B'),
      option3: item.option3 ? processOption(item.option3, 'C') : undefined,
      option4: item.option4 ? processOption(item.option4, 'D') : undefined,
      correct: item.correct,
      analysis: item.analysis,
      source: item.source,
      isLike: item.isLike
    };

    return newItem;
  }

}