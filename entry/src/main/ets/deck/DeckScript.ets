import { D4Event } from '../model/D4Types';
import { blockedImport, PATCH_LINE } from '../probe/InstallIntegrityProbe';
import { acceptProbeRun } from '../probe/ProbeCodec';
import { ProbeEvidence, ProbeRun, ProbeShelf } from '../probe/ProbeTypes';

export const ACT1_TITLE: string = '一 · 湖畔笔记上线';
export const ACT2_TITLE: string = '二 · 得手（基础版）';
export const ACT3_TITLE: string = '三 · 不可利用（安全版）';
export const ACT1_PHRASE: string = '普通软件·正常存储';
export const ACT1_NARRATION: string = '先有一个普通软件，它依赖两条系统承诺';
export const ACT2_NARRATION: string = '安全中心把伪装的安装请求递给系统，基础版收下了它，笔记已在别人手里';
export const ACT3_NARRATION: string = '系统修了安装验签这一处，湖畔笔记一行没改——现在不可被利用';
export const SANDBOX_TITLE: string = '二 · 沙箱读';
export const SANDBOX_NARRATION: string = '这一幕改演沙箱读，红绿只看这次探针的 errno';
export const POSTURE_TITLE: string = '二 · 姿态披露';
export const POSTURE_ACT3_TITLE: string = '三 · 姿态披露';
export const BOUNDARY_TEXT: string = '覆盖的是台账中登记的线，不是装了就百毒不侵';
export const HIT_WORD: string = '得手';
export const BLOCK_WORD: string = '阻断';
export const PENDING_WORD: string = '尚未取证';
export const BUNDLE_MISSING: number = 17700001;

export class DeckBeat {
  id: string = '';
  title: string = '';
  seconds: number = 0;
  narration: string = '';
}

export class CheckItem {
  id: string = '';
  title: string = '';
  passed: boolean = false;
  detail: string = '';
}

export class BundleSight {
  definite: boolean = false;
  installed: boolean = false;
  versionCode: number = 0;
}

export class ActFace {
  phrase: string = '';
  outcome: string = 'pending';
  ink: string = 'muted';
  title: string = '';
  narration: string = '';
  detail: string = '';
  lines: string[] = [];
  showTrophy: boolean = false;
  showPatch: boolean = false;
  patchLine: string = '';
  imageLabel: string = '';
  role: string = 'secure';
  at: string = '';
}

export function deckBeats(): DeckBeat[] {
  let rows: DeckBeat[] = [];
  rows.push(beat('act1', ACT1_TITLE, 30, ACT1_NARRATION));
  rows.push(beat('gap1', '幕间', 15, BOUNDARY_TEXT));
  rows.push(beat('act2', ACT2_TITLE, 60, ACT2_NARRATION));
  rows.push(beat('gap2', '幕间', 15, BOUNDARY_TEXT));
  rows.push(beat('act3', ACT3_TITLE, 60, ACT3_NARRATION));
  rows.push(beat('end', '结局', 15, BOUNDARY_TEXT));
  return rows;
}

export function sidecarReady(shelf: ProbeShelf): boolean {
  return blockedImport(shelf).length === 0;
}

export function sightInstalled(versionCode: number): BundleSight {
  let sight = new BundleSight();
  if (typeof versionCode !== 'number' || versionCode !== versionCode || versionCode % 1 !== 0 || versionCode < 0) {
    return sight;
  }
  sight.definite = true;
  sight.installed = true;
  sight.versionCode = versionCode;
  return sight;
}

export function sightFromCode(code: number): BundleSight {
  let sight = new BundleSight();
  if (code === BUNDLE_MISSING) {
    sight.definite = true;
    sight.installed = false;
  }
  return sight;
}

export function placeholderCount(events: D4Event[]): number {
  if (events === undefined || typeof events.length !== 'number') {
    return 0;
  }
  let count = 0;
  for (let i = 0; i < events.length; i++) {
    let item = events[i];
    if (item === undefined) {
      continue;
    }
    if (item.source === 'show' || item.detail === '演示稿画面，不含数据') {
      count++;
    }
  }
  return count;
}

