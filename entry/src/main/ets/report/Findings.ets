import { hilog } from '@kit.PerformanceAnalysisKit';
import { acceptProbeRun } from '../probe/ProbeCodec';
import type { ProbeId, ProbeResult } from '../probe/ProbeTypes';
import { INSTALL_CLEAR_PHRASE, POSTURE_CLEAR_PHRASE, ProbeLimits, isStamp } from '../probe/ProbeTypes';

const DOMAIN = 0x4A59;
const TAG = 'Findings';
export const DISCLOSURE_NOTE: string = '基础版已由后续镜像修复验证';

const SCHEMA = 'jinyinhu.finding.list';
const VERSION = '0.1';
const APP = 'com.jinyinhu.lakesidenotes';

@Observed
export class Finding {
  findingId: string = '';
  scenarioId: string = '';
  title: string = '';
  affectedApp: string = '';
  ruleRef: string = '';
  patchRef: string = '';
  status: string = 'open';
  registeredAt: string = '';
  evidenceNo: string = '';
}

export class FindingUpdate {
  changed: boolean = false;
  findings: Finding[] = [];
}

class FindingPeek {
  findingId: string = '';
  scenarioId: string = '';
  title: string = '';
  affectedApp: string = '';
  ruleRef: string = '';
  patchRef: string = '';
  status: string = '';
  registeredAt: string = '';
  evidenceNo: string = '';
}

class ListPeek {
  schema: string = '';
  schemaVersion: string = '';
  findings: FindingPeek[] = [];
}

export class Findings {
  private static blocked: boolean = false;
  private static writer: ((text: string) => void) | undefined = undefined;

  static bindWriter(writer: (text: string) => void): void {
    Findings.writer = writer;
  }

  static restore(): void {
    if (!AppStorage.has('findings')) {
      let empty: Finding[] = [];
      AppStorage.setOrCreate('findings', empty);
    }
  }

  static load(raw: string): void {
    if (typeof raw !== 'string' || raw.length === 0) {
      Findings.blocked = false;
      return;
    }
    let parsed = parseFindings(raw);
    if (parsed === undefined) {
      Findings.blocked = true;
      hilog.error(DOMAIN, TAG, 'findings kept on disk');
      return;
    }
    Findings.blocked = false;
    AppStorage.setOrCreate('findings', parsed);
  }

  static noteUnreadable(): void {
    Findings.blocked = true;
  }

  static list(): Finding[] {
    let current = AppStorage.get<Finding[]>('findings');
    if (current === undefined) {
      let empty: Finding[] = [];
      return empty;
    }
    return copyAll(current);
  }

  static record(result: ProbeResult): void {
    let accepted = acceptProbeRun(result.probeId, result);
    if (!accepted.ok) {
      throw new Error(accepted.reason);
    }
    let update = nextFindings(Findings.list(), accepted.run);
    if (!update.changed) {
      return;
    }
    Findings.commit(update.findings);
  }

  private static commit(findings: Finding[]): void {
    if (Findings.blocked) {
      throw new Error('台账损坏，未写入');
    }
    if (Findings.writer === undefined) {
      throw new Error('台账尚未打开');
    }
    Findings.writer(formatFindings(findings));
    AppStorage.setOrCreate('findings', findings);
  }
}

export function nextFindings(current: Finding[], result: ProbeResult): FindingUpdate {
  let update = new FindingUpdate();
  update.findings = copyAll(current);
  if (!isStamp(result.createdAt)) {
    return update;
  }
  if (result.probeId === 'P3' && result.verdict === 'blocked' && result.imageRole === 'secure' &&
    result.phrase === POSTURE_CLEAR_PHRASE) {
    dismissPosture(update);
    return update;
  }
  if (result.probeId === 'P1' && result.verdict === 'blocked' && result.imageRole === 'secure' &&
    result.phrase === INSTALL_CLEAR_PHRASE) {
    closeIntactInstall(update, result);
    return update;
  }
  if (result.probeId === 'P3' || result.verdict === 'passive' || result.verdict === 'hit') {
    upsertOpen(update, result, result.probeId);
    return update;
  }
  if (result.verdict === 'blocked' && result.imageRole === 'secure') {
    markFixed(update, result);
  }
  return update;
}

