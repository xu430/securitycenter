import bundleManager from '@ohos.bundle.bundleManager';
import deviceInfo from '@ohos.deviceInfo';
import { Theme } from '../common/Theme';
import { FieldBox, PrimaryButton, StatusLine } from '../components/UiParts';
import { nowIso } from '../model/D4Types';
import { LiveStore } from '../model/LiveStore';
import { shortStamp } from '../model/ProbeStatus';
import { LAKESIDE_BUNDLE } from '../probe/InstallIntegrityProbe';
import { ProbeLimits, ProbeShelf, emptyProbeShelf } from '../probe/ProbeTypes';

class ErrorBox {
  code: number = 0;
}

class InfoRow {
  label: string = '';
  value: string = '';
}

@Component
export struct DeviceView {
  @StorageLink('statusLine') statusLine: string = '';
  @StorageLink('probeShelf') probeShelf: ProbeShelf = emptyProbeShelf();
  @State boardClock: string = '';
  @State osName: string = '';
  @State bundleText: string = '';
  @State udidDraft: string = '';
  @State udidTouched: boolean = false;

  aboutToAppear(): void {
    this.readLive();
  }

  build() {
    Scroll() {
      Column() {
        this.groupTitle('本机')
        this.infoGroup(this.deviceRows())

        this.groupTitle('检测报告')
        this.infoGroup(this.reportRows())

        this.groupTitle('设备登记')
        Column() {
          FieldBox({
            title: '设备 UDID',
            text: this.udidTouched ? this.udidDraft : this.probeShelf.boardUdid,
            placeholder: '留空则导入报告时不核对 UDID',
            maxLength: 128,
            onEdit: (value: string) => {
              this.udidTouched = true;
              this.udidDraft = value;
            }
          })
          Text(this.probeShelf.boardUdid.length > 0 ? '已登记' : '未登记，导入报告时跳过核对')
            .width('100%')
            .fontSize(12)
            .fontColor(Theme.muted)
          PrimaryButton({
            label: '保存',
            canTap: true,
            onTap: () => {
              LiveStore.setBoardUdid(this.udidTouched ? this.udidDraft : this.probeShelf.boardUdid);
              this.udidTouched = false;
            }
          })
            .margin({ top: 8 })
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor(Theme.card)

        StatusLine({ text: this.statusLine })
          .margin({ top: 8 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 24 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
    .backgroundColor(Theme.page)
    .onVisibleAreaChange([0.0], (expanding: boolean, ratio: number) => {
      if (expanding && ratio > 0) {
        this.readLive();
      }
    })
  }

  @Builder
  groupTitle(title: string) {
    Text(title)
      .width('100%')
      .fontSize(14)
      .fontColor(Theme.muted)
      .padding({ left: 12, top: 16, bottom: 8 })
  }

  @Builder
  infoGroup(rows: InfoRow[]) {
    Column() {
      ForEach(rows, (row: InfoRow, index: number) => {
        Column() {
          Row() {
            Text(row.label)
              .fontSize(16)
              .fontColor(Theme.text)
            Text(row.value)
              .fontSize(14)
              .fontColor(Theme.muted)
              .textAlign(TextAlign.End)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .margin({ left: 16 })
          }
          .width('100%')
          .constraintSize({ minHeight: 52 })
          .alignItems(VerticalAlign.Center)
          if (index + 1 < rows.length) {
            Divider()
              .color(Theme.line)
              .strokeWidth(0.5)
          }
        }
        .width('100%')
      }, (row: InfoRow, index: number) => index.toString() + row.label + row.value)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .borderRadius(16)
    .backgroundColor(Theme.card)
  }

  private deviceRows(): InfoRow[] {
    let rows: InfoRow[] = [];
    rows.push(infoRow('系统版本', this.osName));
    rows.push(infoRow('设备时间', this.boardClock.length > 0 ? shortStamp(this.boardClock) : '尚未读到'));
    rows.push(infoRow('笔记', this.bundleText));
    rows.push(infoRow('设备 UDID', this.probeShelf.boardUdid.length > 0 ? this.probeShelf.boardUdid : '未登记'));
    return rows;
  }

  private reportRows(): InfoRow[] {
    let rows: InfoRow[] = [];
    if (!this.reportKept()) {
      rows.push(infoRow('导入状态', '未导入'));
      return rows;
    }
    rows.push(infoRow('导入状态', this.probeShelf.failureReason.length > 0 ? '最近一次导入失败' : '已导入'));
    let tag = this.probeShelf.sidecar.imageTag;
    rows.push(infoRow('系统镜像', tag === 'secure' ? '安全版' : (tag === 'base' ? '基础版' : '未知')));
    rows.push(infoRow('安装返回码', this.stateTwoCode()));
    if (shortStamp(this.probeShelf.importAt).length > 0) {
      rows.push(infoRow('导入时间', shortStamp(this.probeShelf.importAt)));
    }
    return rows;
  }

  private stateTwoCode(): string {
    let matrix = this.probeShelf.sidecar.matrix;
    for (let i = 0; i < matrix.length; i++) {
      if (matrix[i].state === 2) {
        return matrix[i].retCode.toString();
      }
    }
    return '报告里没有';
  }

  private reportKept(): boolean {
    return this.probeShelf.sidecarPresent && this.probeShelf.importState === ProbeLimits.importImported;
  }

  private readLive(): void {
    this.boardClock = nowIso();
    this.osName = readOs();
    this.bundleText = readBundle();
  }
}

function infoRow(label: string, value: string): InfoRow {
  let row = new InfoRow();
  row.label = label;
  row.value = value.length > 0 ? value : '—';
  return row;
}

function readOs(): string {
  let name = deviceInfo.osFullName;
  if (typeof name !== 'string' || name.trim().length === 0) {
    return '尚未读到';
  }
  return name.trim();
}

function readBundle(): string {
  try {
    let info = bundleManager.getBundleInfoSync(LAKESIDE_BUNDLE, bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
    let versionCode = info.versionCode;
    if (typeof versionCode !== 'number' || versionCode !== versionCode || versionCode % 1 !== 0) {
      return '读取失败';
    }
    return '已安装 · versionCode ' + versionCode.toString();
  } catch (err) {
    let boxed: ErrorBox = err as ErrorBox;
    if (boxed.code === 17700001) {
      return '未安装';
    }
    if (typeof boxed.code === 'number' && boxed.code !== 0) {
      return '读取失败 ' + boxed.code.toString();
    }
    return '读取失败';
  }
}
