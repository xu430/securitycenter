import deviceInfo from '@ohos.deviceInfo';
import { Theme } from '../common/Theme';
import { BusyStage, FindingCard, FindingCardRecord, GhostButton, InfoLine, QuietStage, ScoreRing } from '../components/UiParts';
import { nowIso } from '../model/D4Types';
import { shortStamp } from '../model/ProbeStatus';
import { ImageChoice, LiveStore, ScanProgress } from '../model/LiveStore';
import { emptyProbeShelf, ProbeLimits, ProbeShelf } from '../probe/ProbeTypes';
import { Registry } from '../probe/Registry';
import { Finding, Findings } from '../report/Findings';
import {
  Ledger,
  LedgerEntry,
  countOpenFindings,
  pickImageTag
} from '../report/Ledger';

const PATCH_LINE = 'hap_verify_v2.cpp:1010-1023';

@Component
export struct SocView {
  @StorageLink('findings') findings: Finding[] = [];
  @StorageLink('probeShelf') probeShelf: ProbeShelf = emptyProbeShelf();
  @StorageLink('scanProgress') scanProgress: ScanProgress = new ScanProgress();
  @StorageLink('imageChoice') imageChoice: ImageChoice = new ImageChoice();
  @State osName: string = '';
  @State boardClock: string = '';
  @State probeCount: number = 0;
  @State notice: string = '';
  @Prop
  @Watch('onActiveChange')
  active: boolean = true;

  aboutToAppear(): void {
    this.refresh();
  }

  onActiveChange(): void {
    if (this.active) {
      this.readBoard();
    }
  }

