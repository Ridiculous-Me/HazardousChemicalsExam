import { toast, ToastAlignment } from "@abner/toast";

export class PromptMessage {
  static showMessage(message: string): void {
    toast(message,{
      backgroundColor: '#47454d',
      fontColor: Color.White,
      borderRadius: 10,
      duration: 2000,
      alignment: ToastAlignment.Center
    })
  }
}