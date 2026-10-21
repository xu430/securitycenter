import { hilog } from '@kit.PerformanceAnalysisKit';
import { acceptProbeRun } from '../probe/ProbeCodec';
import { ProbeRun, isStamp } from '../probe/ProbeTypes';
import { Finding, formatFindings, parseFindings } from '../report/Findings';
import { BoardCard, BoardPair, BuildInfo, D4Event, ParseResult, defaultBoards, isHexTail, nowIso, validateEvent } from './D4Types';

class BundlePeek {
  schema: string = '';
  schemaVersion: string = '';
  events: D4Event[] = [];
}

class BoardPeek {
  role: string = '';
  title: string = '';
  deviceId: string = '';
  imageVersion: string = '';
  hashTail: string = '';
  appVersion: string = '';
}

class PairPeek {
  schema: string = '';
  schemaVersion: string = '';
  vanilla: BoardPeek = new BoardPeek();
  secure: BoardPeek = new BoardPeek();
}

function jsonEscape(value: string): string {
  let out = '';
  for (let i = 0; i < value.length; i++) {
    let code = value.charCodeAt(i);
    if (code === 34) {
      out += '\\"';
    } else if (code === 92) {
      out += '\\\\';
    } else if (code === 10) {
      out += '\\n';
    } else if (code === 13) {
      out += '\\r';
    } else if (code === 9) {
      out += '\\t';
    } else if (code < 32) {
      let hex = code.toString(16);
      if (hex.length < 2) {
        hex = '0' + hex;
      }
      out += '\\u00' + hex;
    } else {
      out += value.charAt(i);
    }
  }
  return out;
}

function quote(value: string): string {
  return '"' + jsonEscape(value) + '"';
}

function textOf(value: string): string {
  if (typeof value === 'string') {
    return value;
  }
  return '';
}

function copyEvent(raw: D4Event): D4Event {
  let event = new D4Event();
  event.schema = textOf(raw.schema);
  event.schemaVersion = textOf(raw.schemaVersion);
  event.eventId = textOf(raw.eventId);
  if (typeof raw.seq === 'number') {
    event.seq = raw.seq;
  }
  event.deviceId = textOf(raw.deviceId);
  event.imageRole = textOf(raw.imageRole);
  event.imageVersion = textOf(raw.imageVersion);
  event.imageHashTail = textOf(raw.imageHashTail).toUpperCase();
  event.appId = textOf(raw.appId);
  event.appVersion = textOf(raw.appVersion);
  event.scenarioId = textOf(raw.scenarioId);
  event.outcome = textOf(raw.outcome);
  event.phrase = textOf(raw.phrase);
  event.occurredAt = textOf(raw.occurredAt);
  event.ruleId = textOf(raw.ruleId);
  event.baselineClause = textOf(raw.baselineClause);
  event.threatId = textOf(raw.threatId);
  event.threatStatus = textOf(raw.threatStatus);
  event.registeredAt = textOf(raw.registeredAt);
  event.evidenceNo = textOf(raw.evidenceNo);
  event.source = textOf(raw.source);
  event.detail = textOf(raw.detail);
  return event;
}

