@Component
export struct LoadingComponent {
  build() {
    Column(){
      LoadingProgress()
        .color('#1677FF')
        .size({width: 60, height: 60})

      Text('加载中...')
        .fontSize(16)
    }
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}