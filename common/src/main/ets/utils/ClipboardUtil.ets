import pasteboard from "@ohos.pasteboard";

export class ClipboardUtil {
  static async Clipboard(text: string) {
    try {
      //获取系统剪贴板
      const systemPasteboard = pasteboard.getSystemPasteboard()

      //创建剪贴板数据
      const pasteData = pasteboard.createPlainTextData(text.trim())

      //将剪贴板数据写入剪贴板
      await systemPasteboard.setPasteData(pasteData)

      return true
    } catch (error) {
      console.error("复制失败"+error)
      return false
    }
  }
}