  build() {
    Scroll() {
    Column() {
      if (this.notice.length > 0) {
        Text(this.notice)
          .width('100%')
          .fontSize(13)
          .fontColor(Theme.muted)
          .margin({ bottom: 12 })
      }

      if (this.scanProgress.running) {
        BusyStage({
          title: this.scanProgress.title,
          detail: this.stepLine()
        })
          .margin({ bottom: 12 })
      }

      if (this.probeShelf.runs.length === 0) {
        Column() {
          QuietStage({
            headline: '暂无检测数据',
            detail: '完成一次体检后，这里会显示检测概览。'
          })
        }
        .width('100%')
      } else {
        this.ringCard()
        this.streamCard()
        Column() {
          this.baselineCard()
        }
        .width('100%')
        .margin({ top: 12 })
        Column() {
          this.residualCard()
        }
        .width('100%')
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .backgroundColor(Theme.page)
    .onVisibleAreaChange([0.0], (expanding: boolean, ratio: number) => {
      if (expanding && ratio > 0) {
        this.readBoard();
      }
    })
  }

  @Builder
  ringCard() {
    Column() {
      Text('检测概览')
        .width('100%')
        .fontSize(16)
        .fontColor(Theme.accent)
        .margin({ bottom: 12 })
      Row() {
        ScoreRing({
          done: this.findingCount(),
          total: this.probeCount,
          caption: '发现/检测项'
        })
        Column() {
          Text(this.findingCount().toString())
            .fontSize(40)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.text)
          Text('发现')
            .fontSize(13)
            .fontColor(Theme.muted)
            .margin({ top: 2 })
          Text(this.probeCount.toString())
            .fontSize(40)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.text)
            .margin({ top: 8 })
          Text('检测项')
            .fontSize(13)
            .fontColor(Theme.muted)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 20 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .borderRadius(16)
    .backgroundColor(Theme.card)
    .margin({ bottom: 12 })
  }

  @Builder
  streamCard() {
    Column() {
      Text('检测记录')
        .width('100%')
        .fontSize(16)
        .fontColor(Theme.accent)
        .margin({ bottom: 8 })
      if (this.stream().length === 0) {
        Column() {
          Text('暂无检测记录')
            .width('100%')
            .fontSize(16)
            .fontColor(Theme.muted)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .height(120)
        .justifyContent(FlexAlign.Center)
      } else {
          Column() {
            ForEach(this.stream(), (item: LedgerEntry) => {
              Flex({ direction: FlexDirection.Row, alignItems: ItemAlign.Stretch }) {
                Column()
                  .width(6)
                  .backgroundColor(this.barColor(item))
                  .borderRadius(3)
                  .margin({ right: 8, bottom: 10 })
                Column() {
                  FindingCard({ record: this.cardOf(item) })
                }
                .layoutWeight(1)
              }
              .width('100%')
            }, (item: LedgerEntry) => item.findingId + item.status + item.registeredAt)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .borderRadius(16)
    .backgroundColor(Theme.card)
  }

  @Builder
  baselineCard() {
    Column() {
      Text('镜像基线')
        .width('100%')
        .fontSize(16)
        .fontColor(Theme.accent)
        .margin({ bottom: 8 })
      InfoLine({ label: '系统', value: this.osName.length === 0 ? '尚未读取' : this.osName })
      InfoLine({ label: '设备时间', value: shortStamp(this.boardClock) })
      Row() {
        Column() {
          Text('镜像')
            .width('100%')
            .fontSize(12)
            .fontColor(Theme.muted)
          Text(this.imageText())
            .width('100%')
            .fontSize(16)
            .fontColor(Theme.text)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Column() {
          Text('补丁行号')
            .width('100%')
            .fontSize(12)
            .fontColor(Theme.muted)
          Text(PATCH_LINE)
            .width('100%')
            .fontSize(14)
            .fontColor(Theme.text)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .margin({ bottom: 10 })
      Row() {
        Column() {
          GhostButton({
            label: '记为基础版',
            onTap: () => {
              this.choose('base');
            }
          })
        }
        .layoutWeight(1)
        .margin({ right: 8 })
        Column() {
          GhostButton({
            label: '记为安全版',
            onTap: () => {
              this.choose('secure');
            }
          })
        }
        .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .borderRadius(16)
    .backgroundColor(Theme.card)
  }

  @Builder
  residualCard() {
    Column() {
      Text('残余风险')
        .width('100%')
        .fontSize(16)
        .fontColor(Theme.accent)
        .margin({ bottom: 8 })
      Text('尚未处理完的检测记录会一直保留，直到有修复依据。')
        .width('100%')
        .fontSize(14)
        .fontColor(Theme.muted)
        .lineHeight(20)
        .margin({ bottom: 8 })
      InfoLine({ label: '待处理', value: this.openCount().toString() })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .borderRadius(16)
    .backgroundColor(Theme.card)
  }

  private stepLine(): string {
    if (!this.scanProgress.running || this.scanProgress.probeId !== 'P2') {
      return '';
    }
    if (this.scanProgress.step < 1 || this.scanProgress.total < 1) {
      return '';
    }
    return '第 ' + this.scanProgress.step.toString() + ' / ' + this.scanProgress.total.toString() + ' 条';
  }

  private refresh(): void {
    Registry.registerAll();
    this.probeCount = Registry.all().length;
    this.readBoard();
  }

  private readBoard(): void {
    let name = '';
    try {
      let read = deviceInfo.osFullName;
      if (typeof read === 'string') {
        name = read;
      }
    } catch (err) {
      name = '';
    }
    this.osName = name;
    this.boardClock = nowIso();
  }

  private findingCount(): number {
    if (this.findings.length < 0) {
      return 0;
    }
    return Findings.list().length;
  }

  private stream(): LedgerEntry[] {
    if (this.findings.length < 0) {
      return [];
    }
    return Ledger.entries();
  }

  private openCount(): number {
    if (this.findings.length < 0) {
      return 0;
    }
    return countOpenFindings(Findings.list());
  }

  private imageText(): string {
    let tag = pickImageTag(this.imageChoice.imageTag, this.imageChoice.at, this.probeShelf.sidecar.imageTag,
      this.sidecarReady(), this.probeShelf.importAt);
    if (tag === 'base') {
      return '基础版';
    }
    if (tag === 'secure') {
      return '安全版';
    }
    return '镜像未知';
  }

  private sidecarReady(): boolean {
    return this.probeShelf.sidecarPresent && this.probeShelf.importState === ProbeLimits.importImported;
  }

  private cardOf(item: LedgerEntry): FindingCardRecord {
    let card = new FindingCardRecord();
    card.findingId = item.findingId;
    card.scenarioId = item.scenarioId;
    card.title = item.title;
    card.status = item.status;
    card.registeredAt = item.registeredAt;
    card.evidenceNo = item.evidenceNo;
    return card;
  }

  private barColor(item: LedgerEntry): string {
    if (item.scenarioId === 'C1') {
      return Theme.accent;
    }
    if (item.status === 'fixed-by-patch' && item.evidenceNo.length >= 3) {
      return Theme.ok;
    }
    if (item.status === 'fixed-by-patch') {
      return Theme.warn;
    }
    if (item.status === 'open') {
      return Theme.danger;
    }
    return Theme.line;
  }

  private choose(tag: string): void {
    try {
      LiveStore.noteImageChoice(tag);
      this.notice = tag === 'secure' ? '已记下安全版' : '已记下基础版';
      LiveStore.setStatus(this.notice);
    } catch (err) {
      this.notice = '镜像标签写入失败';
      LiveStore.setStatus(this.notice);
    }
  }
}
