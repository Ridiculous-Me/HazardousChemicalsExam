import { common } from "@kit.AbilityKit";
import { systemShare } from "@kit.ShareKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { uniformTypeDescriptor as utd } from '@kit.ArkData';


export class ShareUtils {
  async shareApp(context: common.UIAbilityContext) {
    const appName = "危险化学品考试通关王";
    const appDescription = '这个软件挺好用的，快来下载试试吧'
    const appUrl = "http://www.yuanlikj.cn/"; // 长沙梦音互动网络科技有限公司应用下载链接

    const thumbnail = await this.getAppIcon();



    // 创建分享数据
    //使用 TEXT 类型，将链接和描述合并
    // let shareData: systemShare.SharedData = new systemShare.SharedData({
    //   utd: utd.UniformDataType.TEXT,
    //   content: `${appDescription} ${appUrl}`, // 将描述和链接合并到内容中
    //   title: appName,
    //   description: appDescription, // 保留描述字段
    //   thumbnail: thumbnail
    // });

    //分享数据
    //使用WEB_URL类型
    let shareData: systemShare.SharedData = new systemShare.SharedData({
      utd: utd.UniformDataType.HYPERLINK,
      content: appUrl,
      title: appName,
      description: appDescription,
      thumbnail: thumbnail
    })

    // 创建分享控制器
    let controller: systemShare.ShareController = new systemShare.ShareController(shareData);


    //const uiContext: UIContext = this.getUIContext();
    //const context: common.UIAbilityContext = uiContext.getHostContext() as common.UIAbilityContext;

    // 显示分享界面
    controller.show(context, {
      selectionMode: systemShare.SelectionMode.SINGLE,
      previewMode: systemShare.SharePreviewMode.DEFAULT,
    }).then(() => {
      console.info('分享成功');
    }).catch((error: BusinessError) => {
      console.error('分享失败:', error.message);
    });
  }

  private async getAppIcon(): Promise<Uint8Array> {
    try {
      // 使用资源管理器获取图片
      const resourceManager = getContext().resourceManager;

      // 获取图片资源的ArrayBuffer
      const imageData = await resourceManager.getMediaContent($r('app.media.app'));

      // 将ArrayBuffer转换为Uint8Array
      return new Uint8Array(imageData);

    } catch (error) {
      console.warn('从资源获取图标失败:', error);
      // 返回空数组作为备用
      return new Uint8Array();
    }
  }

}
