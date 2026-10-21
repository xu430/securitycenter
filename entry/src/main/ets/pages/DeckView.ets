import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import bundleManager from '@ohos.bundle.bundleManager';
import deviceInfo from '@ohos.deviceInfo';
import { Theme } from '../common/Theme';
import { BoardPane, PrimaryButton, ShowDock } from '../components/UiParts';
import {
  ActFace,
  BundleSight,
  CheckItem,
  DeckBeat,
  actFace,
  checklistReady,
  deckBeats,
  evaluateChecklist,
  placeholderCount,
  sidecarReady,
  sightFromCode,
  sightInstalled
} from '../deck/DeckScript';
import { encodeProbeEvents, formatBundle } from '../model/D4Codec';
import { D4Event } from '../model/D4Types';
import { FileExchange } from '../model/FileExchange';
import { clockText } from '../model/ShowDeck';
import { LiveStore } from '../model/LiveStore';
import { Findings } from '../report/Findings';
import { LAKESIDE_BUNDLE } from '../probe/InstallIntegrityProbe';
import { Registry } from '../probe/Registry';
import { ProbeShelf, emptyProbeShelf } from '../probe/ProbeTypes';

const DOMAIN = 0x4A59;
const TAG = 'DeckView';

class ErrorBox {
  code: number = 0;
}

@Component
export struct TrophyView {
  build() {
    Column() {
      Text('李鬼同屏')
        .fontSize(16)
        .fontColor(Theme.accent)
      Text('照片位空着')
        .fontSize(14)
        .fontColor(Theme.text)
        .margin({ top: 6 })
    }
    .width(120)
    .height(120)
    .justifyContent(FlexAlign.Center)
    .border({ width: 1, color: Theme.accent })
    .borderRadius(12)
    .backgroundColor(Theme.card)
  }
}

@Component
export struct DeckView {
  @StorageLink('probeShelf') probeShelf: ProbeShelf = emptyProbeShelf();
  @StorageLink('liveEvents') liveEvents: D4Event[] = [];
  @StorageLink('statusLine') statusLine: string = '';
  @Prop
  @Watch('onActiveChange')
  active: boolean = true;
  @Prop
  @Watch('onPauseMark')
  pauseMark: number = 0;
  @Prop
  @Watch('onPrepTick')
  prepTick: number = 0;
  @State started: boolean = false;
  @State playing: boolean = false;
  @State checking: boolean = false;
  @State ready: boolean = false;
  @State beatIndex: number = 0;
  @State elapsed: number = 0;
  @State busy: boolean = false;
  @State exporting: boolean = false;
  @State tick: number = 0;
  @State checks: CheckItem[] = [];
  onPrep: () => void = () => {};
  onStarted: (started: boolean) => void = (started: boolean) => {};
  onRecheck: () => void = () => {};
  private timer: number = -1;