function formatEvent(event: D4Event, pad: string): string {
  let inner = pad + '  ';
  let lines = pad + '{\n';
  lines += inner + '"schema": ' + quote(event.schema) + ',\n';
  lines += inner + '"schemaVersion": ' + quote(event.schemaVersion) + ',\n';
  lines += inner + '"eventId": ' + quote(event.eventId) + ',\n';
  lines += inner + '"seq": ' + event.seq.toString() + ',\n';
  lines += inner + '"deviceId": ' + quote(event.deviceId) + ',\n';
  lines += inner + '"imageRole": ' + quote(event.imageRole) + ',\n';
  lines += inner + '"imageVersion": ' + quote(event.imageVersion) + ',\n';
  lines += inner + '"imageHashTail": ' + quote(event.imageHashTail) + ',\n';
  lines += inner + '"appId": ' + quote(event.appId) + ',\n';
  lines += inner + '"appVersion": ' + quote(event.appVersion) + ',\n';
  lines += inner + '"scenarioId": ' + quote(event.scenarioId) + ',\n';
  lines += inner + '"outcome": ' + quote(event.outcome) + ',\n';
  lines += inner + '"phrase": ' + quote(event.phrase) + ',\n';
  lines += inner + '"occurredAt": ' + quote(event.occurredAt) + ',\n';
  lines += inner + '"ruleId": ' + quote(event.ruleId) + ',\n';
  lines += inner + '"baselineClause": ' + quote(event.baselineClause) + ',\n';
  lines += inner + '"threatId": ' + quote(event.threatId) + ',\n';
  lines += inner + '"threatStatus": ' + quote(event.threatStatus) + ',\n';
  lines += inner + '"registeredAt": ' + quote(event.registeredAt) + ',\n';
  lines += inner + '"evidenceNo": ' + quote(event.evidenceNo) + ',\n';
  lines += inner + '"source": ' + quote(event.source) + ',\n';
  lines += inner + '"detail": ' + quote(event.detail) + '\n';
  lines += pad + '}';
  return lines;
}

const RECORDER: string = 'com.jinyinhu.securitycenter';

export function encodeProbeEvents(findings: Finding[], runs: ProbeRun[], deviceId: string, imageVersion: string): D4Event[] {
  let events: D4Event[] = [];
  if (findings === undefined || runs === undefined) {
    return events;
  }
  let version = cleanVersion(imageVersion);
  if (version.length === 0) {
    return events;
  }
  let device = cleanDevice(deviceId);
  for (let i = 0; i < findings.length; i++) {
    let event = encodeOne(findings[i], runs, device, version, events.length + 1);
    if (event !== undefined) {
      events.push(event);
    }
  }
  return events;
}

function encodeOne(finding: Finding, runs: ProbeRun[], deviceId: string, imageVersion: string, seq: number): D4Event | undefined {
  if (finding === undefined || finding.scenarioId === 'C1' || finding.findingId === 'FND-C1') {
    return undefined;
  }
  let probeId = '';
  if (finding.scenarioId === 'A1' && finding.findingId === 'FND-A1') {
    probeId = 'P1';
  } else if (finding.scenarioId === 'B1' && finding.findingId === 'FND-B1') {
    probeId = 'P2';
  } else {
    return undefined;
  }
  let status = fileStatus(finding);
  if (status.length === 0) {
    return undefined;
  }
  let run = matchingRun(runs, probeId, status);
  if (run === undefined) {
    return undefined;
  }
  if (run.imageRole !== 'base' && run.imageRole !== 'secure') {
    return undefined;
  }
  if (run.verdict !== 'hit' && run.verdict !== 'blocked') {
    return undefined;
  }
  if (run.phrase.length === 0 || run.phrase.length > 12 || run.phrase.indexOf('\n') >= 0 || run.phrase.indexOf('\r') >= 0) {
    return undefined;
  }
  let event = new D4Event();
  event.schema = BuildInfo.schemaEvent;
  event.schemaVersion = BuildInfo.schemaVersion;
  event.eventId = eventIdFor(finding.findingId, run.createdAt);
  event.seq = seq;
  event.deviceId = deviceId;
  event.imageRole = run.imageRole;
  event.imageVersion = imageVersion;
  event.imageHashTail = '';
  event.appId = RECORDER;
  event.appVersion = BuildInfo.appVersion;
  event.scenarioId = finding.scenarioId;
  event.outcome = run.verdict === 'hit' ? 'succeeded' : 'blocked';
  event.phrase = run.phrase;
  event.occurredAt = run.createdAt;
  event.ruleId = clip(finding.ruleRef, 64);
  event.baselineClause = '';
  event.threatId = finding.findingId;
  event.threatStatus = status;
  event.registeredAt = status === 'mitigated' ? finding.registeredAt : clip(finding.registeredAt, 40);
  event.evidenceNo = status === 'mitigated' ? finding.evidenceNo : '';
  event.source = 'probe';
  event.detail = clip(finding.title, 280);
  if (validateEvent(event) !== '') {
    return undefined;
  }
  return event;
}