function dismissPosture(update: FindingUpdate): void {
  let next: Finding[] = [];
  let removed = false;
  for (let i = 0; i < update.findings.length; i++) {
    if (update.findings[i].findingId === 'FND-C1') {
      removed = true;
    } else {
      next.push(update.findings[i]);
    }
  }
  if (!removed) {
    return;
  }
  update.findings = next;
  update.changed = true;
}

function closeIntactInstall(update: FindingUpdate, result: ProbeResult): void {
  let existing = findByProbe(update.findings, 'P1');
  if (existing === undefined || existing.status !== 'open') {
    return;
  }
  let row = copyFinding(existing);
  row.status = 'fixed-by-patch';
  row.registeredAt = result.createdAt;
  row.evidenceNo = evidenceNoFor(result);
  row.patchRef = '安全镜像已含该修复';
  if (!evidenceFits(row.findingId, row.evidenceNo)) {
    return;
  }
  replaceRow(update, row, false);
}

function upsertOpen(update: FindingUpdate, result: ProbeResult, probeId: ProbeId): void {
  let existing = findByProbe(update.findings, probeId);
  let row = existing === undefined ? template(probeId) : copyFinding(existing);
  if (probeId === 'P3' || result.verdict === 'passive') {
    let kept = row.registeredAt;
    row = template(probeId);
    row.registeredAt = kept;
  }
  let reopened = existing !== undefined && existing.status !== 'open';
  row.status = 'open';
  row.evidenceNo = '';
  row.patchRef = 'open';
  if (probeId === 'P1' && result.verdict === 'passive' && result.level === 'L3') {
    row.patchRef = DISCLOSURE_NOTE;
  }
  if (!isStamp(row.registeredAt) || reopened) {
    row.registeredAt = result.createdAt;
  }
  if (existing !== undefined && sameFinding(existing, row)) {
    return;
  }
  replaceRow(update, row, existing === undefined);
}

function markFixed(update: FindingUpdate, result: ProbeResult): void {
  if (result.probeId === 'P3') {
    return;
  }
  let existing = findByProbe(update.findings, result.probeId);
  if (existing === undefined || existing.status !== 'open') {
    return;
  }
  if (!hasGreenFact(result)) {
    return;
  }
  if (!isStamp(result.createdAt)) {
    return;
  }
  let row = copyFinding(existing);
  row.status = 'fixed-by-patch';
  row.registeredAt = result.createdAt;
  row.evidenceNo = evidenceNoFor(result);
  if (!evidenceFits(row.findingId, row.evidenceNo)) {
    return;
  }
  if (result.probeId === 'P1') {
    row.patchRef = '安全镜像已含该修复';
  } else {
    row.patchRef = 'open';
  }
  replaceRow(update, row, false);
}

class StateFact {
  state: number = 0;
  retCode: number = 0;
  matrix: StateFact[] = [];
}

function hasGreenFact(result: ProbeResult): boolean {
  return hasErrno(result) || hasState2RetCode(result);
}

function hasErrno(result: ProbeResult): boolean {
  if (!(result.evidences instanceof Array)) {
    return false;
  }
  for (let i = 0; i < result.evidences.length; i++) {
    let item = result.evidences[i];
    if (item && item.kind === 'errno' && errnoIn(item.raw)) {
      return true;
    }
  }
  return false;
}

function errnoIn(raw: string): boolean {
  if (typeof raw !== 'string' || raw.length < 3) {
    return false;
  }
  let i = 0;
  while (i + 2 < raw.length) {
    if (raw.charAt(i) === '0' && (raw.charAt(i + 1) === 'x' || raw.charAt(i + 1) === 'X')) {
      let j = i + 2;
      while (j < raw.length && hexDigit(raw.charAt(j)) >= 0) {
        j++;
      }
      if (j > i + 2 && hexNumber(raw.substring(i + 2, j)) > 0) {
        return true;
      }
      i = j;
      continue;
    }
    i++;
  }
  return false;
}

