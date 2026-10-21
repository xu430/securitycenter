import { common } from '@kit.AbilityKit';
import { FileExchange } from '../model/FileExchange';
import { LiveStore } from '../model/LiveStore';
import { ProbeEvidence, ProbeRun } from '../probe/ProbeTypes';
import { Finding, Findings } from './Findings';

const SCHEMA = 'jinyinhu.ledger.export';
const VERSION = '0.1';

export class LedgerEvidence {
  kind: string = '';
  text: string = '';
  raw: string = '';
  at: string = '';
}

export class LedgerRun {
  probeId: string = '';
  verdict: string = '';
  phrase: string = '';
  imageRole: string = '';
  createdAt: string = '';
  evidences: LedgerEvidence[] = [];
}

export class LedgerEntry {
  findingId: string = '';
  scenarioId: string = '';
  title: string = '';
  affectedApp: string = '';
  ruleRef: string = '';
  patchRef: string = '';
  status: string = '';
  registeredAt: string = '';
  evidenceNo: string = '';
  runs: LedgerRun[] = [];
}

class RankedRun {
  run: ProbeRun = new ProbeRun();
  index: number = 0;
}

export class Ledger {
  static readonly archiveName: string = 'jinyinhu-ledger.json';
  static readonly emptyText: string = '演示前无事件';
  static readonly unscannedText: string = '尚未扫描';

  static entries(): LedgerEntry[] {
    return ledgerEntries(Findings.list(), LiveStore.shelf().runs);
  }

  static detail(findingId: string): LedgerEntry | undefined {
    return ledgerDetail(findingId, Findings.list(), LiveStore.shelf().runs);
  }

  static exportText(): string {
    return ledgerExport(Findings.list(), LiveStore.shelf().runs);
  }

  static async saveForArchive(ctx: common.UIAbilityContext): Promise<string> {
    let text = Ledger.exportText();
    if (text.length === 0) {
      return Ledger.emptyText;
    }
    let saved = await FileExchange.saveText(ctx, Ledger.archiveName, text);
    if (!saved.ok) {
      if (saved.message.length === 0) {
        return '保存失败';
      }
      return saved.message;
    }
    return saved.message;
  }
}

export function ledgerEntries(findings: Finding[], runs: ProbeRun[]): LedgerEntry[] {
  let rows: LedgerEntry[] = [];
  if (findings === undefined || typeof findings.length !== 'number') {
    return rows;
  }
  let shelf: ProbeRun[] = [];
  if (runs !== undefined && typeof runs.length === 'number') {
    shelf = runs;
  }
  for (let i = 0; i < findings.length; i++) {
    let row = oneEntry(findings[i], shelf);
    if (row !== undefined) {
      rows.push(row);
    }
  }
  rows.sort((left: LedgerEntry, right: LedgerEntry): number => {
    if (left.registeredAt === right.registeredAt) {
      if (left.findingId < right.findingId) {
        return -1;
      }
      if (left.findingId > right.findingId) {
        return 1;
      }
      return 0;
    }
    if (left.registeredAt < right.registeredAt) {
      return 1;
    }
    return -1;
  });
  return rows;
}

export function ledgerDetail(findingId: string, findings: Finding[], runs: ProbeRun[]): LedgerEntry | undefined {
  if (typeof findingId !== 'string' || findingId.length === 0) {
    return undefined;
  }
  let rows = ledgerEntries(findings, runs);
  for (let i = 0; i < rows.length; i++) {
    if (rows[i].findingId === findingId) {
      return rows[i];
    }
  }
  return undefined;
}

export function ledgerExport(findings: Finding[], runs: ProbeRun[]): string {
  let rows = ledgerEntries(findings, runs);
  if (rows.length === 0) {
    return '';
  }
  let lines = '{\n';
  lines += '  "schema": "' + SCHEMA + '",\n';
  lines += '  "schemaVersion": "' + VERSION + '",\n';
  lines += '  "findings": [\n';
  for (let i = 0; i < rows.length; i++) {
    lines += formatEntry(rows[i]);
    if (i + 1 < rows.length) {
      lines += ',\n';
    } else {
      lines += '\n';
    }
  }
  lines += '  ]\n}\n';
  return lines;
}