function fileStatus(finding: Finding): string {
  if (finding.status === 'open') {
    return 'open';
  }
  if (finding.status !== 'fixed-by-patch') {
    return '';
  }
  if (finding.registeredAt.length < 10 || finding.evidenceNo.length < 3) {
    return '';
  }
  if (finding.registeredAt.indexOf('\n') >= 0 || finding.evidenceNo.indexOf('\n') >= 0) {
    return '';
  }
  return 'mitigated';
}

function matchingRun(runs: ProbeRun[], probeId: string, status: string): ProbeRun | undefined {
  let newest = latestRun(runs, probeId, '');
  if (status !== 'mitigated' && newest !== undefined && newest.verdict === 'passive') {
    return undefined;
  }
  if (status === 'mitigated') {
    return latestSecureBlocked(runs, probeId);
  }
  let hit = latestRun(runs, probeId, 'hit');
  if (hit !== undefined) {
    return hit;
  }
  return latestRun(runs, probeId, 'blocked');
}

function latestSecureBlocked(runs: ProbeRun[], probeId: string): ProbeRun | undefined {
  let best: ProbeRun | undefined = undefined;
  for (let i = 0; i < runs.length; i++) {
    let run = runs[i];
    if (run === undefined || run.probeId !== probeId || run.verdict !== 'blocked' || run.imageRole !== 'secure') {
      continue;
    }
    if (!acceptProbeRun(probeId, run).ok) {
      continue;
    }
    if (best === undefined || run.createdAt >= best.createdAt) {
      best = run;
    }
  }
  return best;
}

function latestRun(runs: ProbeRun[], probeId: string, verdict: string): ProbeRun | undefined {
  let best: ProbeRun | undefined = undefined;
  for (let i = 0; i < runs.length; i++) {
    let run = runs[i];
    if (run === undefined || run.probeId !== probeId) {
      continue;
    }
    if (verdict.length > 0 && run.verdict !== verdict) {
      continue;
    }
    if (!acceptProbeRun(probeId, run).ok) {
      continue;
    }
    if (best === undefined || run.createdAt >= best.createdAt) {
      best = run;
    }
  }
  return best;
}

function eventIdFor(findingId: string, at: string): string {
  return clip('probe-' + findingId + '-' + at, 80);
}

function clip(value: string, max: number): string {
  if (typeof value !== 'string') {
    return '';
  }
  if (value.length <= max) {
    return value;
  }
  return value.substring(0, max);
}

function cleanDevice(deviceId: string): string {
  let trimmed = '';
  if (typeof deviceId === 'string') {
    trimmed = deviceId.trim();
  }
  if (trimmed.length === 0 || trimmed.length > 64 || trimmed.indexOf('\n') >= 0 || trimmed.indexOf('\r') >= 0) {
    return RECORDER;
  }
  return trimmed;
}

function cleanVersion(imageVersion: string): string {
  if (typeof imageVersion !== 'string') {
    return '';
  }
  let trimmed = imageVersion.trim();
  if (trimmed.length === 0 || trimmed.length > 32 || trimmed.indexOf('\n') >= 0) {
    return '';
  }
  return trimmed;
}

export class ArchiveRestore {
  ok: boolean = false;
  message: string = '';
  findings: Finding[] = [];
  runs: ProbeRun[] = [];
}

class RestoredPair {
  finding: Finding = new Finding();
  run: ProbeRun = new ProbeRun();
}

