import { hilog } from '@kit.PerformanceAnalysisKit';
import { Theme } from '../common/Theme';
import { Choice, D4Event, outcomeLabel, outcomeTone, roleLabel, scenarioLabel, sourceLabel, statusLabel } from '../model/D4Types';
import { ThreatRow } from '../model/Catalog';
import { ProbeLimits, ProbeRun, isImageRole, isProbeId, isProofLevel, isStamp, isTightLine, isVerdict } from '../probe/ProbeTypes';

const DOMAIN = 0x4A59;

@Component
export struct BrandBar {
  @Prop title: string = '';
  @Prop subtitle: string = '';

  build() {
    Column() {
      Row() {
        Stack() {
          Text('湖')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.onAccent)
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor(Theme.accent)
        .margin({ right: 12 })

        Column() {
          Text(this.title)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.text)
          Text(this.subtitle)
            .fontSize(13)
            .fontColor(Theme.accent)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      Divider().color(Theme.accent).strokeWidth(2)
    }
    .width('100%')
    .backgroundColor(Theme.page)
  }
}

@Component
export struct TabBar {
  @Prop tabs: string[] = [];
  @Prop index: number = 0;
  onPick: (index: number) => void = (index: number) => {
    hilog.info(DOMAIN, 'tab', '%{public}d', index);
  };

  build() {
    Row() {
      ForEach(this.tabs, (name: string, tabIndex: number) => {
        Text(name)
          .fontSize(14)
          .fontWeight(this.index === tabIndex ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.index === tabIndex ? Theme.onAccent : Theme.text)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .layoutWeight(1)
          .height(40)
          .padding({ left: 2, right: 2 })
          .borderRadius(10)
          .backgroundColor(this.index === tabIndex ? Theme.accent : Theme.cardAlt)
          .onClick(() => {
            this.onPick(tabIndex);
          })
      }, (name: string) => name)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 6 })
  }
}

@Component
export struct StatusLine {
  @Prop text: string = '';

  build() {
    Text(this.text)
      .width('100%')
      .fontSize(13)
      .fontColor(Theme.muted)
      .maxLines(2)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({ left: 16, right: 16, top: 6, bottom: 2 })
      .visibility(this.text.length > 0 ? Visibility.Visible : Visibility.None)
  }
}

@Component
export struct RehearsalBanner {
  @Prop visible: boolean = false;

  build() {
    Text('含版式样例。正式演示前请清空，避免时间戳穿帮。')
      .width('100%')
      .fontSize(14)
      .fontColor(Theme.onWarn)
      .backgroundColor(Theme.warn)
      .borderRadius(10)
      .padding(12)
      .margin({ bottom: 12 })
      .visibility(this.visible ? Visibility.Visible : Visibility.None)
  }
}

@Component
export struct ChoiceRow {
  @Prop title: string = '';
  @Prop options: Choice[] = [];
  @Prop value: string = '';
  onPick: (value: string) => void = (value: string) => {
    hilog.info(DOMAIN, 'choice', '%{public}s', value);
  };

  build() {
    Column() {
      Text(this.title)
        .width('100%')
        .fontSize(13)
        .fontColor(Theme.muted)
        .margin({ bottom: 8 })
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.options, (item: Choice) => {
          Text(item.label)
            .fontSize(14)
            .fontColor(this.value === item.value ? Theme.onAccent : Theme.text)
            .backgroundColor(this.value === item.value ? Theme.accent : Theme.cardAlt)
            .borderRadius(16)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.onPick(item.value);
            })
        }, (item: Choice) => item.value + item.label)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 12 })
  }
}

@Component
export struct FieldBox {
  @Prop title: string = '';
  @Prop text: string = '';
  @Prop placeholder: string = '';
  @Prop maxLength: number = 64;
  onEdit: (value: string) => void = (value: string) => {
    hilog.info(DOMAIN, 'field', '%{public}d', value.length);
  };

