import { common } from '@kit.AbilityKit';
import { Theme } from '../common/Theme';
import { ChoiceRow, EventBlock, EventCard, GhostButton, PrimaryButton, RehearsalBanner, ThreatBlock } from '../components/UiParts';
import { Catalog, ThreatRow } from '../model/Catalog';
import { formatBundle } from '../model/D4Codec';
import { Choice, D4Event, filterEvents, hasRehearsal } from '../model/D4Types';
import { FileExchange } from '../model/FileExchange';
import { LiveStore } from '../model/LiveStore';

@Component
export struct EvidenceView {
  @StorageLink('liveEvents') liveEvents: D4Event[] = [];
  @State scenarioId: string = '';
  @State showSheet: boolean = false;
  @State sheetMode: string = 'event';
  @State detail: D4Event = new D4Event();
  @State confirmDelete: boolean = false;
  @State confirmClear: boolean = false;
  private filters: Choice[] = Catalog.scenarioFilters();

  build() {
    Scroll() {
      Column() {
        RehearsalBanner({ visible: hasRehearsal(this.liveEvents) })
        Text('左边是普通版记录，右边是安全版记录。卡片上只放短句，规则编号和条款号在点开之后。')
          .width('100%')
          .fontSize(14)
          .fontColor(Theme.muted)
          .lineHeight(20)
          .margin({ bottom: 12 })
        ChoiceRow({
          title: '场景',
          options: this.filters,
          value: this.scenarioId,
          onPick: (value: string) => {
            this.scenarioId = value;
          }
        })
        GridRow({ columns: 12, breakpoints: { value: ['320vp', '600vp', '840vp'] } }) {
          GridCol({ span: { sm: 12, md: 6, lg: 6 } }) {
            this.column('普通版', 'vanilla-demo', '这块板还没有记录')
          }
          GridCol({ span: { sm: 12, md: 6, lg: 6 } }) {
            this.column('安全版', 'secure', '这块板还没有记录')
          }
        }
        .width('100%')

        this.residualCard()

        Row() {
          Column() {
            GhostButton({
              label: '导入记录',
              onTap: () => {
                this.importFile();
              }
            })
          }
          .layoutWeight(1)
          .margin({ right: 8 })

          Column() {
            GhostButton({
              label: '导出现场',
              onTap: () => {
                this.exportFile();
              }
            })
          }
          .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 4, bottom: 8 })

        PrimaryButton({
          label: this.confirmClear ? '确认清空' : '清空现场与样例',
          onTap: () => {
            this.clearAll();
          }
        })
        GhostButton({
          label: '载入版式样例，覆盖当前记录',
          onTap: () => {
            this.loadSample();
          }
        })
        .margin({ top: 8 })
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
        this.confirmDelete = false;
      }
    })
  }

  @Builder
  column(title: string, role: string, emptyText: string) {
    Column() {
      Text(title)
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(role === 'secure' ? Theme.ok : Theme.danger)
        .margin({ bottom: 8 })
      if (filterEvents(this.liveEvents, role, this.scenarioId).length === 0) {
        Text(emptyText)
          .width('100%')
          .fontSize(14)
          .fontColor(Theme.muted)
          .padding(16)
          .borderRadius(12)
          .backgroundColor(Theme.card)
          .margin({ bottom: 10 })
      }
      ForEach(filterEvents(this.liveEvents, role, this.scenarioId), (item: D4Event) => {
        EventCard({
          event: item,
          onOpen: (eventId: string) => {
            this.openEvent(eventId);
          }
        })
      }, (item: D4Event) => item.eventId)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 4, right: 4 })
  }

  @Builder
  residualCard() {
    Column() {
      Text('残余 · 必须能单独打开')
        .width('100%')
        .fontSize(13)
        .fontColor(Theme.accent)
      Text(Catalog.residual().title)
        .width('100%')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.text)
        .margin({ top: 4 })
      Text('登记时点 ' + Catalog.residual().registeredAt + '  ·  ' + Catalog.residual().evidenceNo)
        .width('100%')
        .fontSize(13)
        .fontColor(Theme.muted)
        .margin({ top: 4 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .borderRadius(14)
    .backgroundColor(Theme.card)
    .border({ width: 1, color: Theme.accent })
    .margin({ top: 4, bottom: 12 })
    .onClick(() => {
      this.sheetMode = 'threat';
      this.showSheet = true;
    })
  }

  @Builder
  sheetBuilder() {
    Scroll() {
      Column() {
        if (this.sheetMode === 'threat') {
          ThreatBlock({ row: Catalog.residual() })
        } else {
          EventBlock({ event: this.detail })
          if (this.detail.threatId.length > 0) {
            Text('对应台账')
              .width('100%')
              .fontSize(16)
              .fontColor(Theme.accent)
              .margin({ top: 8, bottom: 8 })
            ThreatBlock({ row: this.linkedThreat() })
            if (this.ledgerDiffers()) {
              Text('现场记录里的台账状态和内置台账不一致，请核对。')
                .width('100%')
                .fontSize(13)
                .fontColor(Theme.warn)
                .margin({ bottom: 8 })
            }
          }
          PrimaryButton({
            label: this.confirmDelete ? '确认删除这条' : '删除这条',
            onTap: () => {
              this.deleteCurrent();
            }
          })
          .margin({ top: 8 })
        }
        GhostButton({
          label: '关闭',
          onTap: () => {
            this.showSheet = false;
          }
        })
        .margin({ top: 8 })
      }
      .width('100%')
      .padding(20)
    }
    .width('100%')
    .backgroundColor(Theme.card)
  }

  private openEvent(eventId: string): void {
    let found = this.findEvent(eventId);
    if (found === undefined) {
      return;
    }
    this.detail = found;
    this.sheetMode = 'event';
    this.confirmDelete = false;
    this.showSheet = true;
  }

  private findEvent(eventId: string): D4Event | undefined {
    for (let i = 0; i < this.liveEvents.length; i++) {
      if (this.liveEvents[i].eventId === eventId) {
        return this.liveEvents[i];
      }
    }
    return undefined;
  }

  private linkedThreat(): ThreatRow {
    let found = Catalog.findThreat(this.detail.threatId);
    if (found !== undefined) {
      return found;
    }
    let row = new ThreatRow();
    row.threatId = this.detail.threatId;
    row.title = '台账里没有这条';
    row.status = 'open';
    row.summary = '现场记录写了威胁编号，当前内置台账没有对应项。';
    return row;
  }

  private ledgerDiffers(): boolean {
    let found = Catalog.findThreat(this.detail.threatId);
    if (found === undefined) {
      return false;
    }
    return found.status !== this.detail.threatStatus;
  }

  private deleteCurrent(): void {
    if (!this.confirmDelete) {
      this.confirmDelete = true;
      LiveStore.setStatus('再点一次，确认删除这条记录');
      return;
    }
    this.confirmDelete = false;
    this.showSheet = false;
    LiveStore.deleteEvent(this.detail.eventId);
  }

  private clearAll(): void {
    if (!this.confirmClear) {
      this.confirmClear = true;
      return;
    }
    this.confirmClear = false;
    LiveStore.clearEvents();
  }

  private host(): common.UIAbilityContext | undefined {
    let value = this.getUIContext().getHostContext();
    if (value === undefined) {
      return undefined;
    }
    return value as common.UIAbilityContext;
  }

  private async importFile(): Promise<void> {
    let ctx = this.host();
    if (ctx === undefined) {
      LiveStore.setStatus('无法取得应用上下文');
      return;
    }
    let file = await FileExchange.pickText(ctx);
    if (!file.ok) {
      LiveStore.setStatus(file.message);
      return;
    }
    await LiveStore.importText(file.text, false);
  }

  private async exportFile(): Promise<void> {
    let ctx = this.host();
    if (ctx === undefined) {
      LiveStore.setStatus('无法取得应用上下文');
      return;
    }
    let saved = await FileExchange.saveText(ctx, 'jinyinhu-d4-events.json', formatBundle(this.liveEvents));
    LiveStore.setStatus(saved.message);
  }

  private async loadSample(): Promise<void> {
    let ctx = this.host();
    if (ctx === undefined) {
      LiveStore.setStatus('无法取得应用上下文');
      return;
    }
    let file = await FileExchange.readRaw(ctx, 'layout_sample.json');
    if (!file.ok) {
      LiveStore.setStatus(file.message);
      return;
    }
    this.confirmClear = false;
    await LiveStore.importText(file.text, true);
  }
}