export function evaluateChecklist(year: number, readySidecar: boolean, bundle: BundleSight, placeholders: number): CheckItem[] {
  let rows: CheckItem[] = [];
  rows.push(clockItem(year));
  rows.push(bundleItem(bundle));
  rows.push(sidecarItem(readySidecar));
  rows.push(placeholderItem(placeholders));
  return rows;
}

export function checklistReady(items: CheckItem[]): boolean {
  if (items.length !== 4) {
    return false;
  }
  for (let i = 0; i < items.length; i++) {
    if (!items[i].passed) {
      return false;
    }
  }
  return true;
}

export function pickLine(runs: ProbeRun[]): string {
  let latest = newest(runs, 'P1');
  if (latest !== undefined && latest.verdict === 'hit') {
    return 'P1';
  }
  if (isDisclosure(latest)) {
    let sandbox = newest(runs, 'P2');
    if (sandbox !== undefined && errnoLines(sandbox).length > 0) {
      return 'P2';
    }
    return 'P3';
  }
  return 'P1';
}

export function actFace(beatId: string, runs: ProbeRun[]): ActFace {
  let face = new ActFace();
  let narration = narrationOf(beatId);
  face.narration = narration;
  if (beatId === 'act1') {
    face.phrase = ACT1_PHRASE;
    face.ink = 'gold';
    return face;
  }
  if (beatId === 'gap1' || beatId === 'gap2' || beatId === 'end') {
    face.phrase = BOUNDARY_TEXT;
    face.ink = 'gold';
    face.detail = BOUNDARY_TEXT;
    return face;
  }
  if (beatId === 'act2') {
    return actTwo(runs);
  }
  if (beatId === 'act3') {
    return actThree(runs);
  }
  face.phrase = PENDING_WORD;
  return face;
}

function actTwo(runs: ProbeRun[]): ActFace {
  let line = pickLine(runs);
  if (line === 'P2') {
    let face = sandboxFace(newest(runs, 'P2'), SANDBOX_NARRATION);
    face.title = SANDBOX_TITLE;
    face.narration = SANDBOX_NARRATION;
    return face;
  }
  if (line === 'P3') {
    let face = postureFace(runs, BOUNDARY_TEXT);
    face.title = POSTURE_TITLE;
    face.narration = BOUNDARY_TEXT;
    return face;
  }
  let latest = newest(runs, 'P1');
  if (latest !== undefined && latest.verdict === 'hit') {
    let versions = versionLines(latest);
    if (versions.length > 0) {
      let face = new ActFace();
      face.phrase = HIT_WORD;
      face.outcome = 'succeeded';
      face.ink = 'danger';
      face.title = ACT2_TITLE;
      face.narration = ACT2_NARRATION;
      face.lines = versions;
      face.showTrophy = true;
      face.role = latest.imageRole === 'secure' ? 'secure' : 'vanilla-demo';
      face.at = latest.createdAt;
      face.imageLabel = latest.imageRole === 'secure' ? '安全版' : '基础版';
      return face;
    }
  }
  let waiting = pendingFace(ACT2_NARRATION);
  waiting.title = ACT2_TITLE;
  return waiting;
}

function actThree(runs: ProbeRun[]): ActFace {
  let line = pickLine(runs);
  if (line === 'P3') {
    let face = postureFace(runs, BOUNDARY_TEXT);
    face.title = POSTURE_ACT3_TITLE;
    face.narration = BOUNDARY_TEXT;
    return face;
  }
  let latest = newest(runs, 'P1');
  if (line === 'P1' && latest !== undefined && latest.imageRole === 'secure' && latest.verdict === 'blocked' && hasPatch(latest)) {
    let face = new ActFace();
    face.phrase = BLOCK_WORD;
    face.outcome = 'blocked';
    face.ink = 'ok';
    face.title = ACT3_TITLE;
    face.narration = ACT3_NARRATION;
    face.showPatch = true;
    face.patchLine = PATCH_LINE;
    face.imageLabel = '安全版';
    face.role = 'secure';
    face.at = latest.createdAt;
    face.detail = PATCH_LINE;
    return face;
  }
  if (line === 'P2') {
    let face = pendingFace(BOUNDARY_TEXT);
    face.title = '三 · 边界声明';
    face.detail = BOUNDARY_TEXT;
    return face;
  }
  let waiting = pendingFace(ACT3_NARRATION);
  waiting.title = ACT3_TITLE;
  return waiting;
}

