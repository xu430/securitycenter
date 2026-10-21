import type { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import bundleManager from '@ohos.bundle.bundleManager';
import { LiveStore } from '../model/LiveStore';
import { nowIso } from '../model/D4Types';
import type { Evidence, EvidenceKind, Probe, ProbeId, ProbeResult, ProbeShelf, ProofLevel, SidecarReport, SidecarStep, Verdict } from './ProbeTypes';
import { ANOMALY_PHRASE, INSTALL_CLEAR_PHRASE, NO_ANOMALY_PHRASE, ProbeEvidence, ProbeLimits, ProbeRun, SYSTEM_REJECT_PHRASE, VERIFY_REJECT_CODE } from './ProbeTypes';
import { clearRejectFile, loadRejectCode } from './UpdateReject';

const DOMAIN = 0x4A59;
const TAG = 'InstallProbe';

export const LAKESIDE_BUNDLE: string = 'com.jinyinhu.lakesidenotes';
export const OFFICIAL_VERSION: number = 1000000;
export const DOPPEL_VERSION: number = 1000001;
export const HIT_PHRASE: string = '安装器收下了伪造';
export const BLOCKED_PHRASE: string = '安装器拒绝了伪造';
export const DISCLOSURE_PHRASE: string = '基础版未收下';
export const PATCH_LINE: string = 'hap_verify_v2.cpp:1010-1023';
export const PROFILE_LINE: string = 'hap_verify_v2.cpp:960-988';
export const IMPORT_FAULT: string = '导入失败';
export const READBACK_FAULT: string = '读回失败';
export const MISMATCH_FAULT: string = '读回与态2不一致';
export const MATRIX_FAULT: string = '侧车缺少三态回显';
export const TRANSCRIPT_FAULT: string = '命令回显不是全量';
export const DUMP_FAULT: string = '侧车缺少态2版本';
const VERSION_KEY: string = '"versionCode"';

export class InstallIntegrityProbe implements Probe {
  id: ProbeId = 'P1';
  title: string = '安装完整性';
  risk: string = '检测是否有恶意安装包，是否有绕过安装等风险';
  level: ProofLevel = 'L2';

  async run(ctx: common.UIAbilityContext): Promise<ProbeResult> {
    let shelf = LiveStore.shelf();
    let versionCode = installedVersion();
    let caught = judgeDoppelInstalled(versionCode, nowIso());
    if (caught !== undefined) {
      clearRejectFile(filesDirOf(ctx));
      return caught;
    }
    let block = blockedImport(shelf);
    if (block.length === 0) {
      if (versionCode < 0) {
        throw new Error(READBACK_FAULT);
      }
      return judgeInstall(shelf.sidecar, versionCode, nowIso());
    }
    let rejected = judgeSystemRejected(versionCode, nowIso(), loadRejectCode(filesDirOf(ctx)));
    if (rejected !== undefined) {
      return rejected;
    }
    if (block === IMPORT_FAULT) {
      return judgeNoAnomaly(versionCode, nowIso());
    }
    throw new Error(block);
  }
}

export function blockedImport(shelf: ProbeShelf): string {
  if (shelf.failureReason.length > 0) {
    return shelf.failureReason;
  }
  if (!shelf.sidecarPresent || shelf.importState !== ProbeLimits.importImported) {
    return IMPORT_FAULT;
  }
  return '';
}

export function doppelInstalled(): boolean {
  try {
    return readLakesideVersion() === DOPPEL_VERSION;
  } catch (err) {
    return false;
  }
}

export function installedVersion(): number {
  try {
    return readLakesideVersion();
  } catch (err) {
    return -1;
  }
}

export function judgeSystemRejected(versionCode: number, createdAt: string, code: number): ProbeResult | undefined {
  if (versionCode !== OFFICIAL_VERSION || code !== VERIFY_REJECT_CODE) {
    return undefined;
  }
  let result = new ProbeRun();
  result.probeId = 'P1';
  result.verdict = 'passive';
  result.phrase = SYSTEM_REJECT_PHRASE;
  result.level = 'L2';
  result.imageRole = 'secure';
  result.createdAt = createdAt;
  let rows: Evidence[] = [];
  rows.push(evidence('bundle-state', '读回 versionCode=' + versionCode.toString(),
    'readbackVersionCode=' + versionCode.toString(), createdAt));
  rows.push(evidence('hilog-line', '系统拒绝了这次更新', 'verifyCode=' + code.toString(), createdAt));
  rows.push(evidence('source-ref', '安装验签两处', PATCH_LINE, createdAt));
  result.evidences = rows;
  return result;
}

export function judgeInstallIntact(versionCode: number, createdAt: string): ProbeResult | undefined {
  if (versionCode !== OFFICIAL_VERSION) {
    return undefined;
  }
  let result = new ProbeRun();
  result.probeId = 'P1';
  result.verdict = 'blocked';
  result.phrase = INSTALL_CLEAR_PHRASE;
  result.level = 'L2';
  result.imageRole = 'secure';
  result.createdAt = createdAt;
  let rows: Evidence[] = [];
  rows.push(evidence('bundle-state', '读回 versionCode=' + versionCode.toString(),
    'readbackVersionCode=' + versionCode.toString(), createdAt));
  rows.push(evidence('source-ref', '安装验签两处', PATCH_LINE, createdAt));
  result.evidences = rows;
  return result;
}

export function replaceImportFault(reason: string, sandboxVerdict: string, versionCode: number,
  rejectCode: number): boolean {
  if (reason !== IMPORT_FAULT || sandboxVerdict !== 'blocked' || versionCode !== OFFICIAL_VERSION) {
    return false;
  }
  return rejectCode !== VERIFY_REJECT_CODE;
}

export function judgeNoAnomaly(versionCode: number, createdAt: string): ProbeResult {
  let result = new ProbeRun();
  result.probeId = 'P1';
  result.verdict = 'blocked';
  result.phrase = NO_ANOMALY_PHRASE;
  result.level = 'L2';
  result.imageRole = '';
  result.createdAt = createdAt;
  let shown = versionCode < 0 ? '未安装' : versionCode.toString();
  let rows: Evidence[] = [];
  rows.push(evidence('bundle-state', '读回 versionCode=' + shown, 'readbackVersionCode=' + shown, createdAt));
  result.evidences = rows;
  return result;
}

export function judgeDoppelInstalled(versionCode: number, createdAt: string): ProbeResult | undefined {
  if (versionCode !== DOPPEL_VERSION) {
    return undefined;
  }
  let result = new ProbeRun();
  result.probeId = 'P1';
  result.verdict = 'hit';
  result.phrase = ANOMALY_PHRASE;
  result.level = 'L2';
  result.imageRole = 'base';
  result.createdAt = createdAt;
  let rows: Evidence[] = [];
  rows.push(evidence('bundle-state', '读回 versionCode=' + versionCode.toString(),
    'readbackVersionCode=' + versionCode.toString(), createdAt));
  rows.push(evidence('source-ref', '安装验签两处', PATCH_LINE, createdAt));
  result.evidences = rows;
  return result;
}

function filesDirOf(ctx: common.UIAbilityContext): string {
  if (ctx === undefined || typeof ctx.filesDir !== 'string') {
    return '';
  }
  return ctx.filesDir;
}

function readLakesideVersion(): number {
  let versionCode = 0;
  try {
    let info = bundleManager.getBundleInfoSync(LAKESIDE_BUNDLE, bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
    versionCode = info.versionCode;
  } catch (err) {
    hilog.error(DOMAIN, TAG, 'bundle %{public}s', JSON.stringify(err));
    throw new Error(READBACK_FAULT);
  }
  if (typeof versionCode !== 'number' || versionCode !== versionCode || versionCode % 1 !== 0) {
    throw new Error(READBACK_FAULT);
  }
  return versionCode;
}

export function judgeInstall(report: SidecarReport, versionCode: number, createdAt: string): ProbeResult {
  if (versionCode !== versionCode || versionCode % 1 !== 0) {
    throw new Error(READBACK_FAULT);
  }
  let first = stepOf(report, 1);
  let second = stepOf(report, 2);
  let third = stepOf(report, 3);
  if (first === undefined || second === undefined || third === undefined) {
    throw new Error(MATRIX_FAULT);
  }
  if (!transcriptFull(first) || !transcriptFull(second) || !transcriptFull(third)) {
    throw new Error(TRANSCRIPT_FAULT);
  }
  let dumped = readDumpVersion(second.transcript);
  if (!dumped.ok) {
    throw new Error(DUMP_FAULT);
  }
  let verdict: Verdict = 'passive';
  let phrase = DISCLOSURE_PHRASE;
  let level: ProofLevel = 'L3';
  let dumpVersion = dumped.versionCode;
  if (report.imageTag === 'base' && second.retCode === 0 && dumpVersion === DOPPEL_VERSION && versionCode === OFFICIAL_VERSION) {
    verdict = 'hit';
    phrase = HIT_PHRASE;
    level = 'L2';
  } else if (report.imageTag === 'secure' && second.retCode !== 0 && dumpVersion === OFFICIAL_VERSION && versionCode === OFFICIAL_VERSION) {
    verdict = 'blocked';
    phrase = BLOCKED_PHRASE;
    level = 'L2';
  } else if (report.imageTag === 'base' && second.retCode !== 0 && dumpVersion === OFFICIAL_VERSION && versionCode === OFFICIAL_VERSION) {
    verdict = 'passive';
    phrase = DISCLOSURE_PHRASE;
    level = 'L3';
  } else {
    throw new Error(MISMATCH_FAULT);
  }
  let result = new ProbeRun();
  result.probeId = 'P1';
  result.verdict = verdict;
  result.phrase = phrase;
  result.level = level;
  result.imageRole = report.imageTag === 'secure' ? 'secure' : 'base';
  result.createdAt = createdAt;
  result.evidences = fourEvidences(report, first, second, third, dumpVersion, versionCode, createdAt);
  return result;
}

function stepOf(report: SidecarReport, state: number): SidecarStep | undefined {
  for (let i = 0; i < report.matrix.length; i++) {
    if (report.matrix[i].state === state) {
      return report.matrix[i];
    }
  }
  return undefined;
}

function fourEvidences(report: SidecarReport, first: SidecarStep, second: SidecarStep, third: SidecarStep,
  dumpVersion: number, readback: number, at: string): Evidence[] {
  let rows: Evidence[] = [];
  rows.push(evidence('cmd-transcript', '三态命令回显', transcripts(first, second, third), at));
  rows.push(evidence('sidecar-state', '三态返回码与板时钟', sidecarRaw(report, first, second, third), at));
  rows.push(evidence('bundle-state', bundleText(dumpVersion, readback), bundleRaw(dumpVersion, readback), at));
  rows.push(evidence('source-ref', '安装验签两处', PATCH_LINE + '; ' + PROFILE_LINE, at));
  return rows;
}

function evidence(kind: EvidenceKind, text: string, raw: string, at: string): Evidence {
  let row = new ProbeEvidence();
  row.kind = kind;
  row.text = text;
  row.raw = raw;
  row.at = at;
  return row;
}

function transcripts(first: SidecarStep, second: SidecarStep, third: SidecarStep): string {
  let body = '态1 ' + first.cmd + '\n' + first.transcript + '\n' +
    '态2 ' + second.cmd + '\n' + second.transcript + '\n' +
    '态3 ' + third.cmd + '\n' + third.transcript;
  if (body.length > ProbeLimits.rawMax) {
    return body.substring(0, ProbeLimits.rawMax);
  }
  return body;
}

function sidecarRaw(report: SidecarReport, first: SidecarStep, second: SidecarStep, third: SidecarStep): string {
  return '{"imageTag":"' + report.imageTag + '","boardClockAtRun":"' + report.boardClockAtRun + '",' +
    '"matrix":[' +
    '{"state":1,"retCode":' + first.retCode.toString() + '},' +
    '{"state":2,"retCode":' + second.retCode.toString() + '},' +
    '{"state":3,"retCode":' + third.retCode.toString() + '}' +
    ']}';
}

function bundleText(dumpVersion: number, readback: number): string {
  return LAKESIDE_BUNDLE + ' 态2 versionCode=' + dumpVersion.toString() + ' 读回 versionCode=' + readback.toString();
}

function bundleRaw(dumpVersion: number, readback: number): string {
  return 'state2VersionCode=' + dumpVersion.toString() + ' readbackVersionCode=' + readback.toString();
}

function transcriptFull(step: SidecarStep): boolean {
  return step.transcript.trim().length > 0;
}

class DumpRead {
  ok: boolean = false;
  versionCode: number = 0;
}

class TokenRead {
  ok: boolean = false;
  versionCode: number = 0;
  next: number = 0;
}

function readDumpVersion(transcript: string): DumpRead {
  let read = new DumpRead();
  let seen = false;
  let value = 0;
  let i = 0;
  while (i < transcript.length) {
    let at = transcript.indexOf(VERSION_KEY, i);
    if (at < 0) {
      break;
    }
    let token = readVersionToken(transcript, at + VERSION_KEY.length);
    if (!token.ok) {
      i = at + VERSION_KEY.length;
      continue;
    }
    if (seen && value !== token.versionCode) {
      return read;
    }
    seen = true;
    value = token.versionCode;
    i = token.next;
  }
  if (!seen) {
    return read;
  }
  read.ok = true;
  read.versionCode = value;
  return read;
}

function readVersionToken(transcript: string, start: number): TokenRead {
  let token = new TokenRead();
  let j = skipSpace(transcript, start);
  if (j >= transcript.length || transcript.charAt(j) !== ':') {
    return token;
  }
  j = skipSpace(transcript, j + 1);
  if (j >= transcript.length || transcript.charAt(j) < '0' || transcript.charAt(j) > '9') {
    return token;
  }
  if (transcript.charAt(j) === '0') {
    let after = j + 1;
    if (after < transcript.length && transcript.charAt(after) >= '0' && transcript.charAt(after) <= '9') {
      return token;
    }
    token.ok = true;
    token.versionCode = 0;
    token.next = after;
    return token;
  }
  let n = 0;
  let digits = 0;
  while (j < transcript.length && transcript.charAt(j) >= '0' && transcript.charAt(j) <= '9') {
    digits++;
    if (digits > 9) {
      return token;
    }
    n = n * 10 + transcript.charCodeAt(j) - '0'.charCodeAt(0);
    j++;
  }
  token.ok = true;
  token.versionCode = n;
  token.next = j;
  return token;
}

function skipSpace(transcript: string, index: number): number {
  let j = index;
  while (j < transcript.length) {
    let ch = transcript.charAt(j);
    if (ch !== ' ' && ch !== '\t' && ch !== '\n' && ch !== '\r') {
      break;
    }
    j++;
  }
  return j;
}
