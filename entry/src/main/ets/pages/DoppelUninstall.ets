import { common } from '@kit.AbilityKit';
import installer from '@ohos.bundle.installer';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Theme } from '../common/Theme';
import { LiveStore } from '../model/LiveStore';
import { doppelInstalled, HIT_PHRASE, LAKESIDE_BUNDLE } from '../probe/InstallIntegrityProbe';
import { ProbeShelf, emptyProbeShelf } from '../probe/ProbeTypes';
import { Finding } from '../report/Findings';

const DOMAIN = 0x4A59;
const TAG = 'DoppelUninstall';
const USER_ID = 100;

class InstallError {
  code: number = 0;
  message: string = '';
}

@Component
export struct DoppelUninstall {
  @StorageLink('probeShelf') probeShelf: ProbeShelf = emptyProbeShelf();
  @StorageLink('findings') findings: Finding[] = [];
  @State tick: number = 0;
  @State busy: boolean = false;
  @State notice: string = '';

  build() {
    Column() {
      if (this.armed()) {
        Text(HIT_PHRASE)
          .width('100%')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.danger)
        Text('笔记已被同名伪造包替换。笔记已备份。')
          .width('100%')
          .fontSize(14)
          .fontColor(Theme.text)
          .lineHeight(20)
          .margin({ top: 8 })
        Button(this.busy ? '正在卸载' : '卸载笔记')
          .type(ButtonType.Capsule)
          .width('100%')
          .height(40)
          .fontSize(16)
          .fontColor(Theme.onAccent)
          .backgroundColor(Theme.danger)
          .enabled(!this.busy)
          .margin({ top: 12 })
          .onClick(() => {
            this.confirm();
          })
        if (this.notice.length > 0) {
          Text(this.notice)
            .width('100%')
            .fontSize(13)
            .fontColor(Theme.muted)
            .margin({ top: 8 })
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(this.armed() ? 16 : 0)
    .borderRadius(16)
    .backgroundColor(this.armed() ? Theme.dangerSoft : Theme.page)
    .margin(this.armed() ? { bottom: 12 } : {})
  }

  private armed(): boolean {
    let ignored = this.probeShelf.runs.length + this.findings.length + this.tick;
    if (ignored < 0) {
      return false;
    }
    return doppelInstalled();
  }

  private confirm(): void {
    if (this.busy || !this.armed()) {
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      message: '将卸载笔记。笔记已备份。',
      buttons: [
        { text: '取消', color: Theme.muted },
        { text: '卸载', color: Theme.danger }
      ]
    }).then((result) => {
      if (result.index !== 1) {
        return;
      }
      this.remove();
    }).catch((err: Object) => {
      hilog.error(DOMAIN, TAG, 'dialog %{public}s', JSON.stringify(err));
    });
  }

  private remove(): void {
    let ctx = this.host();
    if (ctx === undefined) {
      this.notice = '无法卸载';
      return;
    }
    this.busy = true;
    this.notice = '';
    installer.getBundleInstaller().then((tool: installer.BundleInstaller): Promise<void> => {
      return tool.uninstall(LAKESIDE_BUNDLE, { userId: USER_ID, isKeepData: true });
    }).then((): void => {
      this.busy = false;
      this.tick = this.tick + 1;
      LiveStore.setStatus('已卸载笔记，笔记已备份');
      this.notice = '';
    }).catch((err: Object) => {
      hilog.error(DOMAIN, TAG, 'uninstall %{public}s', JSON.stringify(err));
      this.busy = false;
      this.notice = errorText(err);
    });
  }

  private host(): common.UIAbilityContext | undefined {
    let value = this.getUIContext().getHostContext();
    if (value === undefined) {
      return undefined;
    }
    return value as common.UIAbilityContext;
  }
}

function errorText(err: Object): string {
  let boxed: InstallError = err as InstallError;
  if (typeof boxed.message === 'string' && boxed.message.length > 0) {
    return boxed.message;
  }
  if (typeof boxed.code === 'number' && boxed.code !== 0) {
    return '卸载失败 ' + boxed.code.toString();
  }
  return '卸载失败';
}
