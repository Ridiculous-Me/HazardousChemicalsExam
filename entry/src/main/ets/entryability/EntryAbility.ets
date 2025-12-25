import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import WindowManager from '../utils/WindowManager'
import bundleManager from '@ohos.bundle.bundleManager'
import { md5EncryptSync } from '@abner/security';
import { ZztSDK } from '@zztsdk/zztcore';
import mobShare from '@zztsdk/sharesdk';
import { WXApi, WXEventHandler } from '../Pay/WXApiWrap';


const DOMAIN = 0x0000;
const DELAY_TIME = 1000; //启动延时1秒

export default class EntryAbility extends UIAbility {



  async  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');



    let bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_SIGNATURE_INFO);
    let fingerprint = bundleInfo.signatureInfo.fingerprint.toLowerCase() // 获取 fingerprint

    let md5 = md5EncryptSync(fingerprint)


    //初始化第三方MobSDK
    ZztSDK.init(this.context, "36a3bea273dd7", "7bc41e13c1f339009e15389c750085e9")
    ZztSDK.submitPolicyGrantResult(true);

    //设置授权需要的UIAbilityContext放在初始化之后调用
    await mobShare.ShareSDK.getInstance().setUIAbilityContext(this.context)
    //接收三方平台回调方法
    mobShare.ShareSDK.getInstance().handlerWant(want,this.context)
  }


  async onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    //接收三方平台回调方法
    //微信回调处理
    this.handleWeChatCallIfNeed(want)
    //处理mobShare回调
    mobShare.ShareSDK.getInstance().handlerWant(want, this.context)
  }

  private handleWeChatCallIfNeed(want: Want) {
    WXApi.handleWant(want, WXEventHandler);
  }


  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');


    //添加沉浸式全局配置
    WindowManager.immerseFullScreenAsync(windowStage)

    //实现启动延时
    setTimeout(() =>{
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      });
    }, DELAY_TIME)



  }



  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');

  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}