  aboutToAppear(): void {
    this.refreshChecks(false);
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  onActiveChange(): void {
    if (!this.active) {
      this.playing = false;
      this.stopTimer();
      return;
    }
    if (!this.started) {
      this.refreshChecks(true);
    }
  }

  onPrepTick(): void {
    if (!this.started) {
      this.refreshChecks(true);
    }
  }

  onPauseMark(): void {
    this.playing = false;
    this.stopTimer();
  }

  build() {
    Column() {
      if (!this.started) {
        this.checklistBody()
      } else {
        this.showBody()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.page)
  }

  @Builder
  checklistBody() {
    Scroll() {
      Column() {
        Text('正片前检查')
          .width('100%')
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.text)
        Text('四项都是读出来的，不能手勾。')
          .width('100%')
          .fontSize(13)
          .fontColor(Theme.muted)
          .margin({ top: 6, bottom: 12 })
        ForEach(this.checks, (item: CheckItem) => {
          Row() {
            Text(item.title)
              .fontSize(16)
              .fontColor(Theme.text)
              .maxLines(2)
              .layoutWeight(1)
            Text(item.detail)
              .fontSize(14)
              .fontColor(item.passed ? Theme.ok : Theme.warn)
              .textAlign(TextAlign.End)
              .maxLines(3)
              .layoutWeight(1)
              .margin({ left: 12 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .padding(16)
          .borderRadius(14)
          .backgroundColor(Theme.card)
          .margin({ top: 8 })
        }, (item: CheckItem) => item.id + (item.passed ? '1' : '0') + item.detail)

        PrimaryButton({
          label: '重新检查',
          canTap: !this.checking,
          onTap: () => {
            this.refreshChecks(true);
          }
        })
          .margin({ top: 16 })
        PrimaryButton({
          label: this.ready ? '开演' : '未通过不能开演',
          canTap: this.ready && !this.checking,
          onTap: () => {
            this.begin();
          }
        })
          .margin({ top: 8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
    .backgroundColor(Theme.page)
  }

  @Builder
  showBody() {
    Column() {
      if (this.boundaryBeat()) {
        Column() {
          Text(this.currentFace().phrase)
            .width('100%')
            .fontSize(28)
            .fontColor(Theme.accent)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding(24)
        .backgroundColor(Theme.page)
      } else {
        Column() {
          Text(this.currentFace().title.length > 0 ? this.currentFace().title : this.current().title)
            .width('100%')
            .fontSize(16)
            .fontColor(Theme.muted)
          BoardPane({
            role: this.currentFace().role,
            focused: true,
            face: 'result',
            phrase: this.currentFace().phrase,
            timeText: this.currentFace().at.length > 0 ? clockText(this.currentFace().at) : '',
            outcome: this.currentFace().outcome,
            phraseInk: this.inkColor(this.currentFace().ink),
            demoMark: false
          })
            .layoutWeight(1)
            .margin({ top: 8 })

          if (this.currentFace().showPatch) {
            Row() {
              Text(this.currentFace().imageLabel)
                .fontSize(14)
                .fontColor(Theme.ok)
              Text(this.currentFace().patchLine)
                .fontSize(14)
                .fontColor(Theme.ok)
                .margin({ left: 12 })
            }
            .width('100%')
            .margin({ top: 8 })
          }

          if (this.current().id === 'act2') {
            Row() {
              TrophyView()
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ top: 8 })
          }

          if (this.current().id === 'act2' || this.current().id === 'act3') {
            PrimaryButton({
              label: this.busy ? '正在扫描' : '一键自动扫描',
              canTap: !this.busy,
              onTap: () => {
                this.startScan();
              }
            })
              .margin({ top: 8 })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor(Theme.page)
      }

      if (this.current().id === 'end') {
        PrimaryButton({
          label: this.exporting ? '正在导出' : '交给归档',
          canTap: !this.exporting,
          onTap: () => {
            this.handOff();
          }
        })
          .margin({ left: 16, right: 16, bottom: 8 })
      }

      Row() {
        if (this.elapsed > 0) {
          Column()
            .layoutWeight(this.elapsed)
            .height(6)
            .backgroundColor(Theme.accent)
        }
        if (this.remainWeight() > 0) {
          Column()
            .layoutWeight(this.remainWeight())
            .height(6)
            .backgroundColor(Theme.line)
        }
      }
      .width('100%')
      .height(6)

      ShowDock({
        toggleText: this.playing ? '暂停' : '继续',
        remainText: '剩余 ' + this.remainWeight().toString() + ' 秒',
        onPrep: () => {
          this.onPrep();
        },
        onToggle: () => {
          this.toggle();
        },
        onNext: () => {
          this.advance();
        }
      })

      Text('回到检查')
        .fontSize(14)
        .fontColor(Theme.accent)
        .padding({ bottom: 12 })
        .onClick(() => {
          this.stopShow();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.page)
  }

  private begin(): void {
    this.refreshChecks(true);
    if (!this.ready || this.checking) {
      return;
    }
    this.beatIndex = 0;
    this.elapsed = 0;
    this.started = true;
    this.playing = true;
    this.onStarted(true);
    this.startTimer();
  }

  private stopShow(): void {
    this.playing = false;
    this.stopTimer();
    this.started = false;
    this.onStarted(false);
    this.refreshChecks(true);
  }

  private toggle(): void {
    this.playing = !this.playing;
    if (this.playing) {
      this.startTimer();
    } else {
      this.stopTimer();
    }
  }

  private startTimer(): void {
    this.stopTimer();
    this.timer = setInterval(() => {
      this.onTick();
    }, 1000);
  }

  private stopTimer(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private onTick(): void {
    if (!this.playing) {
      return;
    }
    if (this.elapsed + 1 >= this.current().seconds) {
      this.advance();
      return;
    }
    this.elapsed = this.elapsed + 1;
  }

  private advance(): void {
    let rows = deckBeats();
    if (this.beatIndex + 1 >= rows.length) {
      this.elapsed = this.current().seconds;
      this.playing = false;
      this.stopTimer();
      return;
    }
    this.beatIndex = this.beatIndex + 1;
    this.elapsed = 0;
  }

  private remainWeight(): number {
    let left = this.current().seconds - this.elapsed;
    if (left < 0) {
      return 0;
    }
    return left;
  }

  private current(): DeckBeat {
    let rows = deckBeats();
    if (this.beatIndex < 0 || this.beatIndex >= rows.length) {
      return rows[0];
    }
    return rows[this.beatIndex];
  }

  private boundaryBeat(): boolean {
    let id = this.current().id;
    return id === 'gap1' || id === 'gap2' || id === 'end';
  }

  private currentFace(): ActFace {
    let ignored = this.tick;
    if (ignored < 0) {
      return actFace(this.current().id, this.probeShelf.runs);
    }
    return actFace(this.current().id, this.probeShelf.runs);
  }

  private inkColor(ink: string): string {
    if (ink === 'danger') {
      return Theme.danger;
    }
    if (ink === 'ok') {
      return Theme.ok;
    }
    if (ink === 'gold') {
      return Theme.accent;
    }
    return Theme.muted;
  }

  private refreshChecks(notify: boolean): void {
    this.checking = true;
    if (notify) {
      this.onRecheck();
    }
    let sight = this.readSight();
    let items = evaluateChecklist(new Date().getFullYear(), sidecarReady(this.probeShelf), sight,
      placeholderCount(this.liveEvents));
    this.checks = items;
    this.ready = checklistReady(items);
    this.checking = false;
  }

  private readSight(): BundleSight {
    try {
      let info = bundleManager.getBundleInfoSync(LAKESIDE_BUNDLE, bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      return sightInstalled(info.versionCode);
    } catch (err) {
      let boxed: ErrorBox = err as ErrorBox;
      hilog.error(DOMAIN, TAG, 'bundle %{public}s', JSON.stringify(err));
      return sightFromCode(boxed.code);
    }
  }

  private scanTitle(id: string): string {
    if (id === 'P1') {
      return '安装完整性';
    }
    if (id === 'P2') {
      return '沙箱隔离';
    }
    if (id === 'P3') {
      return '安全组件姿态';
    }
    return id;
  }

  private startScan(): void {
    if (this.busy) {
      return;
    }
    let ctx = this.host();
    if (ctx === undefined) {
      LiveStore.setStatus('无法扫描');
      return;
    }
    Registry.registerAll();
    let probes = Registry.all();
    if (probes.length === 0) {
      LiveStore.setStatus('没有已登记的探针');
      return;
    }
    this.busy = true;
    Registry.runAll(ctx, () => {
      this.tick = this.tick + 1;
    }, (id: string) => {
      LiveStore.beginScan(id, this.scanTitle(id));
    }).then(() => {
      LiveStore.endScan();
      this.busy = false;
      this.tick = this.tick + 1;
    }).catch((err: Object) => {
      hilog.error(DOMAIN, TAG, 'scan %{public}s', JSON.stringify(err));
      LiveStore.setStatus('扫描中断');
      LiveStore.endScan();
      this.busy = false;
    });
  }

  private handOff(): void {
    if (this.exporting) {
      return;
    }
    this.exporting = true;
    let ctx = this.host();
    if (ctx === undefined) {
      LiveStore.setStatus('无法取得应用上下文');
      this.exporting = false;
      return;
    }
    let events = encodeProbeEvents(Findings.list(), this.probeShelf.runs, this.probeShelf.boardUdid, this.readImageVersion());
    if (events.length === 0) {
      LiveStore.setStatus('演示前无事件');
      this.exporting = false;
      return;
    }
    FileExchange.saveText(ctx, 'jinyinhu-d4-events.json', formatBundle(events)).then((saved) => {
      LiveStore.setStatus(saved.message);
      this.exporting = false;
    }).catch((err: Object) => {
      hilog.error(DOMAIN, TAG, 'export %{public}s', JSON.stringify(err));
      LiveStore.setStatus('保存失败');
      this.exporting = false;
    });
  }

  private readImageVersion(): string {
    let version = deviceInfo.displayVersion;
    if (typeof version !== 'string' || version.trim().length === 0) {
      version = deviceInfo.osFullName;
    }
    if (typeof version !== 'string') {
      return '';
    }
    let trimmed = version.trim();
    if (trimmed.indexOf('\n') >= 0 || trimmed.indexOf('\r') >= 0) {
      return '';
    }
    if (trimmed.length > 32) {
      return trimmed.substring(0, 32);
    }
    return trimmed;
  }

  private host(): common.UIAbilityContext | undefined {
    let value = this.getUIContext().getHostContext();
    if (value === undefined) {
      return undefined;
    }
    return value as common.UIAbilityContext;
  }
}
