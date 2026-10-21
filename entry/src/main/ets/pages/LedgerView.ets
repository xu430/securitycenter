import { common } from '@kit.AbilityKit';
import { Theme } from '../common/Theme';
import { BusyStage, EvidenceSheet, FindingCard, FindingCardRecord, PrimaryButton, QuietStage } from '../components/UiParts';
import { LiveStore, ScanProgress } from '../model/LiveStore';
import { emptyProbeShelf, ProbeShelf } from '../probe/ProbeTypes';
import { Finding } from '../report/Findings';
import { Ledger, LedgerEntry, LedgerEvidence } from '../report/Ledger';

@Component
export struct LedgerView {
  @StorageLink('findings') findings: Finding[] = [];
  @StorageLink('probeShelf') probeShelf: ProbeShelf = emptyProbeShelf();
  @StorageLink('scanProgress') scanProgress: ScanProgress = new ScanProgress();
  @State selectedId: string = '';
  @State showSheet: boolean = false;
  @State exporting: boolean = false;
  @State notice: string = '';

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

        if (this.rows().length === 0 && !this.scanProgress.running) {
          QuietStage({
            headline: '暂无风险记录',
            detail: '完成一次体检后，这里会列出检测记录。'
          })
            .margin({ bottom: 12 })
        } else if (this.rows().length > 0) {
          ForEach(this.rows(), (item: LedgerEntry) => {
            Column() {
              if (this.phraseOf(item).length > 0) {
                Text(this.phraseOf(item))
                  .width('100%')
                  .fontSize(20)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.phraseInk(item))
                  .maxLines(2)
                  .padding({ left: 16, right: 16, top: 16 })
              }
              FindingCard({ record: this.cardOf(item) })
            }
            .width('100%')
            .borderRadius(16)
            .backgroundColor(Theme.card)
            .margin({ bottom: 12 })
            .onClick(() => {
              this.openEntry(item);
            })
          }, (item: LedgerEntry) => item.findingId + item.status + item.registeredAt + item.evidenceNo)
        }

        PrimaryButton({
          label: this.exporting ? '正在导出' : '导出记录',
          canTap: !this.exporting,
          onTap: () => {
            this.handOff();
          }
        })
      }
      .width('100%')
      .padding(16)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
    .backgroundColor(Theme.page)
    .bindSheet(this.showSheet, this.sheetBuilder(), {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: true,
      backgroundColor: Theme.card,
      onDisappear: () => {
        this.showSheet = false;
      }
    })
  }

  @Builder
  sheetBuilder() {
    Scroll() {
      Column() {
        ForEach(this.openedLines(), (line: LedgerEvidence, index: number) => {
          EvidenceSheet({
            kind: this.kindLabel(line.kind),
            text: line.text,
            raw: line.raw,
            at: line.at
          })
            .margin({ top: index === 0 ? 0 : 20 })
        }, (line: LedgerEvidence, index: number) => line.kind + index.toString() + line.at + line.raw.length.toString())
      }
      .width('100%')
      .padding(20)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
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

  private phraseOf(item: LedgerEntry): string {
    if (item.runs.length === 0) {
      return '';
    }
    return item.runs[0].phrase;
  }

  private phraseInk(item: LedgerEntry): string {
    if (item.runs.length === 0) {
      return Theme.muted;
    }
    if (item.runs[0].verdict === 'hit') {
      return Theme.danger;
    }
    if (item.runs[0].verdict === 'blocked') {
      return Theme.ok;
    }
    if (item.runs[0].verdict === 'passive') {
      return Theme.accent;
    }
    return Theme.muted;
  }

  private rows(): LedgerEntry[] {
    if (this.findings.length < 0 || this.probeShelf.runs.length < 0) {
      return [];
    }
    return Ledger.entries();
  }

  private openEntry(item: LedgerEntry): void {
    if (this.linesOf(item).length === 0) {
      return;
    }
    this.selectedId = item.findingId;
    this.showSheet = true;
  }

  private openedLines(): LedgerEvidence[] {
    let row = this.opened();
    if (row === undefined) {
      return [];
    }
    return this.linesOf(row);
  }

  private linesOf(item: LedgerEntry): LedgerEvidence[] {
    let out: LedgerEvidence[] = [];
    if (item.runs.length === 0) {
      return out;
    }
    let run = item.runs[0];
    for (let i = 0; i < run.evidences.length; i++) {
      let line = run.evidences[i];
      if (line.text.length > 0 || line.raw.length > 0) {
        out.push(line);
      }
    }
    return out;
  }

  private kindLabel(kind: string): string {
    if (kind === 'cmd-transcript') {
      return '命令回显';
    }
    if (kind === 'bundle-state') {
      return '安装状态';
    }
    if (kind === 'source-ref') {
      return '源码行号';
    }
    if (kind === 'errno') {
      return '错误码';
    }
    if (kind === 'hilog-line') {
      return '点击';
    }
    if (kind === 'sidecar-state') {
      return '检测报告';
    }
    return kind;
  }

  private opened(): LedgerEntry | undefined {
    if (this.findings.length < 0 || this.probeShelf.runs.length < 0) {
      return undefined;
    }
    return Ledger.detail(this.selectedId);
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

  private host(): common.UIAbilityContext | undefined {
    let value = this.getUIContext().getHostContext();
    if (value === undefined) {
      return undefined;
    }
    return value as common.UIAbilityContext;
  }

  private async handOff(): Promise<void> {
    if (this.exporting) {
      return;
    }
    this.exporting = true;
    let message = '保存失败';
    try {
      let ctx = this.host();
      if (ctx === undefined) {
        message = '无法取得应用上下文';
      } else {
        message = await Ledger.saveForArchive(ctx);
      }
      this.notice = message;
      LiveStore.setStatus(message);
    } finally {
      this.exporting = false;
    }
  }
}
