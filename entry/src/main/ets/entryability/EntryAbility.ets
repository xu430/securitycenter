import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { LiveStore } from '../model/LiveStore';
import { ScanTask } from '../model/ScanTask';
import { VERIFY_REJECT_CODE } from '../probe/ProbeTypes';
import { codeFromParameter, storeRejectCode } from '../probe/UpdateReject';

const DOMAIN = 0x4A59;
const TAG = 'SecurityCenter';

export default class EntryAbility extends UIAbility {
  private rejectScan: boolean = false;
  private windowReady: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    let name = 'com.jinyinhu.securitycenter';
    if (typeof want.bundleName === 'string') {
      name = want.bundleName;
    }
    hilog.info(DOMAIN, TAG, 'onCreate %{public}s', name + '/' + launchParam.launchReason.toString());
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'colorMode %{public}s', JSON.stringify(err));
    }
    LiveStore.bind(this.context);
    LiveStore.prepare();
    this.takeReject(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'onNewWant %{public}s', launchParam.launchReason.toString());
    this.takeReject(want);
    this.scanIfRejected();
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    LiveStore.restore().then(() => {
      this.open(windowStage);
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'restore %{public}s', JSON.stringify(err));
      this.open(windowStage);
    });
  }

  private open(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err && err.code) {
        hilog.error(DOMAIN, TAG, 'load %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'loaded');
      this.windowReady = true;
      this.scanIfRejected();
    });
    windowStage.getMainWindow().then((win: window.Window) => {
      win.setWindowBackgroundColor('#FFF7F6F2');
      win.setWindowSystemBarProperties({
        statusBarColor: '#FFF7F6F2',
        statusBarContentColor: '#E51C1E21',
        navigationBarColor: '#FFF7F6F2',
        navigationBarContentColor: '#E5000000'
      }).catch((err: Error) => {
        hilog.error(DOMAIN, TAG, 'systemBar %{public}s', JSON.stringify(err));
      });
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'window %{public}s', JSON.stringify(err));
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageDestroy');
  }

  private takeReject(want: Want): void {
    let value: Object | undefined = undefined;
    if (want.parameters !== undefined) {
      value = want.parameters['jinyinhuRejectCode'];
    }
    let code = codeFromParameter(value);
    if (code !== VERIFY_REJECT_CODE) {
      return;
    }
    if (!storeRejectCode(this.context.filesDir, code)) {
      hilog.error(DOMAIN, TAG, 'reject note failed');
      return;
    }
    this.rejectScan = true;
  }

  private scanIfRejected(): void {
    if (!this.rejectScan || !this.windowReady) {
      return;
    }
    this.rejectScan = false;
    ScanTask.run(this.context, []).catch((err: Object) => {
      hilog.error(DOMAIN, TAG, 'reject scan %{public}s', JSON.stringify(err));
    });
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'onBackground');
  }
}