export function restoreArchive(events: D4Event[]): ArchiveRestore {
  let result = new ArchiveRestore();
  if (events === undefined || events.length === 0) {
    result.message = '文件里没有记录';
    return result;
  }
  let deviceId = events[0].deviceId;
  let imageVersion = events[0].imageVersion;
  let findings: Finding[] = [];
  let runs: ProbeRun[] = [];
  let seenA = false;
  let seenB = false;
  for (let i = 0; i < events.length; i++) {
    let event = events[i];
    if (event.deviceId !== deviceId || event.imageVersion !== imageVersion) {
      result.message = '第 ' + (i + 1).toString() + ' 条与归档上下文不一致';
      return result;
    }
    let built = rebuildOne(event);
    if (built === undefined) {
      result.message = '第 ' + (i + 1).toString() + ' 条不能还原成台账记录';
      return result;
    }
    if (built.finding.findingId === 'FND-A1') {
      if (seenA) {
        result.message = '安装信任链重复';
        return result;
      }
      seenA = true;
    } else if (seenB) {
      result.message = '沙箱隔离重复';
      return result;
    } else {
      seenB = true;
    }
    findings.push(built.finding);
    runs.push(built.run);
  }
  let ordered = orderFindings(findings);
  if (parseFindings(formatFindings(ordered)) === undefined) {
    result.message = '台账无法写入';
    return result;
  }
  let encoded = encodeProbeEvents(ordered, runs, deviceId, imageVersion);
  if (!sameGroup(events, encoded)) {
    result.message = '不能还原成同一组记录';
    return result;
  }
  result.ok = true;
  result.findings = ordered;
  result.runs = runs;
  result.message = '已恢复 ' + events.length.toString() + ' 条';
  return result;
}

function rebuildOne(event: D4Event): RestoredPair | undefined {
  if (event.source !== 'probe' || (event.scenarioId !== 'A1' && event.scenarioId !== 'B1')) {
    return undefined;
  }
  if (event.outcome !== 'succeeded' && event.outcome !== 'blocked') {
    return undefined;
  }
  if (event.threatStatus !== 'open' && event.threatStatus !== 'mitigated') {
    return undefined;
  }
  if (event.threatStatus === 'mitigated' && event.imageRole !== 'secure') {
    return undefined;
  }
  if (event.imageRole !== 'base' && event.imageRole !== 'secure') {
    return undefined;
  }
  if (!isStamp(event.occurredAt) || !isStamp(event.registeredAt)) {
    return undefined;
  }
  if (event.threatStatus === 'open' && event.evidenceNo !== '') {
    return undefined;
  }
  let probeId: 'P1' | 'P2' = event.scenarioId === 'A1' ? 'P1' : 'P2';
  let finding = new Finding();
  finding.findingId = probeId === 'P1' ? 'FND-A1' : 'FND-B1';
  finding.scenarioId = event.scenarioId;
  finding.title = probeId === 'P1' ? '安装信任链' : '沙箱隔离';
  finding.affectedApp = 'com.jinyinhu.lakesidenotes';
  finding.ruleRef = probeId === 'P1' ?
    'hap_verify_v2.cpp:1010-1023; hap_verify_v2.cpp:960-988' :
    'sandbox_helper.cpp:532-552; file_uri.cpp:154-200';
  finding.registeredAt = event.registeredAt;
  if (event.threatStatus === 'mitigated') {
    finding.status = 'fixed-by-patch';
    finding.evidenceNo = event.evidenceNo;
    finding.patchRef = probeId === 'P1' ? '安全镜像已含该修复' : 'open';
  } else {
    finding.status = 'open';
    finding.evidenceNo = '';
    finding.patchRef = 'open';
  }
  let run = new ProbeRun();
  run.probeId = probeId;
  run.verdict = event.outcome === 'succeeded' ? 'hit' : 'blocked';
  run.level = probeId === 'P1' ? 'L2' : 'L1';
  run.imageRole = event.imageRole;
  run.phrase = event.phrase;
  run.createdAt = event.occurredAt;
  if (!acceptProbeRun(probeId, run).ok) {
    return undefined;
  }
  let pair = new RestoredPair();
  pair.finding = finding;
  pair.run = run;
  return pair;
}

