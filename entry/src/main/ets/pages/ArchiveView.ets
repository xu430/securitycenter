import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import deviceInfo from '@ohos.deviceInfo';
import { Theme } from '../common/Theme';
import { GhostButton, InfoLine, PrimaryButton, ThreatBlock } from '../components/UiParts';
import { Catalog, SbomRow, ThreatRow } from '../model/Catalog';
import { encodeProbeEvents, formatBundle, parseBundle, restoreArchive } from '../model/D4Codec';
import { D4Event } from '../model/D4Types';
import { FileExchange } from '../model/FileExchange';
import { LiveStore } from '../model/LiveStore';
import { ProbeShelf, emptyProbeShelf } from '../probe/ProbeTypes';
import { Registry } from '../probe/Registry';
import { Finding, Findings } from '../report/Findings';

const ARCHIVE_NAME: string = 'jinyinhu-d4-events.json';
const DOMAIN = 0x4A59;
const TAG = 'ArchiveView';

@Component
export struct ArchiveView {
  @StorageLink('probeShelf') probeShelf: ProbeShelf = emptyProbeShelf();
  @StorageLink('findings') findings: Finding[] = [];
  @State showSheet: boolean = false;
  @State threat: ThreatRow = Catalog.residual();
  @State notice: string = '';
  @State busy: boolean = false;
  @Prop section: string = 'records';
  private threats: ThreatRow[] = Catalog.threats();
  private components: SbomRow[] = Catalog.sbom('金银湖安全中心');