  build() {
    Column() {
      Text(this.title)
        .width('100%')
        .fontSize(13)
        .fontColor(Theme.muted)
        .margin({ bottom: 6 })
      TextInput({ text: this.text, placeholder: this.placeholder })
        .width('100%')
        .height(44)
        .maxLength(this.maxLength)
        .fontSize(16)
        .fontColor(Theme.text)
        .placeholderColor(Theme.muted)
        .backgroundColor(Theme.page)
        .borderRadius(10)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.onEdit(value);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 12 })
  }
}

@Component
export struct PrimaryButton {
  @Prop label: string = '';
  @Prop canTap: boolean = true;
  onTap: () => void = () => {
    hilog.info(DOMAIN, 'button', 'tap');
  };

  build() {
    Button(this.label)
      .type(ButtonType.Capsule)
      .enabled(this.canTap)
      .width('100%')
      .height(40)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor(Theme.onAccent)
      .backgroundColor(Theme.accent)
      .opacity(this.canTap ? 1 : 0.4)
      .margin({ top: 8 })
      .onClick(() => {
        this.onTap();
      })
  }
}

@Component
export struct QuietStage {
  @Prop headline: string = '';
  @Prop detail: string = '';

  build() {
    Column() {
      SymbolGlyph($r('sys.symbol.doc_text_fill'))
        .fontSize(48)
        .fontColor([Theme.line])
      Text(this.headline)
        .width('100%')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.text)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .margin({ top: 12 })
      if (this.detail.length > 0) {
        Text(this.detail)
          .width('100%')
          .fontSize(14)
          .fontColor(Theme.muted)
          .textAlign(TextAlign.Center)
          .lineHeight(20)
          .margin({ top: 6 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 24, right: 24, top: 32, bottom: 32 })
    .borderRadius(16)
    .backgroundColor(Theme.card)
  }
}

@Component
export struct BusyStage {
  @Prop title: string = '';
  @Prop detail: string = '';