function hexDigit(ch: string): number {
  if (ch >= '0' && ch <= '9') {
    return ch.charCodeAt(0) - '0'.charCodeAt(0);
  }
  if (ch >= 'a' && ch <= 'f') {
    return ch.charCodeAt(0) - 'a'.charCodeAt(0) + 10;
  }
  if (ch >= 'A' && ch <= 'F') {
    return ch.charCodeAt(0) - 'A'.charCodeAt(0) + 10;
  }
  return -1;
}

function hexNumber(text: string): number {
  if (text.length === 0 || text.length > 7) {
    return 0;
  }
  let n = 0;
  for (let i = 0; i < text.length; i++) {
    let digit = hexDigit(text.charAt(i));
    if (digit < 0) {
      return 0;
    }
    n = n * 16 + digit;
  }
  return n;
}

function hasState2RetCode(result: ProbeResult): boolean {
  if (!(result.evidences instanceof Array)) {
    return false;
  }
  for (let i = 0; i < result.evidences.length; i++) {
    let item = result.evidences[i];
    if (item && item.kind === 'sidecar-state' && state2Refused(item.raw)) {
      return true;
    }
  }
  return false;
}

function state2Refused(raw: string): boolean {
  if (typeof raw !== 'string' || raw.length === 0) {
    return false;
  }
  try {
    let parsed = JSON.parse(raw) as StateFact;
    if (!parsed || typeof parsed !== 'object' || parsed instanceof Array) {
      return false;
    }
    if (refusedRetCode(parsed.state, parsed.retCode)) {
      return true;
    }
    if (!(parsed.matrix instanceof Array)) {
      return false;
    }
    for (let i = 0; i < parsed.matrix.length; i++) {
      let step = parsed.matrix[i];
      if (step && refusedRetCode(step.state, step.retCode)) {
        return true;
      }
    }
    return false;
  } catch (err) {
    return false;
  }
}

function refusedRetCode(state: number, retCode: number): boolean {
  if (typeof state !== 'number' || typeof retCode !== 'number') {
    return false;
  }
  if (state !== 2 || retCode === 0 || retCode !== retCode || retCode % 1 !== 0) {
    return false;
  }
  if (retCode < -ProbeLimits.retCodeAbs || retCode > ProbeLimits.retCodeAbs) {
    return false;
  }
  return true;
}

function template(probeId: ProbeId): Finding {
  let row = new Finding();
  if (probeId === 'P1') {
    row.findingId = 'FND-A1';
    row.scenarioId = 'A1';
    row.title = '安装信任链';
    row.affectedApp = APP;
    row.ruleRef = 'hap_verify_v2.cpp:1010-1023; hap_verify_v2.cpp:960-988';
  } else if (probeId === 'P2') {
    row.findingId = 'FND-B1';
    row.scenarioId = 'B1';
    row.title = '沙箱隔离';
    row.affectedApp = APP;
    row.ruleRef = 'sandbox_helper.cpp:532-552; file_uri.cpp:154-200';
  } else {
    row.findingId = 'FND-C1';
    row.scenarioId = 'C1';
    row.title = '安全组件姿态';
    row.affectedApp = '';
    row.ruleRef = 'window_info_helper.cpp:168-170; sec_comp_entity.cpp:53-78; sec_comp_malicious_apps.cpp; sec_comp_service.cpp:163-180';
  }
  row.patchRef = 'open';
  row.status = 'open';
  return row;
}

function evidenceNoFor(result: ProbeResult): string {
  let state = 'C';
  if (result.probeId === 'P1') {
    state = '2';
  } else if (result.probeId === 'P2') {
    state = 'B';
  }
  let pack = APP;
  if (result.probeId === 'P3') {
    pack = 'device';
  }
  return pack + '-' + state + '-' + hash6(result.createdAt + result.probeId + result.verdict);
}

function sameFinding(left: Finding, right: Finding): boolean {
  return left.findingId === right.findingId &&
    left.scenarioId === right.scenarioId &&
    left.title === right.title &&
    left.affectedApp === right.affectedApp &&
    left.ruleRef === right.ruleRef &&
    left.patchRef === right.patchRef &&
    left.status === right.status &&
    left.registeredAt === right.registeredAt &&
    left.evidenceNo === right.evidenceNo;
}