function sandboxFace(run: ProbeRun | undefined, narration: string): ActFace {
  if (run === undefined) {
    return pendingFace(narration);
  }
  let lines = errnoLines(run);
  if (lines.length === 0) {
    return pendingFace(narration);
  }
  let face = new ActFace();
  face.phrase = plainPhrase(run.phrase);
  face.narration = narration;
  face.lines = lines;
  face.role = run.imageRole === 'secure' ? 'secure' : 'vanilla-demo';
  face.at = run.createdAt;
  face.imageLabel = run.imageRole === 'secure' ? '安全版' : '基础版';
  if (run.verdict === 'hit') {
    face.outcome = 'succeeded';
    face.ink = 'danger';
  } else if (run.verdict === 'blocked') {
    face.outcome = 'blocked';
    face.ink = 'ok';
  } else {
    face.outcome = 'pending';
    face.ink = 'gold';
  }
  return face;
}

function postureFace(runs: ProbeRun[], narration: string): ActFace {
  let face = pendingFace(narration);
  face.detail = BOUNDARY_TEXT;
  let run = passivePosture(runs);
  if (run === undefined) {
    return face;
  }
  let lines = postureLines(run);
  if (lines.length === 0) {
    return face;
  }
  face.phrase = plainPhrase(run.phrase);
  face.ink = 'gold';
  face.lines = lines;
  face.at = run.createdAt;
  return face;
}

function pendingFace(narration: string): ActFace {
  let face = new ActFace();
  face.phrase = PENDING_WORD;
  face.outcome = 'pending';
  face.ink = 'muted';
  face.narration = narration;
  return face;
}

function passivePosture(runs: ProbeRun[]): ProbeRun | undefined {
  let best: ProbeRun | undefined = undefined;
  for (let i = 0; i < runs.length; i++) {
    let run = runs[i];
    if (run.probeId !== 'P3' || run.verdict !== 'passive' || run.level !== 'L3') {
      continue;
    }
    if (!acceptProbeRun('P3', run).ok) {
      continue;
    }
    if (best === undefined || run.createdAt >= best.createdAt) {
      best = run;
    }
  }
  return best;
}

function newest(runs: ProbeRun[], id: string): ProbeRun | undefined {
  if (runs === undefined || typeof runs.length !== 'number') {
    return undefined;
  }
  let best: ProbeRun | undefined = undefined;
  for (let i = 0; i < runs.length; i++) {
    let run = runs[i];
    if (run === undefined || run.probeId !== id) {
      continue;
    }
    if (!acceptProbeRun(id, run).ok) {
      continue;
    }
    if (best === undefined || run.createdAt >= best.createdAt) {
      best = run;
    }
  }
  return best;
}

function isDisclosure(run: ProbeRun | undefined): boolean {
  if (run === undefined) {
    return false;
  }
  return run.probeId === 'P1' && run.verdict === 'passive' && run.level === 'L3';
}

function versionLines(run: ProbeRun): string[] {
  let lines: string[] = [];
  let rows = evidencesOf(run);
  for (let i = 0; i < rows.length; i++) {
    if (rows[i].kind !== 'bundle-state') {
      continue;
    }
    if (rows[i].text.length > 0) {
      lines.push(rows[i].text);
    }
    if (rows[i].raw.length > 0) {
      lines.push(rows[i].raw);
    }
  }
  return lines;
}