  build() {
    Scroll() {
      Column() {
        if (this.section !== 'about') {
        Text(this.notice.length > 0 ? this.notice : '导出的文件只包含已有结论的检测记录。')
          .width('100%')
          .fontSize(13)
          .fontColor(Theme.muted)
          .margin({ bottom: 12 })

        if (this.ledgerRows().length === 0) {
          Text('暂无检测记录')
            .width('100%')
            .fontSize(14)
            .fontColor(Theme.muted)
            .padding(14)
            .borderRadius(16)
            .backgroundColor(Theme.card)
            .margin({ bottom: 8 })
        }
        ForEach(this.ledgerRows(), (row: Finding) => {
          Column() {
            Text(row.title)
              .width('100%')
              .fontSize(16)
              .fontColor(Theme.text)
            Text(this.ledgerStatus(row))
              .width('100%')
              .fontSize(13)
              .fontColor(Theme.accent)
              .margin({ top: 4 })
            if (row.status === 'fixed-by-patch') {
              Text(row.registeredAt)
                .width('100%')
                .fontSize(12)
                .fontColor(Theme.muted)
                .margin({ top: 4 })
              Text(row.evidenceNo)
                .width('100%')
                .fontSize(12)
                .fontColor(Theme.muted)
                .margin({ top: 2 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .borderRadius(16)
          .backgroundColor(Theme.card)
          .margin({ bottom: 8 })
        }, (row: Finding) => row.findingId + row.status + row.evidenceNo)

        if (this.ledgerRows().length > 0 && this.exportable().length === 0) {
          Text('暂无检测记录')
            .width('100%')
            .fontSize(14)
            .fontColor(Theme.muted)
            .margin({ bottom: 8 })
        }
        ForEach(this.exportable(), (item: D4Event) => {
          Text(item.scenarioId + '  ·  ' + item.phrase + '  ·  ' + this.fileStatus(item.threatStatus))
            .width('100%')
            .fontSize(14)
            .fontColor(Theme.text)
            .margin({ bottom: 6 })
        }, (item: D4Event) => item.eventId)

        PrimaryButton({
          label: this.busy ? '正在处理' : '导出检测记录',
          canTap: !this.busy,
          onTap: () => {
            this.exportArchive();
          }
        })
          .margin({ top: 8, bottom: 8 })
        GhostButton({
          label: '导入检测记录',
          onTap: () => {
            this.importArchive();
          }
        })
          .margin({ bottom: 8 })
        GhostButton({
          label: '导入检测报告',
          onTap: () => {
            this.importSidecar();
          }
        })
          .margin({ bottom: 16 })

        }

        if (this.section === 'about') {
        Text('边界声明')
          .width('100%')
          .fontSize(16)
          .fontColor(Theme.accent)
          .margin({ bottom: 8 })
        Text(Catalog.boundary)
          .width('100%')
          .fontSize(16)
          .fontColor(Theme.text)
          .lineHeight(24)
          .padding(14)
          .borderRadius(16)
          .backgroundColor(Theme.card)
          .border({ width: 1, color: Theme.accent })
          .margin({ bottom: 16 })

        Text('威胁清单')
          .width('100%')
          .fontSize(16)
          .fontColor(Theme.accent)
          .margin({ bottom: 8 })
        Text('待处理项还没有登记成已缓解。残余项带登记时点和依据编号，登记日是计划修订日。')
          .width('100%')
          .fontSize(13)
          .fontColor(Theme.muted)
          .margin({ bottom: 8 })
        ForEach(this.threats, (item: ThreatRow) => {
          Column() {
            Text(item.threatId + '  ·  ' + item.title)
              .width('100%')
              .fontSize(16)
              .fontColor(Theme.text)
            Text(item.status === 'residual' ? '残余 · 点开查看' : '待处理 · 点开查看')
              .width('100%')
              .fontSize(13)
              .fontColor(Theme.accent)
              .margin({ top: 4 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .borderRadius(16)
          .backgroundColor(Theme.card)
          .margin({ bottom: 8 })
          .onClick(() => {
            this.threat = item;
            this.showSheet = true;
          })
        }, (item: ThreatRow) => item.threatId)

        Text('组件清单')
          .width('100%')
          .fontSize(16)
          .fontColor(Theme.accent)
          .margin({ top: 8, bottom: 8 })
        ForEach(this.components, (item: SbomRow) => {
          Column() {
            Text(item.name)
              .width('100%')
              .fontSize(16)
              .fontColor(Theme.text)
            InfoLine({ label: '版本', value: item.version })
            InfoLine({ label: '许可证', value: item.license })
            InfoLine({ label: '范围', value: item.scope })
            Text(item.note)
              .width('100%')
              .fontSize(13)
              .fontColor(Theme.muted)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .borderRadius(16)
          .backgroundColor(Theme.card)
          .margin({ bottom: 8 })
        }, (item: SbomRow) => item.name)

        }
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
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

  private ledgerRows(): Finding[] {
    let ignored = this.findings.length;
    if (ignored < 0) {
      return [];
    }
    return Findings.list();
  }

  private exportable(): D4Event[] {
    let ignored = this.probeShelf.runs.length + this.findings.length;
    if (ignored < 0) {
      return [];
    }
    return encodeProbeEvents(Findings.list(), this.probeShelf.runs, this.probeShelf.boardUdid, this.readImageVersion());
  }

  private ledgerStatus(row: Finding): string {
    if (row.scenarioId === 'C1') {
      return '持续关注，不写入导出文件';
    }
    if (row.status === 'fixed-by-patch') {
      return '已由补丁修复';
    }
    if (row.status === 'open') {
      return '待处理';
    }
    return row.status;
  }

  private fileStatus(status: string): string {
    if (status === 'mitigated') {
      return '已缓解';
    }
    if (status === 'residual') {
      return '残余';
    }
    return '待处理';
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

  private exportArchive(): void {
    if (this.busy) {
      return;
    }
    let events = this.exportable();
    if (events.length === 0) {
      this.notice = '演示前无事件';
      LiveStore.setStatus(this.notice);
      return;
    }
    let ctx = this.host();
    if (ctx === undefined) {
      this.notice = '无法取得应用上下文';
      LiveStore.setStatus(this.notice);
      return;
    }
    this.busy = true;
    FileExchange.saveText(ctx, ARCHIVE_NAME, formatBundle(events)).then((saved) => {
      this.notice = saved.message;
      LiveStore.setStatus(saved.message);
      this.busy = false;
    }).catch((err: Object) => {
      hilog.error(DOMAIN, TAG, 'save %{public}s', JSON.stringify(err));
      this.notice = '保存失败';
      LiveStore.setStatus(this.notice);
      this.busy = false;
    });
  }

  private importArchive(): void {
    if (this.busy) {
      return;
    }
    let ctx = this.host();
    if (ctx === undefined) {
      this.notice = '无法取得应用上下文';
      LiveStore.setStatus(this.notice);
      return;
    }
    this.busy = true;
    FileExchange.pickText(ctx).then((picked) => {
      if (!picked.ok) {
        this.notice = picked.message;
        LiveStore.setStatus(picked.message);
        this.busy = false;
        return;
      }
      let parsed = parseBundle(picked.text);
      if (!parsed.ok || parsed.skipped > 0 || parsed.events.length === 0) {
        this.notice = parsed.message.length > 0 ? parsed.message : '文件无法通过校验';
        LiveStore.setStatus(this.notice);
        this.busy = false;
        return;
      }
      let restored = restoreArchive(parsed.events);
      if (!restored.ok) {
        this.notice = restored.message.length > 0 ? restored.message : '文件无法通过校验';
        LiveStore.setStatus(this.notice);
        this.busy = false;
        return;
      }
      try {
        LiveStore.replaceLedger(restored.findings, restored.runs);
        this.notice = restored.message;
        LiveStore.setStatus(this.notice);
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'restore %{public}s', JSON.stringify(err));
        this.notice = '记录没有写回';
        LiveStore.setStatus(this.notice);
      }
      this.busy = false;
    }).catch((err: Object) => {
      hilog.error(DOMAIN, TAG, 'import %{public}s', JSON.stringify(err));
      this.notice = '读取文件失败';
      LiveStore.setStatus(this.notice);
      this.busy = false;
    });
  }

  private importSidecar(): void {
    if (this.busy) {
      return;
    }
    let ctx = this.host();
    if (ctx === undefined) {
      this.notice = '无法取得应用上下文';
      LiveStore.setStatus(this.notice);
      return;
    }
    this.busy = true;
    FileExchange.pickSidecar(ctx).then((picked) => {
      if (!picked.ok) {
        this.notice = picked.message;
        LiveStore.setStatus(picked.message);
        this.busy = false;
        return;
      }
      let report = Registry.ingestSidecar(picked.text);
      if (report === undefined) {
        let reason = LiveStore.shelf().failureReason;
        this.notice = reason.length > 0 ? reason : '导入失败';
        this.busy = false;
        return;
      }
      this.notice = '检测报告已导入';
      this.busy = false;
    }).catch((err: Object) => {
      hilog.error(DOMAIN, TAG, 'sidecar %{public}s', JSON.stringify(err));
      this.notice = '检测报告读取失败';
      LiveStore.setStatus(this.notice);
      this.busy = false;
    });
  }

  private host(): common.UIAbilityContext | undefined {
    let value = this.getUIContext().getHostContext();
    if (value === undefined) {
      return undefined;
    }
    return value as common.UIAbilityContext;
  }

  @Builder
  sheetBuilder() {
    Scroll() {
      Column() {
        ThreatBlock({ row: this.threat })
      }
      .width('100%')
      .padding(20)
    }
    .backgroundColor(Theme.card)
  }
}