function evidenceFits(findingId: string, evidenceNo: string): boolean {
  let prefix = '';
  if (findingId === 'FND-A1') {
    prefix = APP + '-2-';
  } else if (findingId === 'FND-B1') {
    prefix = APP + '-B-';
  } else {
    return false;
  }
  if (evidenceNo.length !== prefix.length + 6 || evidenceNo.substring(0, prefix.length) !== prefix) {
    return false;
  }
  let tail = evidenceNo.substring(prefix.length);
  for (let i = 0; i < tail.length; i++) {
    let ch = tail.charAt(i);
    let digit = ch >= '0' && ch <= '9';
    let lower = ch >= 'a' && ch <= 'f';
    if (!digit && !lower) {
      return false;
    }
  }
  return true;
}

function replaceRow(update: FindingUpdate, row: Finding, created: boolean): void {
  let next: Finding[] = [];
  let replaced = false;
  for (let i = 0; i < update.findings.length; i++) {
    if (update.findings[i].findingId === row.findingId) {
      next.push(row);
      replaced = true;
    } else {
      next.push(update.findings[i]);
    }
  }
  if (!replaced) {
    next.push(row);
  }
  update.findings = next;
  update.changed = created || replaced;
}

function findByProbe(findings: Finding[], probeId: ProbeId): Finding | undefined {
  let id = 'FND-C1';
  if (probeId === 'P1') {
    id = 'FND-A1';
  } else if (probeId === 'P2') {
    id = 'FND-B1';
  }
  for (let i = 0; i < findings.length; i++) {
    if (findings[i].findingId === id) {
      return findings[i];
    }
  }
  return undefined;
}

function copyAll(findings: Finding[]): Finding[] {
  let next: Finding[] = [];
  for (let i = 0; i < findings.length; i++) {
    next.push(copyFinding(findings[i]));
  }
  return next;
}

function copyFinding(raw: Finding): Finding {
  let row = new Finding();
  row.findingId = raw.findingId;
  row.scenarioId = raw.scenarioId;
  row.title = raw.title;
  row.affectedApp = raw.affectedApp;
  row.ruleRef = raw.ruleRef;
  row.patchRef = raw.patchRef;
  row.status = raw.status;
  row.registeredAt = raw.registeredAt;
  row.evidenceNo = raw.evidenceNo;
  return row;
}

export function formatFindings(findings: Finding[]): string {
  let lines = '{\n';
  lines += '  "schema": "' + SCHEMA + '",\n';
  lines += '  "schemaVersion": "' + VERSION + '",\n';
  lines += '  "findings": [\n';
  for (let i = 0; i < findings.length; i++) {
    lines += formatOne(findings[i]);
    if (i + 1 < findings.length) {
      lines += ',\n';
    } else {
      lines += '\n';
    }
  }
  lines += '  ]\n}\n';
  return lines;
}

function formatOne(row: Finding): string {
  return '    {\n' +
    '      "findingId": ' + quote(row.findingId) + ',\n' +
    '      "scenarioId": ' + quote(row.scenarioId) + ',\n' +
    '      "title": ' + quote(row.title) + ',\n' +
    '      "affectedApp": ' + quote(row.affectedApp) + ',\n' +
    '      "ruleRef": ' + quote(row.ruleRef) + ',\n' +
    '      "patchRef": ' + quote(row.patchRef) + ',\n' +
    '      "status": ' + quote(row.status) + ',\n' +
    '      "registeredAt": ' + quote(row.registeredAt) + ',\n' +
    '      "evidenceNo": ' + quote(row.evidenceNo) + '\n' +
    '    }';
}

