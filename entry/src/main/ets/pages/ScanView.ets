import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import { picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Theme } from '../common/Theme';
import { BusyStage, DemoBadge, EvidenceSheet, GhostButton, PrimaryButton, QuietStage } from '../components/UiParts';
import { LiveStore, ScanProgress } from '../model/LiveStore';
import { PROBE_IDS, probeName } from '../model/ProbeStatus';
import { ScanTask } from '../model/ScanTask';
import { DoppelUninstall } from './DoppelUninstall';
import { nowIso } from '../model/D4Types';
import { PATCH_LINE } from '../probe/InstallIntegrityProbe';
import { acceptProbeRun } from '../probe/ProbeCodec';
import { Registry } from '../probe/Registry';
import { isPasteRaw, SecCompPostureProbe } from '../probe/SecCompPostureProbe';
import { ProbeEvidence, ProbeRun, ProbeRunFault, ProbeShelf, emptyProbeShelf, isStamp } from '../probe/ProbeTypes';

const DOMAIN = 0x4A59;
const TAG = 'ScanView';

class EvidenceLine {
  key: string = '';
  kind: string = '';
  text: string = '';
  raw: string = '';
  at: string = '';
  hot: boolean = false;
}

@Component
export struct ScanView {
  @StorageLink('probeShelf') probeShelf: ProbeShelf = emptyProbeShelf();
  @StorageLink('scanProgress') scanProgress: ScanProgress = new ScanProgress();
  @Prop only: string = '';
  @State busy: boolean = false;
  @State activeId: string = '';
  @State tick: number = 0;
  @State showEvidence: boolean = false;
  @State sheetKind: string = '';
  @State sheetText: string = '';
  @State sheetRaw: string = '';
  @State sheetAt: string = '';

  aboutToAppear(): void {
    Registry.registerAll();
  }

  build() {
    Scroll() {
      Column() {
        if (this.scanProgress.running) {
          BusyStage({
            title: this.scanProgress.title,
            detail: this.stepLine()
          })
            .margin({ bottom: 12 })
        } else if (this.settledIds().length === 0) {
          QuietStage({
            headline: '尚未检测',
            detail: this.wantsReport() ? '先导入检测报告，再开始检测。' : '点下方按钮开始检测。'
          })
            .margin({ bottom: 12 })
        }

        ForEach(this.shownIds(), (id: string) => {
          this.probeCard(id)
        }, (id: string) => id + this.tick.toString() + this.scanProgress.step.toString())

        Column() {
          PrimaryButton({
            label: this.scanBusy() ? '检测中…' : (this.settledIds().length > 0 ? '重新检测' : '开始检测'),
            canTap: !this.scanBusy(),
            onTap: () => {
              this.startScan();
            }
          })
          if (this.wantsReport()) {
            GhostButton({
              label: '导入检测报告',
              onTap: () => {
                this.importSidecar();
              }
            })
          }
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 12 })
      }
      .width('100%')
      .padding(16)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .backgroundColor(Theme.page)
    .scrollBar(BarState.Off)
    .bindSheet(this.showEvidence, this.evidenceSheet(), {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: true,
      backgroundColor: Theme.card,
      onDisappear: () => {
        this.showEvidence = false;
      }
    })
  }

  @Builder
  evidenceSheet() {
    Scroll() {
      EvidenceSheet({
        kind: this.sheetKind,
        text: this.sheetText,
        raw: this.sheetRaw,
        at: this.sheetAt
      })
        .width('100%')
        .padding(20)
    }
    .width('100%')
    .align(Alignment.TopStart)
    .backgroundColor(Theme.card)
  }