function oneEntry(raw: Finding, runs: ProbeRun[]): LedgerEntry | undefined {
  if (!raw) {
    return undefined;
  }
  let probeId = probeIdOf(raw);
  if (probeId.length === 0) {
    return undefined;
  }
  if (raw.status !== 'open' && raw.status !== 'fixed-by-patch') {
    return undefined;
  }
  let row = new LedgerEntry();
  row.findingId = raw.findingId;
  row.scenarioId = raw.scenarioId;
  row.title = raw.title;
  row.affectedApp = raw.affectedApp;
  row.ruleRef = raw.ruleRef;
  row.patchRef = raw.patchRef;
  row.status = raw.status;
  row.registeredAt = raw.registeredAt;
  row.evidenceNo = raw.evidenceNo;
  row.runs = runsFor(probeId, runs);
  return row;
}

function probeIdOf(raw: Finding): string {
  if (raw.findingId === 'FND-A1' && raw.scenarioId === 'A1') {
    return 'P1';
  }
  if (raw.findingId === 'FND-B1' && raw.scenarioId === 'B1') {
    return 'P2';
  }
  if (raw.findingId === 'FND-C1' && raw.scenarioId === 'C1') {
    return 'P3';
  }
  return '';
}

function runsFor(probeId: string, runs: ProbeRun[]): LedgerRun[] {
  let ranked: RankedRun[] = [];
  for (let i = 0; i < runs.length; i++) {
    let run = runs[i];
    if (!run || run.probeId !== probeId) {
      continue;
    }
    let item = new RankedRun();
    item.run = run;
    item.index = i;
    ranked.push(item);
  }
  ranked.sort((left: RankedRun, right: RankedRun): number => {
    if (left.run.createdAt === right.run.createdAt) {
      return right.index - left.index;
    }
    if (left.run.createdAt < right.run.createdAt) {
      return 1;
    }
    return -1;
  });
  let copied: LedgerRun[] = [];
  for (let i = 0; i < ranked.length; i++) {
    copied.push(copyRun(ranked[i].run));
  }
  return copied;
}

function copyRun(raw: ProbeRun): LedgerRun {
  let run = new LedgerRun();
  run.probeId = raw.probeId;
  run.verdict = raw.verdict;
  run.phrase = raw.phrase;
  run.imageRole = raw.imageRole === 'base' || raw.imageRole === 'secure' ? raw.imageRole : '';
  run.createdAt = raw.createdAt;
  let evidences: LedgerEvidence[] = [];
  if (raw.evidences !== undefined && typeof raw.evidences.length === 'number') {
    for (let i = 0; i < raw.evidences.length; i++) {
      let item = copyEvidence(raw.evidences[i]);
      if (item !== undefined) {
        evidences.push(item);
      }
    }
  }
  run.evidences = evidences;
  return run;
}

function copyEvidence(raw: ProbeEvidence): LedgerEvidence | undefined {
  if (!raw || !knownKind(raw.kind)) {
    return undefined;
  }
  let item = new LedgerEvidence();
  item.kind = raw.kind;
  item.text = screenText(typeof raw.text === 'string' ? raw.text : '');
  item.raw = screenRaw(raw.kind, typeof raw.raw === 'string' ? raw.raw : '');
  item.at = typeof raw.at === 'string' ? raw.at : '';
  return item;
}

function knownKind(kind: string): boolean {
  return kind === 'errno' || kind === 'bundle-state' || kind === 'hilog-line' ||
    kind === 'source-ref' || kind === 'cmd-transcript' || kind === 'sidecar-state';
}

class SidePeek {
  state: number = 0;
  retCode: number = 0;
  matrix: SidePeek[] = [];
  imageTag: string = '';
  boardClockAtRun: string = '';
}

function screenText(text: string): string {
  if (text.length === 0) {
    return '';
  }
  if (text.length > 400 || text.indexOf('{') >= 0 || text.indexOf('"') >= 0 || text.indexOf('\n') >= 0) {
    return '已脱敏';
  }
  return text;
}

function screenRaw(kind: string, raw: string): string {
  if (raw.length === 0) {
    return '';
  }
  if (kind === 'errno') {
    if (errnoLine(raw)) {
      return raw;
    }
    return '已脱敏';
  }
  if (kind === 'sidecar-state') {
    return screenSidecar(raw);
  }
  if (kind === 'cmd-transcript') {
    return screenTranscript(raw);
  }
  if (kind === 'source-ref') {
    if (sourceRef(raw)) {
      return raw;
    }
    return '已脱敏';
  }
  if (plainEvidence(raw)) {
    return raw;
  }
  return '已脱敏';
}

function screenTranscript(raw: string): string {
  if (raw === '已脱敏' || raw.indexOf('\u0000') >= 0) {
    return '已脱敏';
  }
  if (raw.length > 8000) {
    return raw.substring(0, 8000);
  }
  return raw;
}