  build() {
    Row() {
      LoadingProgress()
        .width(32)
        .height(32)
        .color(Theme.accent)
      Column() {
        Text('正在检测 ' + this.title)
          .width('100%')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.detail.length > 0) {
          Text(this.detail)
            .width('100%')
            .fontSize(13)
            .fontColor(Theme.muted)
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(16)
    .borderRadius(16)
    .backgroundColor(Theme.card)
  }
}

@Component
export struct GhostButton {
  @Prop label: string = '';
  onTap: () => void = () => {
    hilog.info(DOMAIN, 'ghost', 'tap');
  };

  build() {
    Button(this.label)
      .type(ButtonType.Capsule)
      .width('100%')
      .height(40)
      .fontSize(15)
      .fontColor(Theme.accent)
      .backgroundColor(Theme.accentSoft)
      .margin({ top: 8 })
      .onClick(() => {
        this.onTap();
      })
  }
}

@Component
export struct InfoLine {
  @Prop label: string = '';
  @Prop value: string = '';

  build() {
    Column() {
      Text(this.label)
        .width('100%')
        .fontSize(12)
        .fontColor(Theme.muted)
      Text(this.value.length === 0 ? '—' : this.value)
        .width('100%')
        .fontSize(16)
        .fontColor(Theme.text)
        .margin({ top: 2 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 10 })
  }
}

@Component
export struct EvidenceSheet {
  @Prop kind: string = '';
  @Prop text: string = '';
  @Prop raw: string = '';
  @Prop at: string = '';

  build() {
    Column() {
      Text(this.kind)
        .width('100%')
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.text)
      if (this.at.length > 0) {
        Text('时间')
          .width('100%')
          .fontSize(12)
          .fontColor(Theme.muted)
          .margin({ top: 16 })
        Text(this.at)
          .width('100%')
          .fontSize(15)
          .fontColor(Theme.text)
          .margin({ top: 4 })
      }
      if (this.text.length > 0) {
        Text('说明')
          .width('100%')
          .fontSize(12)
          .fontColor(Theme.muted)
          .margin({ top: 16 })
        Text(this.text)
          .width('100%')
          .fontSize(16)
          .fontColor(Theme.text)
          .margin({ top: 4 })
      }
      if (this.kind === '源码行号' && this.raw.length > 0) {
        Text('源码行号')
          .width('100%')
          .fontSize(12)
          .fontColor(Theme.accent)
          .margin({ top: 16 })
        Text(this.raw)
          .width('100%')
          .fontSize(20)
          .fontColor(Theme.accent)
          .margin({ top: 4 })
      } else if (this.raw.length > 0) {
        Text('原文')
          .width('100%')
          .fontSize(12)
          .fontColor(Theme.muted)
          .margin({ top: 16 })
        Text(this.raw)
          .width('100%')
          .fontSize(13)
          .fontFamily('monospace')
          .fontColor(Theme.muted)
          .margin({ top: 4 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

@Component
export struct EventCard {
  @Prop event: D4Event = new D4Event();
  onOpen: (eventId: string) => void = (eventId: string) => {
    hilog.info(DOMAIN, 'event', '%{public}s', eventId);
  };

  build() {
    Column() {
      Row() {
        Text(outcomeLabel(this.event.outcome))
          .fontSize(12)
          .fontColor(outcomeTone(this.event.outcome) === 'danger' ? '#3A1212' : outcomeTone(this.event.outcome) === 'ok' ? '#06281A' : Theme.onAccent)
          .backgroundColor(outcomeTone(this.event.outcome) === 'danger' ? Theme.danger : outcomeTone(this.event.outcome) === 'ok' ? Theme.ok : Theme.accent)
          .borderRadius(10)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        Text(sourceLabel(this.event.source))
          .fontSize(12)
          .fontColor(Theme.accent)
          .borderRadius(10)
          .border({ width: 1, color: Theme.accent })
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .margin({ left: 8 })
        Text(this.event.scenarioId)
          .fontSize(12)
          .fontColor(Theme.muted)
          .margin({ left: 8 })
      }
      .width('100%')

      Text(this.event.phrase.length === 0 ? '（没有短语）' : this.event.phrase)
        .width('100%')
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.text)
        .margin({ top: 10 })

      Text(this.event.occurredAt + '  ·  ' + this.event.deviceId + '  ·  #' + this.event.seq.toString())
        .width('100%')
        .fontSize(12)
        .fontColor(Theme.muted)
        .margin({ top: 6 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .borderRadius(14)
    .backgroundColor(Theme.cardAlt)
    .borderWidth({ left: 4, top: 1, right: 1, bottom: 1 })
    .borderColor(outcomeTone(this.event.outcome) === 'danger' ? Theme.danger : outcomeTone(this.event.outcome) === 'ok' ? Theme.ok : Theme.accent)
    .margin({ bottom: 10 })
    .onClick(() => {
      this.onOpen(this.event.eventId);
    })
  }
}

@Component
export struct ScoreRing {
  @Prop done: number = 0;
  @Prop total: number = 6;
  @Prop caption: string = '闭环';

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Progress({
        value: this.total > 0 && this.done > this.total ? this.total : (this.done < 0 ? 0 : this.done),
        total: this.total > 0 ? this.total : 1,
        type: ProgressType.Ring
      })
        .width(128)
        .height(128)
        .style({ strokeWidth: 10 })
        .color(Theme.accent)
      Column() {
        Text(this.done.toString() + '/' + this.total.toString())
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.text)
        Text(this.caption)
          .fontSize(12)
          .fontColor(Theme.muted)
      }
    }
    .width(128)
    .height(128)
  }
}

@Component
export struct ThreatBlock {
  @Prop row: ThreatRow = new ThreatRow();

  build() {
    Column() {
      Text(this.row.threatId + '  ·  ' + statusLabel(this.row.status))
        .width('100%')
        .fontSize(13)
        .fontColor(Theme.accent)
      Text(this.row.title)
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.text)
        .margin({ top: 4 })
      InfoLine({ label: '登记时点', value: this.row.registeredAt.length === 0 ? '尚未登记，不能视为已缓解' : this.row.registeredAt })
      InfoLine({ label: '依据编号', value: this.row.evidenceNo })
      InfoLine({ label: '依据', value: this.row.basis })
      Text(this.row.summary)
        .width('100%')
        .fontSize(15)
        .fontColor(Theme.text)
        .lineHeight(22)
      if (this.row.status === 'mitigated') {
        Text('已缓解来自台账登记，不是某次拦截当场生成的。')
          .width('100%')
          .fontSize(13)
          .fontColor(Theme.warn)
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

@Component
export struct EventBlock {
  @Prop event: D4Event = new D4Event();

  build() {
    Column() {
      Text(this.event.phrase.length === 0 ? outcomeLabel(this.event.outcome) : this.event.phrase)
        .width('100%')
        .fontSize(24)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.text)
      Text(scenarioLabel(this.event.scenarioId) + '  ·  ' + roleLabel(this.event.imageRole))
        .width('100%')
        .fontSize(14)
        .fontColor(Theme.accent)
        .margin({ top: 4, bottom: 8 })
      InfoLine({ label: '现场结果', value: outcomeLabel(this.event.outcome) })
      InfoLine({ label: '时间', value: this.event.occurredAt })
      InfoLine({ label: '设备', value: this.event.deviceId })
      InfoLine({ label: '序号', value: this.event.seq.toString() })
      InfoLine({ label: '镜像', value: this.event.imageVersion + '  ·  尾号 ' + (this.event.imageHashTail.length === 0 ? '未填' : this.event.imageHashTail) })
      InfoLine({ label: '来源', value: sourceLabel(this.event.source) })
      InfoLine({ label: '记录方', value: this.event.appId })
      InfoLine({ label: '规则编号', value: this.event.ruleId })
      InfoLine({ label: '条款号', value: this.event.baselineClause.length === 0 ? '尚未填写' : this.event.baselineClause })
      InfoLine({ label: '威胁编号', value: this.event.threatId })
      InfoLine({ label: '台账状态', value: statusLabel(this.event.threatStatus) })
      InfoLine({
        label: '登记时点',
        value: this.event.registeredAt.length === 0 ? '尚未登记，不能视为已缓解' : this.event.registeredAt
      })
      InfoLine({ label: '依据编号', value: this.event.evidenceNo })
      if (this.event.detail.length > 0) {
        Text(this.event.detail)
          .width('100%')
          .fontSize(15)
          .fontColor(Theme.text)
          .lineHeight(22)
          .margin({ bottom: 8 })
      }
      if (this.event.threatStatus === 'mitigated') {
        Text('已缓解来自台账登记，不是这次拦截当场生成的。')
          .width('100%')
          .fontSize(13)
          .fontColor(Theme.warn)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

@Component
export struct BoardPane {
  @Prop role: string = 'secure';
  @Prop version: string = '';
  @Prop hashTail: string = '';
  @Prop focused: boolean = true;
  @Prop face: string = 'identity';
  @Prop phrase: string = '';
  @Prop timeText: string = '';
  @Prop outcome: string = '';
  @Prop phraseInk: string = '';
  @Prop demoMark: boolean = false;
  onOpen: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        if (!(this.face === 'result' && this.outcome === 'pending')) {
          Text(this.role === 'vanilla-demo' ? '普通版' : '安全版')
            .fontSize(16)
            .fontColor(this.role === 'vanilla-demo' ? Theme.danger : Theme.ok)
          Column()
            .width(28)
            .height(2)
            .backgroundColor(this.role === 'vanilla-demo' ? Theme.danger : Theme.ok)
            .margin({ top: 6, bottom: 16 })
        }
        if (this.face !== 'result') {
          this.identityBody()
          this.slotRow()
        }
        if (this.face !== 'identity') {
          this.resultBody()
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: 16, right: 16, top: 20, bottom: 20 })

      if (this.role === 'vanilla-demo') {
        Text('对照镜像 · 非交付物')
          .width(280)
          .textAlign(TextAlign.Center)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.danger)
          .opacity(0.32)
          .rotate({ angle: -24 })
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .backgroundColor(Theme.card)
    .borderWidth({ left: 8 })
    .borderColor(this.barColor())
    .opacity(this.focused ? 1 : 0.4)
  }

  @Builder
  identityBody() {
    Column() {
      if (this.hashTail.length === 4) {
        Text(this.version.length === 0 ? '7.0.0.40' : this.version)
          .width('100%')
          .fontSize(18)
          .fontColor(Theme.muted)
          .textAlign(TextAlign.Center)
          .maxLines(1)
        Text(this.hashTail.toUpperCase())
          .width('100%')
          .fontSize(Theme.hashSize)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.accent)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .margin({ top: 4 })
      } else {
        Text(this.version.length === 0 ? '7.0.0.40' : this.version)
          .width('100%')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.accent)
          .textAlign(TextAlign.Center)
          .maxLines(2)
        Text('尾号待填写')
          .width('100%')
          .fontSize(14)
          .fontColor(Theme.muted)
          .textAlign(TextAlign.Center)
          .margin({ top: 6 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  resultBody() {
    Column() {
      if (this.demoMark) {
        Text('演示稿')
          .fontSize(12)
          .fontColor(Theme.accent)
          .border({ width: 1, color: Theme.accent })
          .borderRadius(10)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .margin({ bottom: 10 })
      }
      Text(this.phrase.length === 0 ? '等待这一下' : this.phrase)
        .width('100%')
        .fontSize(this.face === 'both' ? 32 : Theme.phraseSize)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.phraseInk.length > 0 ? this.phraseInk : Theme.text)
        .textAlign(TextAlign.Center)
        .maxLines(3)
        .lineHeight(44)
      if (this.phrase.length > 0 && (this.outcome === 'succeeded' || this.outcome === 'down')) {
        this.redactBars()
      }
      if (this.timeText.length > 0) {
        Text(this.timeText)
          .width('100%')
          .fontSize(15)
          .fontColor(Theme.muted)
          .textAlign(TextAlign.Center)
          .margin({ top: 12 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ top: this.face === 'both' ? 18 : 0 })
    .onClick(() => {
      if (this.phrase.length > 0) {
        this.onOpen();
      }
    })
  }

  @Builder
  redactBars() {
    Column() {
      Column().width('78%').height(10).borderRadius(5).backgroundColor(Theme.danger).opacity(0.9)
      Column().width('62%').height(10).borderRadius(5).backgroundColor(Theme.danger).opacity(0.75).margin({ top: 8 })
      Column().width('46%').height(10).borderRadius(5).backgroundColor(Theme.danger).opacity(0.6).margin({ top: 8 })
    }
    .width('86%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 14 })
  }

  @Builder
  slotRow() {
    Row() {
      this.oneSlot('安', '安全中心')
      this.oneSlot('对', '对照台')
      this.oneSlot('场', '场景应用')
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
    .margin({ top: 18 })
  }

  @Builder
  oneSlot(mark: string, name: string) {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Text(mark)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.onAccent)
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .backgroundColor(Theme.accent)

      Text(name)
        .fontSize(12)
        .fontColor(Theme.text)
        .maxLines(1)
        .margin({ top: 6 })
    }
    .width(76)
    .alignItems(HorizontalAlign.Center)
  }

  barColor(): string {
    if (this.outcome === 'pending') {
      return Theme.line;
    }
    if (this.outcome === 'succeeded' || this.outcome === 'down') {
      return Theme.danger;
    }
    if (this.outcome === 'blocked' || this.outcome === 'alive') {
      return Theme.ok;
    }
    if (this.role === 'vanilla-demo') {
      return Theme.danger;
    }
    return Theme.ok;
  }
}

@Component
export struct HitButton {
  onTap: () => void = () => {};

  build() {
    Button('按下这一下')
      .type(ButtonType.Normal)
      .width('72%')
      .height(Theme.hitHeight)
      .fontSize(22)
      .fontWeight(FontWeight.Medium)
      .fontColor(Theme.onAccent)
      .backgroundColor(Theme.accent)
      .borderRadius(16)
      .onClick(() => {
        this.onTap();
      })
  }
}

@Component
export struct ShowDock {
  @Prop toggleText: string = '暂停';
  @Prop remainText: string = '';
  onPrep: () => void = () => {};
  onToggle: () => void = () => {};
  onNext: () => void = () => {};

  build() {
    Row() {
      Text('准备')
        .fontSize(16)
        .fontColor(Theme.accent)
        .padding({ left: 4, right: 12, top: 10, bottom: 10 })
        .onClick(() => {
          this.onPrep();
        })
      Blank()
      Text(this.remainText)
        .fontSize(14)
        .fontColor(Theme.muted)
        .margin({ right: 12 })
      Text(this.toggleText)
        .fontSize(16)
        .fontColor(Theme.accent)
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .onClick(() => {
          this.onToggle();
        })
      Button('下一步')
        .type(ButtonType.Normal)
        .height(44)
        .width(112)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.onAccent)
        .backgroundColor(Theme.accent)
        .borderRadius(12)
        .margin({ left: 8 })
        .onClick(() => {
          this.onNext();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 14 })
    .alignItems(VerticalAlign.Center)
  }
}

@Component
export struct SampleHero {
  @Prop title: string = '';
  @Prop expect: string = '';
  @Prop note: string = '';
  @Prop index: number = 0;
  @Prop total: number = 6;

  build() {
    Column() {
      Text('第 ' + (this.index + 1).toString() + ' 张  ·  共 ' + this.total.toString() + ' 张')
        .fontSize(16)
        .fontColor(Theme.accent)
      Text(this.title)
        .fontSize(Theme.phraseSize)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.text)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .margin({ top: 18 })
      Text(this.expect)
        .fontSize(20)
        .fontColor(Theme.text)
        .textAlign(TextAlign.Center)
        .margin({ top: 14 })
      Text(this.note)
        .fontSize(14)
        .fontColor(Theme.muted)
        .textAlign(TextAlign.Center)
        .margin({ top: 8 })
      Row({ space: 10 }) {
        ForEach(this.marks(), (item: number) => {
          Text(item === this.index ? '●' : '○')
            .fontSize(16)
            .fontColor(item === this.index ? Theme.accent : Theme.muted)
        }, (item: number) => item.toString())
      }
      .margin({ top: 28 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Theme.card)
    .padding(24)
  }

  marks(): number[] {
    let rows: number[] = [];
    for (let i = 0; i < this.total; i++) {
      rows.push(i);
    }
    return rows;
  }
}

@Observed
export class FindingCardRecord {
  findingId: string = '';
  scenarioId: string = '';
  title: string = '';
  status: string = '';
  registeredAt: string = '';
  evidenceNo: string = '';
}

@Component
export struct FindingCard {
  @Prop record: FindingCardRecord = new FindingCardRecord();

  build() {
    Column() {
      Row() {
        Text(findingStatusText(this.record))
          .fontSize(12)
          .fontColor(Theme.onAccent)
          .backgroundColor(findingBarColor(this.record))
          .borderRadius(10)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        if (knownScenario(this.record.scenarioId)) {
          Text(this.record.scenarioId)
            .fontSize(12)
            .fontColor(Theme.muted)
            .margin({ left: 8 })
        }
      }
      .width('100%')

      if (knownFindingId(this.record.findingId)) {
        Text(this.record.findingId)
          .width('100%')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.text)
          .maxLines(1)
          .margin({ top: 10 })
      }

      if (knownTitle(this.record.title)) {
        Text(this.record.title)
          .width('100%')
          .fontSize(16)
          .fontColor(Theme.text)
          .maxLines(1)
          .margin({ top: 4 })
      }

      Text('登记时点')
        .width('100%')
        .fontSize(12)
        .fontColor(Theme.muted)
        .margin({ top: 8 })
      Text(registeredAtText(this.record.registeredAt))
        .width('100%')
        .fontSize(15)
        .fontColor(isStamp(this.record.registeredAt) ? Theme.text : Theme.warn)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 2 })

      if (this.record.status === 'fixed-by-patch' || evidenceReady(this.record.evidenceNo)) {
        Text('依据编号')
          .width('100%')
          .fontSize(12)
          .fontColor(Theme.muted)
          .margin({ top: 8 })
        Text(evidenceReady(this.record.evidenceNo) ? this.record.evidenceNo : '尚未编号')
          .width('100%')
          .fontSize(15)
          .fontColor(evidenceReady(this.record.evidenceNo) ? Theme.text : Theme.warn)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(16)
    .backgroundColor(Theme.card)
    .margin({ bottom: 10 })
  }
}

@Component
export struct ProbeBadge {
  @Prop run: ProbeRun = new ProbeRun();

  build() {
    Row() {
      if (recordedRun(this.run)) {
        Text(this.run.probeId)
          .fontSize(12)
          .fontColor(Theme.onAccent)
          .backgroundColor(Theme.accent)
          .borderRadius(10)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        Text(this.run.level)
          .fontSize(12)
          .fontColor(Theme.onAccent)
          .backgroundColor(Theme.accent)
          .borderRadius(10)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .margin({ left: 8 })
      } else {
        Text('尚未检测')
          .fontSize(12)
          .fontColor(Theme.muted)
          .backgroundColor(Theme.card)
          .borderRadius(10)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      }
    }
  }
}

@Component
export struct SocL3Exhibit {
  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Text('终端分布 / 攻击面示意')
          .width('100%')
          .fontSize(16)
          .fontColor(Theme.text)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 14, right: 64, top: 14, bottom: 14 })
      DemoBadge()
        .margin({ top: 10, right: 10 })
    }
    .width('100%')
    .borderRadius(14)
    .backgroundColor(Theme.card)
    .border({ width: 1, color: Theme.line })
  }
}

@Component
export struct DemoBadge {
  build() {
    Text('展示')
      .fontSize(12)
      .fontColor(Theme.onWarn)
      .backgroundColor(Theme.warn)
      .borderRadius(10)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
  }
}

function findingBarColor(record: FindingCardRecord): string {
  if (record.scenarioId === 'C1') {
    return Theme.accent;
  }
  if (record.status === 'fixed-by-patch' && findingClosed(record)) {
    return Theme.ok;
  }
  if (record.status === 'fixed-by-patch') {
    return Theme.warn;
  }
  if (record.status === 'open') {
    return Theme.danger;
  }
  return Theme.line;
}

function findingStatusText(record: FindingCardRecord): string {
  if (record.scenarioId === 'C1') {
    return '持续关注';
  }
  if (record.status === 'fixed-by-patch' && findingClosed(record)) {
    return '已由补丁修复';
  }
  if (record.status === 'fixed-by-patch') {
    return '登记不完整';
  }
  if (record.status === 'open') {
    return '待处理';
  }
  return '尚未检测';
}

function findingClosed(record: FindingCardRecord): boolean {
  return isStamp(record.registeredAt) && evidenceReady(record.evidenceNo);
}

function knownScenario(scenarioId: string): boolean {
  return scenarioId === 'A1' || scenarioId === 'B1' || scenarioId === 'C1';
}

function knownTitle(title: string): boolean {
  return title === '安装信任链' || title === '沙箱隔离' || title === '安全组件姿态';
}

function knownFindingId(findingId: string): boolean {
  if (findingId.indexOf('FND-A1') !== 0 && findingId.indexOf('FND-B1') !== 0 && findingId.indexOf('FND-C1') !== 0) {
    return false;
  }
  let rest = findingId.substring(6);
  if (rest.length === 0) {
    return true;
  }
  for (let i = 0; i < rest.length; i++) {
    let code = rest.charCodeAt(i);
    if (code < 48 || code > 57) {
      return false;
    }
  }
  return true;
}

function recordedRun(run: ProbeRun): boolean {
  if (!isProbeId(run.probeId) || !isVerdict(run.verdict) || !isProofLevel(run.level)) {
    return false;
  }
  if (run.imageRole !== '' && !isImageRole(run.imageRole)) {
    return false;
  }
  if ((run.verdict === 'hit' || run.verdict === 'blocked') && run.level === 'L3') {
    return false;
  }
  if (!isTightLine(run.phrase, ProbeLimits.phraseMax) || !isStamp(run.createdAt)) {
    return false;
  }
  return true;
}

function evidenceReady(evidenceNo: string): boolean {
  if (typeof evidenceNo !== 'string') {
    return false;
  }
  let trimmed = evidenceNo.trim();
  if (trimmed.length < 3 || trimmed !== evidenceNo) {
    return false;
  }
  if (trimmed.indexOf('\n') >= 0 || trimmed.indexOf('\r') >= 0) {
    return false;
  }
  return true;
}

function registeredAtText(registeredAt: string): string {
  if (isStamp(registeredAt)) {
    return registeredAt;
  }
  return '尚未登记';
}