  @Builder
  probeCard(id: string) {
    Column() {
      Row() {
        Text(this.probeTitle(id))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.text)
          .layoutWeight(1)
        if (this.disclose(id)) {
          Column() {
            DemoBadge()
          }
          .margin({ left: 8 })
        }
      }
      .width('100%')

      if (this.probeRisk(id).length > 0) {
        Text(this.probeRisk(id))
          .width('100%')
          .fontSize(13)
          .fontColor(Theme.muted)
          .margin({ top: 6 })
      }

      Text(this.phraseText(id))
        .width('100%')
        .fontSize(this.showingRun(id) ? Theme.phraseSize : 20)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.phraseColor(id))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 12 })

      if (!this.showingRun(id) && !this.scanningThis(id)) {
        Text(this.visibleFault(id) !== undefined ? this.faultText(id) : this.emptyHint(id))
          .width('100%')
          .fontSize(14)
          .fontColor(Theme.muted)
          .margin({ top: 8 })
      }

      if (this.scanningThis(id) && this.stepLine().length > 0 && id === 'P2') {
        Text(this.stepLine())
          .width('100%')
          .fontSize(16)
          .fontColor(Theme.muted)
          .margin({ top: 8 })
      }

      if (id === 'P1' && this.showingRun(id)) {
        Row() {
          Text(this.imageCaption(id))
            .fontSize(13)
            .fontColor(Theme.accent)
          Text(PATCH_LINE)
            .fontSize(13)
            .fontColor(Theme.accent)
            .margin({ left: 12 })
        }
        .width('100%')
        .margin({ top: 12 })
      }

      if (this.linesFor(id).length > 0) {
        Scroll() {
          Column() {
            ForEach(this.linesFor(id), (line: EvidenceLine) => {
              this.evidenceRow(line)
            }, (line: EvidenceLine) => line.key)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height(220)
        .scrollBar(BarState.Off)
        .align(Alignment.TopStart)
        .margin({ top: 12 })
      }

      if (id === 'P1' && !this.scanningThis(id)) {
        DoppelUninstall()
          .margin({ top: 12 })
      }

      if (id === 'P3' && !this.scanningThis(id)) {
        this.postureBlock()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(16)
    .backgroundColor(Theme.card)
    .border({ width: this.scanningThis(id) ? 1.5 : 0, color: this.cardColor(id) })
    .margin({ bottom: 12 })
  }

  private startScan(): void {
    if (this.scanBusy()) {
      return;
    }
    let ctx = this.host();
    if (ctx === undefined) {
      LiveStore.setStatus('无法开始检测');
      return;
    }
    this.busy = true;
    let ids: string[] = [];
    if (this.only.length > 0) {
      ids.push(this.only);
    }
    ScanTask.run(ctx, ids).then(() => {
      this.finishScan();
    }).catch((err: Object) => {
      hilog.error(DOMAIN, TAG, 'scan %{public}s', JSON.stringify(err));
      LiveStore.setStatus('检测中断');
      this.finishScan();
    });
  }

  private finishScan(): void {
    this.busy = false;
    this.activeId = '';
    this.tick = this.tick + 1;
  }

  private wantsReport(): boolean {
    return this.only.length === 0 || this.only === 'P1';
  }

  private cardRaw(line: EvidenceLine): string {
    if (line.kind === '命令回显' || line.kind === '检测报告') {
      return '';
    }
    if (line.raw.length === 0 || line.raw.length > 160) {
      return '';
    }
    if (line.raw.indexOf('\n') >= 0 || line.raw.indexOf('{') >= 0 || line.raw.indexOf('}') >= 0) {
      return '';
    }
    return line.raw;
  }

  private openEvidence(line: EvidenceLine): void {
    if (line.text.length === 0 && line.raw.length === 0) {
      return;
    }
    this.sheetKind = line.kind;
    this.sheetText = line.text;
    this.sheetRaw = line.raw;
    this.sheetAt = line.at;
    this.showEvidence = true;
  }

  private scanBusy(): boolean {
    return this.busy || this.scanProgress.running;
  }

  private settledIds(): string[] {
    let ids = this.probeIds();
    let picked: string[] = [];
    for (let i = 0; i < ids.length; i++) {
      if (this.visibleRun(ids[i]) !== undefined || this.visibleFault(ids[i]) !== undefined) {
        picked.push(ids[i]);
      }
    }
    return picked;
  }

  private shownIds(): string[] {
    let ids = this.probeIds();
    let picked: string[] = [];
    for (let i = 0; i < ids.length; i++) {
      let id = ids[i];
      if (this.scanningThis(id) || this.visibleRun(id) !== undefined || this.visibleFault(id) !== undefined) {
        picked.push(id);
      }
    }
    return picked;
  }

  private linesFor(id: string): EvidenceLine[] {
    let rows: EvidenceLine[] = [];
    if (id === 'P2' && this.scanningThis(id)) {
      let lines = this.scanProgress.lines;
      for (let i = 0; i < lines.length; i++) {
        if (lines[i].category.length === 0 && lines[i].raw.length === 0) {
          continue;
        }
        let row = new EvidenceLine();
        row.key = 'step' + lines[i].index.toString();
        row.kind = '错误码';
        row.text = lines[i].category;
        row.raw = lines[i].raw;
        row.at = lines[i].at;
        row.hot = lines[i].index === this.scanProgress.step;
        rows.push(row);
      }
      return rows;
    }
    if (id === 'P3') {
      this.appendEvidences(rows, this.sourceRun(), 'p3ref');
      this.appendClick(rows);
      return rows;
    }
    if (!this.showingRun(id)) {
      return rows;
    }
    this.appendEvidences(rows, this.visibleRun(id), id);
    return rows;
  }

  private appendEvidences(rows: EvidenceLine[], run: ProbeRun | undefined, prefix: string): void {
    if (run === undefined || run.evidences === undefined) {
      return;
    }
    for (let i = 0; i < run.evidences.length; i++) {
      let item = run.evidences[i];
      let label = this.kindLabel(item.kind);
      if (label.length === 0 || (item.text.length === 0 && item.raw.length === 0)) {
        continue;
      }
      let row = new EvidenceLine();
      row.key = prefix + i.toString() + item.kind;
      row.kind = label;
      row.text = item.text;
      row.raw = item.raw;
      row.at = item.at;
      rows.push(row);
    }
  }

  private appendClick(rows: EvidenceLine[]): void {
    let runs = this.probeShelf.runs;
    let bestAt = '';
    let bestText = '';
    let bestRaw = '';
    for (let i = 0; i < runs.length; i++) {
      if (runs[i].probeId !== 'P3' || runs[i].evidences === undefined) {
        continue;
      }
      let evidences = runs[i].evidences;
      for (let j = 0; j < evidences.length; j++) {
        if (!isPasteRaw(evidences[j].raw) || evidences[j].text.length === 0) {
          continue;
        }
        if (bestAt.length === 0 || evidences[j].at >= bestAt) {
          bestAt = evidences[j].at;
          bestText = evidences[j].text;
          bestRaw = evidences[j].raw;
        }
      }
    }
    if (bestText.length === 0 && bestRaw.length === 0) {
      return;
    }
    let row = new EvidenceLine();
    row.key = 'click' + bestAt;
    row.kind = '点击';
    row.text = bestText;
    row.raw = bestRaw;
    row.at = bestAt;
    rows.push(row);
  }

  private sourceRun(): ProbeRun | undefined {
    let runs = this.probeShelf.runs;
    let best: ProbeRun | undefined = undefined;
    for (let i = 0; i < runs.length; i++) {
      if (runs[i].probeId !== 'P3' || runs[i].level !== 'L3' || runs[i].evidences === undefined) {
        continue;
      }
      let hasRef = false;
      for (let j = 0; j < runs[i].evidences.length; j++) {
        if (runs[i].evidences[j].kind === 'source-ref' &&
          (runs[i].evidences[j].text.length > 0 || runs[i].evidences[j].raw.length > 0)) {
          hasRef = true;
        }
      }
      if (!hasRef) {
        continue;
      }
      if (best === undefined || runs[i].createdAt >= best.createdAt) {
        best = runs[i];
      }
    }
    return best;
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
    return '';
  }

  private probeRisk(id: string): string {
    let probes = Registry.all();
    for (let i = 0; i < probes.length; i++) {
      if (probes[i].id === id && probes[i].risk.length > 0) {
        return probes[i].risk;
      }
    }
    if (id === 'P1') {
      return '检测是否有恶意安装包，是否有绕过安装等风险';
    }
    if (id === 'P2') {
      return '检测应用之间是否隔离，是否有读取私有文件的风险';
    }
    if (id === 'P3') {
      return '检测安全控件是否可信，是否有绕过授权的风险';
    }
    return '';
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

  private faultText(id: string): string {
    let fault = this.visibleFault(id);
    if (fault === undefined) {
      return '';
    }
    return '原因：' + fault.reason;
  }

  private emptyHint(id: string): string {
    if (id === 'P1') {
      return '先导入检测报告，再开始检测。';
    }
    return '点开始检测。';
  }

  private importSidecar(): void {
    if (this.scanBusy()) {
      return;
    }
    let ctx = this.host();
    if (ctx === undefined) {
      LiveStore.setStatus('无法取得应用上下文');
      return;
    }
    this.readSidecar(ctx);
  }

  private readSidecar(ctx: common.UIAbilityContext): void {
    let options = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = ['检测报告|.json'];
    let view = new picker.DocumentViewPicker(ctx);
    view.select(options).then((uris: string[]) => {
      if (uris.length === 0) {
        LiveStore.setStatus('未导入');
        return;
      }
      let text = this.readUri(uris[0]);
      if (text.length === 0) {
        LiveStore.setStatus('检测报告读取失败');
        return;
      }
      Registry.ingestSidecar(text);
      this.tick = this.tick + 1;
    }).catch((err: Object) => {
      hilog.error(DOMAIN, TAG, 'sidecar %{public}s', JSON.stringify(err));
      LiveStore.setStatus('检测报告读取失败');
    });
  }

  private readUri(uri: string): string {
    try {
      let file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      try {
        let stat = fs.statSync(file.fd);
        if (stat.size <= 0 || stat.size > 1000000) {
          fs.closeSync(file);
          return '';
        }
        let buffer = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buffer);
        fs.closeSync(file);
        let decoder = util.TextDecoder.create('utf-8');
        return decoder.decodeToString(new Uint8Array(buffer));
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'read %{public}s', JSON.stringify(err));
        fs.closeSync(file);
        return '';
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'open %{public}s', JSON.stringify(err));
      return '';
    }
  }

  private disclose(id: string): boolean {
    if (id !== 'P1' || !this.showingRun(id)) {
      return false;
    }
    let run = this.visibleRun(id);
    if (run === undefined) {
      return false;
    }
    return run.verdict === 'passive' && run.level === 'L3';
  }

  private imageCaption(id: string): string {
    let run = this.visibleRun(id);
    if (run !== undefined && run.imageRole === 'secure') {
      return '安全版';
    }
    return '基础版';
  }

  @Builder
  evidenceRow(line: EvidenceLine) {
    Row() {
      Text(line.kind)
        .width(72)
        .fontSize(12)
        .fontColor(Theme.accent)
      Column() {
        if (line.text.length > 0) {
          Text(line.text)
            .width('100%')
            .fontSize(14)
            .fontColor(Theme.text)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (this.cardRaw(line).length > 0) {
          Text(this.cardRaw(line))
            .width('100%')
            .fontSize(12)
            .fontColor(Theme.muted)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
        if (isStamp(line.at)) {
          Text(line.at)
            .width('100%')
            .fontSize(12)
            .fontColor(Theme.muted)
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: 8, right: 8, top: 8, bottom: 8 })
    .borderRadius(10)
    .backgroundColor(line.hot ? Theme.cardAlt : Theme.page)
    .margin({ top: 6 })
    .onClick(() => {
      this.openEvidence(line);
    })
  }

  @Builder
  postureBlock() {
    Column() {
      Column() {
        Text('点一次，记录系统组件是否回报')
          .width('100%')
          .fontSize(14)
          .fontColor(Theme.text)
          .margin({ bottom: 10 })
        PasteButton()
          .onClick((event: ClickEvent, result: PasteButtonOnClickResult) => {
            this.recordPaste(result);
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(12)
      .borderRadius(12)
      .border({ width: 1, color: Theme.line })
      .backgroundColor(Theme.cardAlt)
      .margin({ top: 12 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private recordPaste(result: PasteButtonOnClickResult): void {
    try {
      SecCompPostureProbe.noteClick(nowIso(), pasteToken(result));
      this.tick = this.tick + 1;
      LiveStore.setStatus('已记下组件回报');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'paste %{public}s', JSON.stringify(err));
      LiveStore.setStatus('组件回报没有落盘');
    }
  }

  private host(): common.UIAbilityContext | undefined {
    let value = this.getUIContext().getHostContext();
    if (value === undefined) {
      return undefined;
    }
    return value as common.UIAbilityContext;
  }

  private probeIds(): string[] {
    let ids: string[] = [];
    for (let i = 0; i < PROBE_IDS.length; i++) {
      if (this.only.length === 0 || this.only === PROBE_IDS[i]) {
        ids.push(PROBE_IDS[i]);
      }
    }
    return ids;
  }

  private probeTitle(id: string): string {
    return probeName(id);
  }

  private showingRun(id: string): boolean {
    return this.visibleRun(id) !== undefined && !this.scanningThis(id);
  }

  private phraseText(id: string): string {
    if (this.scanningThis(id)) {
      return '正在检测';
    }
    let run = this.visibleRun(id);
    if (run !== undefined) {
      return run.phrase;
    }
    if (this.visibleFault(id) !== undefined) {
      return '检测未完成';
    }
    return '尚未检测';
  }

  private phraseColor(id: string): string {
    if (this.scanningThis(id)) {
      return Theme.muted;
    }
    let run = this.visibleRun(id);
    if (run === undefined) {
      if (this.visibleFault(id) !== undefined) {
        return Theme.warn;
      }
      return Theme.muted;
    }
    if (run.verdict === 'hit') {
      return Theme.danger;
    }
    if (run.verdict === 'blocked') {
      return Theme.ok;
    }
    return Theme.accent;
  }

  private cardColor(id: string): string {
    if (this.scanningThis(id)) {
      return Theme.accent;
    }
    let run = this.visibleRun(id);
    if (run === undefined) {
      if (this.visibleFault(id) !== undefined) {
        return Theme.warn;
      }
      return Theme.line;
    }
    if (run.verdict === 'hit') {
      return Theme.danger;
    }
    if (run.verdict === 'blocked') {
      return Theme.ok;
    }
    if (run.verdict === 'passive') {
      return Theme.accent;
    }
    return Theme.line;
  }

  private runEvidences(id: string): ProbeEvidence[] {
    let run = this.visibleRun(id);
    if (run === undefined) {
      let empty: ProbeEvidence[] = [];
      return empty;
    }
    return run.evidences;
  }

  private scanningThis(id: string): boolean {
    return this.scanProgress.running && this.scanProgress.probeId === id;
  }

  private visibleRun(id: string): ProbeRun | undefined {
    let run = this.newestRun(id);
    if (run === undefined) {
      return undefined;
    }
    let fault = this.newestFault(id);
    if (fault !== undefined && fault.at >= run.createdAt) {
      return undefined;
    }
    return run;
  }

  private visibleFault(id: string): ProbeRunFault | undefined {
    let fault = this.newestFault(id);
    if (fault === undefined) {
      return undefined;
    }
    let run = this.newestRun(id);
    if (run !== undefined && run.createdAt > fault.at) {
      return undefined;
    }
    return fault;
  }

  private newestRun(id: string): ProbeRun | undefined {
    let runs = this.probeShelf.runs;
    for (let i = runs.length - 1; i >= 0; i--) {
      if (runs[i].probeId !== id) {
        continue;
      }
      if (acceptProbeRun(id, runs[i]).ok) {
        return runs[i];
      }
    }
    return undefined;
  }

  private newestFault(id: string): ProbeRunFault | undefined {
    let faults = this.probeShelf.runFaults;
    for (let i = 0; i < faults.length; i++) {
      if (faults[i].probeId === id && isStamp(faults[i].at) && faults[i].reason.length > 0) {
        return faults[i];
      }
    }
    return undefined;
  }
}

function pasteToken(result: PasteButtonOnClickResult): string {
  if (result === PasteButtonOnClickResult.SUCCESS) {
    return 'SUCCESS';
  }
  return 'TEMPORARY_AUTHORIZATION_FAILED';
}