export function parseFindings(text: string): Finding[] | undefined {
  if (typeof text !== 'string' || text.length === 0) {
    return undefined;
  }
  try {
    let parsed = JSON.parse(text) as ListPeek;
    if (!parsed || typeof parsed !== 'object' || parsed instanceof Array) {
      return undefined;
    }
    if (parsed.schema !== SCHEMA || parsed.schemaVersion !== VERSION) {
      return undefined;
    }
    if (!(parsed.findings instanceof Array) || parsed.findings.length > 3) {
      return undefined;
    }
    let rows: Finding[] = [];
    let seenA = false;
    let seenB = false;
    let seenC = false;
    for (let i = 0; i < parsed.findings.length; i++) {
      let row = readOne(parsed.findings[i]);
      if (row === undefined) {
        return undefined;
      }
      if (row.findingId === 'FND-A1') {
        if (seenA) {
          return undefined;
        }
        seenA = true;
      } else if (row.findingId === 'FND-B1') {
        if (seenB) {
          return undefined;
        }
        seenB = true;
      } else if (seenC) {
        return undefined;
      } else {
        seenC = true;
      }
      rows.push(row);
    }
    return rows;
  } catch (err) {
    return undefined;
  }
}

function readOne(raw: FindingPeek): Finding | undefined {
  if (!raw || typeof raw !== 'object') {
    return undefined;
  }
  let probeId = probeOf(raw.findingId);
  if (probeId === undefined) {
    return undefined;
  }
  let model = template(probeId);
  if (raw.scenarioId !== model.scenarioId || raw.title !== model.title) {
    return undefined;
  }
  if (raw.affectedApp !== model.affectedApp || raw.ruleRef !== model.ruleRef) {
    return undefined;
  }
  if (typeof raw.patchRef !== 'string' || typeof raw.evidenceNo !== 'string' || typeof raw.registeredAt !== 'string') {
    return undefined;
  }
  if (raw.status !== 'open' && raw.status !== 'fixed-by-patch') {
    return undefined;
  }
  if (!isStamp(raw.registeredAt)) {
    return undefined;
  }
  if (raw.status === 'open' && raw.evidenceNo !== '') {
    return undefined;
  }
  if (raw.status === 'open' && raw.patchRef !== 'open') {
    if (!(probeId === 'P1' && raw.patchRef === DISCLOSURE_NOTE)) {
      return undefined;
    }
  }
  if (raw.status === 'fixed-by-patch') {
    if (probeId === 'P3' || !evidenceFits(raw.findingId, raw.evidenceNo)) {
      return undefined;
    }
    if (probeId === 'P1' && raw.patchRef !== '安全镜像已含该修复') {
      return undefined;
    }
    if (probeId === 'P2' && raw.patchRef !== 'open') {
      return undefined;
    }
  }
  let row = new Finding();
  row.findingId = model.findingId;
  row.scenarioId = model.scenarioId;
  row.title = model.title;
  row.affectedApp = model.affectedApp;
  row.ruleRef = model.ruleRef;
  row.patchRef = raw.patchRef;
  row.status = raw.status;
  row.registeredAt = raw.registeredAt;
  row.evidenceNo = raw.evidenceNo;
  return row;
}

function probeOf(findingId: string): ProbeId | undefined {
  if (findingId === 'FND-A1') {
    return 'P1';
  }
  if (findingId === 'FND-B1') {
    return 'P2';
  }
  if (findingId === 'FND-C1') {
    return 'P3';
  }
  return undefined;
}

function hash6(text: string): string {
  let n = 0;
  for (let i = 0; i < text.length; i++) {
    n = (n * 33 + text.charCodeAt(i)) % 16777216;
  }
  let hex = n.toString(16);
  while (hex.length < 6) {
    hex = '0' + hex;
  }
  return hex.substring(0, 6);
}

function quote(value: string): string {
  let out = '';
  for (let i = 0; i < value.length; i++) {
    let ch = value.charAt(i);
    let code = value.charCodeAt(i);
    if (ch === '"' || ch === '\\') {
      out += '\\' + ch;
    } else if (ch === '\n') {
      out += '\\n';
    } else if (ch === '\r') {
      out += '\\r';
    } else if (ch === '\t') {
      out += '\\t';
    } else if (code < 32) {
      let hex = code.toString(16);
      if (hex.length < 2) {
        hex = '0' + hex;
      }
      out += '\\u00' + hex;
    } else {
      out += ch;
    }
  }
  return '"' + out + '"';
}
