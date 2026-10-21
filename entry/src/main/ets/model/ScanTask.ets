import type { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LiveStore } from './LiveStore';
import { probeName } from './ProbeStatus';
import { Registry } from '../probe/Registry';
import type { ProbeId } from '../probe/ProbeTypes';

const DOMAIN = 0x4A59;
const TAG = 'ScanTask';

export class ScanTask {
  private static busy: boolean = false;

  static running(): boolean {
    return ScanTask.busy || LiveStore.scanProgress().running;
  }

  static async run(ctx: common.UIAbilityContext, ids: string[]): Promise<void> {
    if (ScanTask.running()) {
      return;
    }
    Registry.registerAll();
    if (Registry.all().length === 0) {
      LiveStore.setStatus('没有可用的检测项');
      return;
    }
    ScanTask.busy = true;
    try {
      await Registry.runSome(ctx, ids, () => {}, (id: ProbeId) => {
        LiveStore.beginScan(id, probeName(id));
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'scan %{public}s', JSON.stringify(err));
      LiveStore.setStatus('检测中断');
    } finally {
      ScanTask.busy = false;
      LiveStore.endScan();
    }
  }
}