function errnoLine(raw: string): boolean {
  let i = 0;
  let saw = false;
  while (i < raw.length) {
    if (raw.charAt(i) === ' ') {
      i++;
      continue;
    }
    let next = takeErrno(raw, i);
    if (next <= i) {
      return false;
    }
    i = next;
    saw = true;
  }
  return saw;
}

function takeErrno(raw: string, i: number): number {
  if (tokenAt(raw, i, '拿到句柄')) {
    return i + 4;
  }
  if (tokenAt(raw, i, '拿到stat')) {
    return i + 6;
  }
  if (tokenAt(raw, i, '落点')) {
    return i + 2;
  }
  if (tokenAt(raw, i, '穿越')) {
    return i + 2;
  }
  if (tokenAt(raw, i, 'stat=')) {
    return i + 5;
  }
  if (tokenAt(raw, i, 'open=')) {
    return i + 5;
  }
  if (tokenAt(raw, i, '0x') || tokenAt(raw, i, '0X')) {
    let j = i + 2;
    let digits = 0;
    while (j < raw.length && hexChar(raw.charAt(j))) {
      j++;
      digits++;
    }
    if (digits === 0 || digits > 8) {
      return i;
    }
    return j;
  }
  if (tokenAt(raw, i, 'na') && errnoBoundary(raw, i + 2)) {
    return i + 2;
  }
  return i;
}

function tokenAt(raw: string, i: number, token: string): boolean {
  return raw.substring(i, i + token.length) === token;
}

function errnoBoundary(raw: string, i: number): boolean {
  if (i >= raw.length) {
    return true;
  }
  return raw.charAt(i) === ' ';
}