function orderFindings(findings: Finding[]): Finding[] {
  let ordered: Finding[] = [];
  for (let i = 0; i < findings.length; i++) {
    if (findings[i].findingId === 'FND-A1') {
      ordered.push(findings[i]);
    }
  }
  for (let i = 0; i < findings.length; i++) {
    if (findings[i].findingId === 'FND-B1') {
      ordered.push(findings[i]);
    }
  }
  return ordered;
}

function sameGroup(original: D4Event[], encoded: D4Event[]): boolean {
  if (original.length !== encoded.length) {
    return false;
  }
  for (let i = 0; i < original.length; i++) {
    let found = false;
    for (let j = 0; j < encoded.length; j++) {
      if (sameEvent(original[i], encoded[j])) {
        found = true;
      }
    }
    if (!found) {
      return false;
    }
  }
  return true;
}

function sameEvent(left: D4Event, right: D4Event): boolean {
  return left.eventId === right.eventId &&
    left.deviceId === right.deviceId &&
    left.imageRole === right.imageRole &&
    left.imageVersion === right.imageVersion &&
    left.scenarioId === right.scenarioId &&
    left.outcome === right.outcome &&
    left.phrase === right.phrase &&
    left.occurredAt === right.occurredAt &&
    left.threatStatus === right.threatStatus &&
    left.registeredAt === right.registeredAt &&
    left.evidenceNo === right.evidenceNo &&
    left.source === right.source;
}

export function formatBundle(events: D4Event[]): string {
  let lines = '{\n';
  lines += '  "schema": ' + quote(BuildInfo.schemaBundle) + ',\n';
  lines += '  "schemaVersion": ' + quote(BuildInfo.schemaVersion) + ',\n';
  lines += '  "exportedAt": ' + quote(nowIso()) + ',\n';
  lines += '  "note": ' + quote(BuildInfo.bundleNote) + ',\n';
  lines += '  "events": [\n';
  for (let i = 0; i < events.length; i++) {
    lines += formatEvent(events[i], '    ');
    if (i + 1 < events.length) {
      lines += ',\n';
    } else {
      lines += '\n';
    }
  }
  lines += '  ]\n}\n';
  return lines;
}

function readEvents(items: D4Event[]): ParseResult {
  let result = new ParseResult();
  if (items.length > 200) {
    result.message = '一次最多交换 200 条记录';
    return result;
  }
  let seen: string[] = [];
  let messages: string[] = [];
  for (let i = 0; i < items.length; i++) {
    let event = copyEvent(items[i] as D4Event);
    let problem = validateEvent(event);
    let where = '第 ' + (i + 1).toString() + ' 条';
    if (problem !== '') {
      result.skipped++;
      messages.push(where + '已跳过：' + problem);
      continue;
    }
    let duplicated = false;
    for (let j = 0; j < seen.length; j++) {
      if (seen[j] === event.eventId) {
        duplicated = true;
      }
    }
    if (duplicated) {
      result.skipped++;
      messages.push(where + '已跳过：事件编号重复');
      continue;
    }
    seen.push(event.eventId);
    result.events.push(event);
  }
  result.ok = result.events.length > 0 || items.length === 0;
  if (items.length === 0) {
    result.message = '文件里没有记录';
    result.ok = true;
    return result;
  }
  if (result.events.length === 0) {
    result.ok = false;
    result.message = messages.length > 0 ? messages[0] : '没有可导入的记录';
    return result;
  }
  result.message = '可读 ' + result.events.length.toString() + ' 条';
  if (messages.length > 0) {
    result.message = result.message + '，' + messages[0];
  }
  return result;
}