function errnoLines(run: ProbeRun): string[] {
  let lines: string[] = [];
  let rows = evidencesOf(run);
  for (let i = 0; i < rows.length; i++) {
    if (rows[i].kind !== 'errno') {
      continue;
    }
    if (rows[i].text.length > 0) {
      lines.push(rows[i].text);
    }
    if (rows[i].raw.length > 0) {
      lines.push(rows[i].raw);
    }
  }
  return lines;
}

function postureLines(run: ProbeRun): string[] {
  let lines: string[] = [];
  let rows = evidencesOf(run);
  for (let i = 0; i < rows.length; i++) {
    if (rows[i].kind !== 'source-ref') {
      continue;
    }
    if (rows[i].raw.length > 0) {
      lines.push(rows[i].raw);
    }
    if (rows[i].text.length > 0) {
      lines.push(rows[i].text);
    }
  }
  return lines;
}

function hasPatch(run: ProbeRun): boolean {
  let rows = evidencesOf(run);
  for (let i = 0; i < rows.length; i++) {
    if (rows[i].kind === 'source-ref' && rows[i].raw.indexOf(PATCH_LINE) >= 0) {
      return true;
    }
  }
  return false;
}

function evidencesOf(run: ProbeRun): ProbeEvidence[] {
  if (run.evidences === undefined || typeof run.evidences.length !== 'number') {
    return [];
  }
  return run.evidences;
}

function plainPhrase(phrase: string): string {
  if (phrase === HIT_WORD || phrase === BLOCK_WORD || phrase.length === 0) {
    return PENDING_WORD;
  }
  return phrase;
}

function narrationOf(beatId: string): string {
  let rows = deckBeats();
  for (let i = 0; i < rows.length; i++) {
    if (rows[i].id === beatId) {
      return rows[i].narration;
    }
  }
  return '';
}

function beat(id: string, title: string, seconds: number, narration: string): DeckBeat {
  let row = new DeckBeat();
  row.id = id;
  row.title = title;
  row.seconds = seconds;
  row.narration = narration;
  return row;
}

function clockItem(year: number): CheckItem {
  let item = new CheckItem();
  item.id = 'clock';
  item.title = '板对时';
  if (typeof year === 'number' && year === year && year % 1 === 0 && year !== 2021) {
    item.passed = true;
    item.detail = '板时钟年份是 ' + year.toString();
  } else {
    item.detail = '时钟停在 2021';
  }
  return item;
}

function bundleItem(bundle: BundleSight): CheckItem {
  let item = new CheckItem();
  item.id = 'bundle';
  item.title = '湖畔笔记预置数据 reset';
  if (bundle !== undefined && bundle.definite && bundle.installed) {
    item.passed = true;
    item.detail = '湖畔笔记已安装，versionCode=' + bundle.versionCode.toString();
  } else if (bundle !== undefined && bundle.definite) {
    item.passed = true;
    item.detail = '湖畔笔记未安装';
  } else {
    item.detail = '读回没有明确结果';
  }
  return item;
}

function sidecarItem(readySidecar: boolean): CheckItem {
  let item = new CheckItem();
  item.id = 'sidecar';
  item.title = '侧车脚本已出最新报告';
  if (readySidecar) {
    item.passed = true;
    item.detail = '侧车报告已导入';
  } else {
    item.detail = '侧车未导入';
  }
  return item;
}

function placeholderItem(placeholders: number): CheckItem {
  let item = new CheckItem();
  item.id = 'placeholder';
  item.title = '空载占位页面已清理';
  if (typeof placeholders === 'number' && placeholders === placeholders && placeholders % 1 === 0 && placeholders <= 0) {
    item.passed = true;
    item.detail = '事件流没有 L3 占位';
  } else {
    let count = 0;
    if (typeof placeholders === 'number' && placeholders === placeholders) {
      count = placeholders;
    }
    item.detail = '事件流里混入了展示区数字，还有 ' + count.toString() + ' 条';
  }
  return item;
}