function hexChar(ch: string): boolean {
  return (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F');
}

function sourceRef(raw: string): boolean {
  if (raw.length === 0 || raw.length > 400 || !sourceChars(raw)) {
    return false;
  }
  if (raw.indexOf(':') >= 0) {
    return true;
  }
  return raw.length <= 80 && raw.indexOf(' ') < 0 && raw.indexOf('/') < 0 &&
    raw.substring(raw.length - 4) === '.cpp';
}

function sourceChars(raw: string): boolean {
  for (let i = 0; i < raw.length; i++) {
    let ch = raw.charAt(i);
    let letter = (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
    let digit = ch >= '0' && ch <= '9';
    let mark = ch === '_' || ch === '.' || ch === ':' || ch === '-' || ch === ';' || ch === '/' || ch === ' ';
    if (!letter && !digit && !mark) {
      return false;
    }
  }
  return true;
}

function plainEvidence(raw: string): boolean {
  if (raw.length > 240 || raw.indexOf('{') >= 0 || raw.indexOf('}') >= 0 || raw.indexOf('"') >= 0) {
    return false;
  }
  if (raw.indexOf('\n') >= 0 || raw.indexOf('\r') >= 0) {
    return false;
  }
  return true;
}

function screenSidecar(raw: string): string {
  try {
    let parsed = JSON.parse(raw) as SidePeek;
    if (!parsed || typeof parsed !== 'object' || parsed instanceof Array) {
      return '已脱敏';
    }
    if (parsed.matrix instanceof Array) {
      let body = '';
      let count = 0;
      for (let i = 0; i < parsed.matrix.length; i++) {
        let step = parsed.matrix[i];
        if (!step || !isSideStep(step.state, step.retCode)) {
          continue;
        }
        if (count > 0) {
          body += ',';
        }
        body += '{"state":' + step.state.toString() + ',"retCode":' + step.retCode.toString() + '}';
        count++;
      }
      if (count === 0) {
        return '已脱敏';
      }
      return sideObject(parsed, '"matrix":[' + body + ']');
    }
    if (isSideStep(parsed.state, parsed.retCode)) {
      return sideObject(parsed, '"state":' + parsed.state.toString() + ',"retCode":' + parsed.retCode.toString());
    }
    return '已脱敏';
  } catch (err) {
    return '已脱敏';
  }
}

function sideObject(parsed: SidePeek, body: string): string {
  let head = '';
  if (parsed.imageTag === 'base' || parsed.imageTag === 'secure') {
    head += '"imageTag":"' + parsed.imageTag + '"';
  }
  if (typeof parsed.boardClockAtRun === 'string' && parsed.boardClockAtRun.length === 25 &&
    parsed.boardClockAtRun.indexOf('"') < 0 && parsed.boardClockAtRun.indexOf('\\') < 0) {
    if (head.length > 0) {
      head += ',';
    }
    head += '"boardClockAtRun":"' + parsed.boardClockAtRun + '"';
  }
  if (head.length === 0) {
    return '{' + body + '}';
  }
  return '{' + head + ',' + body + '}';
}

function isSideStep(state: number, retCode: number): boolean {
  if (typeof state !== 'number' || typeof retCode !== 'number') {
    return false;
  }
  if (state !== state || retCode !== retCode || state % 1 !== 0 || retCode % 1 !== 0) {
    return false;
  }
  if (state < 0 || state > 9 || retCode < -1000000 || retCode > 1000000) {
    return false;
  }
  return true;
}

function formatEntry(row: LedgerEntry): string {
  let lines = '    {\n';
  lines += '      "findingId": ' + quote(row.findingId) + ',\n';
  lines += '      "scenarioId": ' + quote(row.scenarioId) + ',\n';
  lines += '      "title": ' + quote(row.title) + ',\n';
  lines += '      "affectedApp": ' + quote(row.affectedApp) + ',\n';
  lines += '      "ruleRef": ' + quote(row.ruleRef) + ',\n';
  lines += '      "patchRef": ' + quote(row.patchRef) + ',\n';
  lines += '      "status": ' + quote(row.status) + ',\n';
  lines += '      "registeredAt": ' + quote(row.registeredAt) + ',\n';
  lines += '      "evidenceNo": ' + quote(row.evidenceNo) + ',\n';
  lines += '      "runs": [\n';
  for (let i = 0; i < row.runs.length; i++) {
    lines += formatRun(row.runs[i]);
    if (i + 1 < row.runs.length) {
      lines += ',\n';
    } else {
      lines += '\n';
    }
  }
  lines += '      ]\n';
  lines += '    }';
  return lines;
}

function formatRun(run: LedgerRun): string {
  let lines = '        {\n';
  lines += '          "probeId": ' + quote(run.probeId) + ',\n';
  lines += '          "verdict": ' + quote(run.verdict) + ',\n';
  lines += '          "phrase": ' + quote(run.phrase) + ',\n';
  lines += '          "imageRole": ' + quote(run.imageRole) + ',\n';
  lines += '          "createdAt": ' + quote(run.createdAt) + ',\n';
  lines += '          "evidences": [\n';
  for (let i = 0; i < run.evidences.length; i++) {
    lines += formatEvidence(run.evidences[i]);
    if (i + 1 < run.evidences.length) {
      lines += ',\n';
    } else {
      lines += '\n';
    }
  }
  lines += '          ]\n';
  lines += '        }';
  return lines;
}

function formatEvidence(item: LedgerEvidence): string {
  return '            {\n' +
    '              "kind": ' + quote(item.kind) + ',\n' +
    '              "text": ' + quote(item.text) + ',\n' +
    '              "raw": ' + quote(item.raw) + ',\n' +
    '              "at": ' + quote(item.at) + '\n' +
    '            }';
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

export class SocTally {
  hit: number = 0;
  blocked: number = 0;
  passive: number = 0;
}

export function tallyVerdicts(runs: ProbeRun[]): SocTally {
  let tally = new SocTally();
  if (runs === undefined || typeof runs.length !== 'number') {
    return tally;
  }
  for (let i = 0; i < runs.length; i++) {
    let run = runs[i];
    if (!run) {
      continue;
    }
    if (run.probeId !== 'P1' && run.probeId !== 'P2' && run.probeId !== 'P3') {
      continue;
    }
    if (run.verdict === 'hit') {
      tally.hit = tally.hit + 1;
    } else if (run.verdict === 'blocked') {
      tally.blocked = tally.blocked + 1;
    } else if (run.verdict === 'passive') {
      tally.passive = tally.passive + 1;
    }
  }
  return tally;
}

export function pickImageTag(choiceTag: string, choiceAt: string, sidecarTag: string, sidecarReady: boolean,
  sidecarAt: string): string {
  let picked = '';
  if (choiceTag === 'base' || choiceTag === 'secure') {
    picked = choiceTag;
  }
  let side = '';
  if (sidecarReady && (sidecarTag === 'base' || sidecarTag === 'secure')) {
    side = sidecarTag;
  }
  if (picked.length === 0) {
    return side;
  }
  if (side.length === 0) {
    return picked;
  }
  if (choiceAt >= sidecarAt) {
    return picked;
  }
  return side;
}

export function countOpenFindings(findings: Finding[]): number {
  if (findings === undefined || typeof findings.length !== 'number') {
    return 0;
  }
  let count = 0;
  for (let i = 0; i < findings.length; i++) {
    if (findings[i] && findings[i].status === 'open') {
      count = count + 1;
    }
  }
  return count;
}