export function parseBundle(raw: string): ParseResult {
  let result = new ParseResult();
  if (raw.length === 0) {
    result.message = '文件是空的';
    return result;
  }
  if (raw.length > 1000000) {
    result.message = '文件超过 1MB';
    return result;
  }
  let trimmed = raw.trim();
  if (trimmed.charAt(0) === '\uFEFF') {
    trimmed = trimmed.substring(1).trim();
  }
  try {
    if (trimmed.charAt(0) === '[') {
      let items = JSON.parse(trimmed) as D4Event[];
      if (!(items instanceof Array)) {
        result.message = '不是记录数组';
        return result;
      }
      return readEvents(items);
    }
    let bundle = JSON.parse(trimmed) as BundlePeek;
    if (bundle.schema !== BuildInfo.schemaBundle || bundle.schemaVersion !== BuildInfo.schemaVersion) {
      result.message = '不是本阶段的 D4 交换文件';
      return result;
    }
    if (!(bundle.events instanceof Array)) {
      result.message = '交换文件缺少 events 数组';
      return result;
    }
    return readEvents(bundle.events);
  } catch (err) {
    hilog.error(0x4A59, 'D4Codec', 'parse %{public}s', JSON.stringify(err));
    result.message = '不是合法的 JSON';
    return result;
  }
}

function formatCard(card: BoardCard, pad: string): string {
  let inner = pad + '  ';
  return pad + '{\n' +
    inner + '"role": ' + quote(card.role) + ',\n' +
    inner + '"title": ' + quote(card.title) + ',\n' +
    inner + '"deviceId": ' + quote(card.deviceId) + ',\n' +
    inner + '"imageVersion": ' + quote(card.imageVersion) + ',\n' +
    inner + '"hashTail": ' + quote(card.hashTail) + ',\n' +
    inner + '"appVersion": ' + quote(card.appVersion) + '\n' +
    pad + '}';
}

export function formatBoards(pair: BoardPair): string {
  return '{\n' +
    '  "schema": "jinyinhu.board.pair",\n' +
    '  "schemaVersion": "0.1",\n' +
    '  "vanilla": ' + formatCard(pair.vanilla, '  ') + ',\n' +
    '  "secure": ' + formatCard(pair.secure, '  ') + '\n' +
    '}\n';
}

function copyCard(raw: BoardPeek, expectedRole: string): BoardCard | undefined {
  let card = new BoardCard();
  card.role = textOf(raw.role);
  card.title = textOf(raw.title);
  card.deviceId = textOf(raw.deviceId);
  card.imageVersion = textOf(raw.imageVersion);
  card.hashTail = textOf(raw.hashTail).toUpperCase();
  card.appVersion = textOf(raw.appVersion);
  if (card.role !== expectedRole) {
    return undefined;
  }
  if (card.title.length < 1 || card.title.length > 20) {
    return undefined;
  }
  if (card.deviceId.length < 1 || card.deviceId.length > 64) {
    return undefined;
  }
  if (card.imageVersion.length < 1 || card.imageVersion.length > 32) {
    return undefined;
  }
  if (!isHexTail(card.hashTail)) {
    return undefined;
  }
  if (card.appVersion.length < 1 || card.appVersion.length > 32) {
    return undefined;
  }
  return card;
}

export function parseBoards(raw: string): BoardPair | undefined {
  try {
    let parsed = JSON.parse(raw) as PairPeek;
    if (parsed.schema !== 'jinyinhu.board.pair' || parsed.schemaVersion !== '0.1') {
      return undefined;
    }
    let vanilla = copyCard(parsed.vanilla, 'vanilla-demo');
    let secure = copyCard(parsed.secure, 'secure');
    if (vanilla === undefined || secure === undefined) {
      return undefined;
    }
    let pair = defaultBoards();
    pair.vanilla = vanilla;
    pair.secure = secure;
    return pair;
  } catch (err) {
    hilog.error(0x4A59, 'D4Codec', 'boards %{public}s', JSON.stringify(err));
    return undefined;
  }
}
