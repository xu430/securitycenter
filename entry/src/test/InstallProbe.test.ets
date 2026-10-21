import { DISCLOSURE_NOTE, formatFindings, nextFindings, parseFindings } from '../main/ets/report/Findings';
import { acceptProbeRun, applyImportFailure, applyKeepSidecar } from '../main/ets/probe/ProbeCodec';
import {
  BLOCKED_PHRASE,
  DISCLOSURE_PHRASE,
  DOPPEL_VERSION,
  DUMP_FAULT,
  HIT_PHRASE,
  LAKESIDE_BUNDLE,
  MATRIX_FAULT,
  MISMATCH_FAULT,
  OFFICIAL_VERSION,
  PATCH_LINE,
  PROFILE_LINE,
  TRANSCRIPT_FAULT,
  blockedImport,
  judgeDoppelInstalled,
  judgeInstall,
  judgeInstallIntact,
  judgeSystemRejected,
  replaceImportFault
} from '../main/ets/probe/InstallIntegrityProbe';
import { canonicalRejectCode, parseRejectCode } from '../main/ets/probe/UpdateReject';
import { SidecarReport, SidecarStep, emptyProbeShelf } from '../main/ets/probe/ProbeTypes';

const AT = '2026-10-15T16:00:00+08:00';
const LATER = '2026-10-15T16:05:00+08:00';

function fail(message: string): void {
  throw new Error(message);
}

function step(state: number, retCode: number, dumpVersion: number): SidecarStep {
  let row = new SidecarStep();
  row.state = state;
  row.desc = '态' + state.toString();
  row.cmd = 'hdc install -r lakeside-notes.hap';
  row.retCode = retCode;
  row.transcript = 'hdc install 态' + state.toString();
  if (state === 2) {
    row.transcript = 'versionCode=' + dumpVersion.toString() + '\n' +
      'expectedVersionCode=' + dumpVersion.toString() + '\n' +
      'verify=pass\n--- hdc install ---\ninstall bundle finished.\n' +
      '--- bm dump -n com.jinyinhu.lakesidenotes exit 0 ---\n' +
      '{"versionCode": ' + dumpVersion.toString() + ', "name": "com.jinyinhu.lakesidenotes"}';
  }
  row.at = AT;
  return row;
}

function report(tag: string, retCode: number, dumpVersion: number): SidecarReport {
  let row = new SidecarReport();
  row.imageTag = tag;
  row.boardClockAtRun = AT;
  let matrix: SidecarStep[] = [];
  matrix.push(step(1, 0, OFFICIAL_VERSION));
  matrix.push(step(2, retCode, dumpVersion));
  matrix.push(step(3, 0, OFFICIAL_VERSION));
  row.matrix = matrix;
  return row;
}

function kindAt(resultKinds: string[], kind: string): boolean {
  for (let i = 0; i < resultKinds.length; i++) {
    if (resultKinds[i] === kind) {
      return true;
    }
  }
  return false;
}

export function runInstallChecks(): void {
  let replaced = judgeDoppelInstalled(DOPPEL_VERSION, AT);
  if (replaced === undefined || replaced.verdict !== 'hit' || replaced.phrase !== '发现异常' || replaced.level !== 'L2') {
    fail('读回 1000001 应直接判为发现异常');
  }
  if (replaced.evidences.length < 1 || replaced.evidences[0].raw.indexOf(DOPPEL_VERSION.toString()) < 0) {
    fail('读回证据应写上 1000001');
  }
  if (!acceptProbeRun('P1', replaced).ok) {
    fail('读回结论应能写入探针记录');
  }
  if (judgeDoppelInstalled(OFFICIAL_VERSION, AT) !== undefined) {
    fail('读回仍是正版时不能靠版本号判红');
  }
  let hit = judgeInstall(report('base', 0, DOPPEL_VERSION), OFFICIAL_VERSION, AT);
  if (hit.verdict !== 'hit' || hit.level !== 'L2' || hit.phrase !== HIT_PHRASE || hit.imageRole !== 'base') {
    fail('基础版态 2 收下、dump 为 1000001、读回已恢复 1000000 应判红');
  }
  if (hit.phrase.length > 12 || hit.phrase.indexOf('得手') >= 0 || hit.phrase.indexOf('阻断') >= 0) {
    fail('短语应不超过 12 字');
  }
  if (hit.evidences.length !== 4) {
    fail('判红需要四件证据');
  }
  let kinds: string[] = [];
  for (let i = 0; i < hit.evidences.length; i++) {
    kinds.push(hit.evidences[i].kind);
  }
  if (!kindAt(kinds, 'cmd-transcript') || !kindAt(kinds, 'sidecar-state') ||
    !kindAt(kinds, 'bundle-state') || !kindAt(kinds, 'source-ref')) {
    fail('四件证据种类不齐');
  }
  let named = false;
  let lines = false;
  let states = false;
  for (let i = 0; i < hit.evidences.length; i++) {
    let item = hit.evidences[i];
    if (item.kind === 'bundle-state' && item.text.indexOf(LAKESIDE_BUNDLE) >= 0 &&
      item.raw.indexOf('state2VersionCode=1000001') >= 0 && item.raw.indexOf('readbackVersionCode=1000000') >= 0) {
      named = true;
    }
    if (item.kind === 'source-ref' && item.raw.indexOf(PATCH_LINE) >= 0 && item.raw.indexOf(PROFILE_LINE) >= 0) {
      lines = true;
    }
    if (item.kind === 'cmd-transcript' && item.raw.indexOf('态1') >= 0 && item.raw.indexOf('态2') >= 0 && item.raw.indexOf('态3') >= 0) {
      states = true;
    }
    if (item.kind === 'sidecar-state' && (item.raw.indexOf('boardClockAtRun') < 0 || item.raw.indexOf('"imageTag":"base"') < 0)) {
      fail('侧车证据应带板时钟和镜像标签');
    }
  }
  if (!named || !lines || !states) {
    fail('湖畔笔记、补丁行或三态回显没有进证据');
  }
  if (!acceptProbeRun('P1', hit).ok) {
    fail('基础版判红应能落盘');
  }

  let blocked = judgeInstall(report('secure', 7, OFFICIAL_VERSION), OFFICIAL_VERSION, LATER);
  if (blocked.verdict !== 'blocked' || blocked.level !== 'L2' || blocked.phrase !== BLOCKED_PHRASE || blocked.imageRole !== 'secure') {
    fail('安全版拒绝且 dump 与读回都保持 1000000 应判绿');
  }
  if (!acceptProbeRun('P1', blocked).ok) {
    fail('安全版判绿应能落盘');
  }

  let disclosed = judgeInstall(report('base', 7, OFFICIAL_VERSION), OFFICIAL_VERSION, AT);
  if (disclosed.verdict !== 'passive' || disclosed.level !== 'L3' || disclosed.phrase !== DISCLOSURE_PHRASE) {
    fail('基础版态 2 被拒应降为展示，不能判绿');
  }
  if (disclosed.verdict === 'hit' || disclosed.verdict === 'blocked') {
    fail('基础版失败不能写成红或绿');
  }
  if (!acceptProbeRun('P1', disclosed).ok) {
    fail('降级披露应能落盘');
  }
  let opened = nextFindings([], disclosed);
  if (opened.findings.length !== 1 || opened.findings[0].findingId !== 'FND-A1' || opened.findings[0].status !== 'open') {
    fail('降级披露应留下未修复的 A1');
  }
  if (opened.findings[0].patchRef !== DISCLOSURE_NOTE || opened.findings[0].affectedApp !== LAKESIDE_BUNDLE) {
    fail('A1 备注应是基础版已由后续镜像修复验证');
  }
  let stored = parseFindings(formatFindings(opened.findings));
  if (stored === undefined || stored.length !== 1 || stored[0].patchRef !== DISCLOSURE_NOTE) {
    fail('降级备注应能按原句读回');
  }
  let dirty = formatFindings(opened.findings).replace(DISCLOSURE_NOTE, '得手');
  if (parseFindings(dirty) !== undefined) {
    fail('未修复项不能写入自由短语');
  }

  let red = nextFindings([], hit);
  let green = nextFindings(red.findings, blocked);
  if (green.findings.length !== 1 || green.findings[0].status !== 'fixed-by-patch' || green.findings[0].patchRef !== '安全镜像已含该修复') {
    fail('已有未修复项时，安全版拒绝应记为补丁修复');
  }
  if (nextFindings([], blocked).findings.length !== 0) {
    fail('没有先前的未修复项时，不能凭绿结果新开修复');
  }

  expectThrow(report('base', 0, DOPPEL_VERSION), DOPPEL_VERSION, MISMATCH_FAULT);
  expectThrow(report('base', 0, OFFICIAL_VERSION), OFFICIAL_VERSION, MISMATCH_FAULT);
  expectThrow(report('secure', 0, DOPPEL_VERSION), OFFICIAL_VERSION, MISMATCH_FAULT);
  expectThrow(report('secure', 7, DOPPEL_VERSION), OFFICIAL_VERSION, MISMATCH_FAULT);
  expectThrow(report('secure', 7, OFFICIAL_VERSION), DOPPEL_VERSION, MISMATCH_FAULT);
  expectThrow(report('base', 7, DOPPEL_VERSION), OFFICIAL_VERSION, MISMATCH_FAULT);
  let partial = report('base', 0, DOPPEL_VERSION);
  let kept: SidecarStep[] = [];
  kept.push(partial.matrix[0]);
  kept.push(partial.matrix[1]);
  partial.matrix = kept;
  expectThrow(partial, OFFICIAL_VERSION, MATRIX_FAULT);
  let blank = report('base', 0, DOPPEL_VERSION);
  blank.matrix[1].transcript = '';
  expectThrow(blank, OFFICIAL_VERSION, TRANSCRIPT_FAULT);
  blank.matrix[1].transcript = '   ';
  expectThrow(blank, OFFICIAL_VERSION, TRANSCRIPT_FAULT);
  blank.matrix[1].transcript = report('base', 0, DOPPEL_VERSION).matrix[1].transcript;
  blank.matrix[0].transcript = '';
  expectThrow(blank, OFFICIAL_VERSION, TRANSCRIPT_FAULT);
  let headerOnly = report('base', 0, DOPPEL_VERSION);
  headerOnly.matrix[1].transcript = 'versionCode=1000001\nexpectedVersionCode=1000001\nverify=pass\n';
  expectThrow(headerOnly, OFFICIAL_VERSION, DUMP_FAULT);
  let conflict = report('base', 0, DOPPEL_VERSION);
  conflict.matrix[1].transcript = '{"versionCode": 1000001}\n{"versionCode": 1000000}';
  expectThrow(conflict, OFFICIAL_VERSION, DUMP_FAULT);
  let repeated = report('base', 0, DOPPEL_VERSION);
  repeated.matrix[1].transcript = '{"versionCode": 1000001}\n{"versionCode":1000001}';
  let repeatedHit = judgeInstall(repeated, OFFICIAL_VERSION, AT);
  if (repeatedHit.verdict !== 'hit') {
    fail('dump 里同一个 1000001 出现两次仍应判红');
  }
  let shelf = applyKeepSidecar(emptyProbeShelf(), report('base', 0, DOPPEL_VERSION), AT);
  if (blockedImport(shelf).length !== 0) {
    fail('成功导入不应挡住 P1');
  }
  let failed = applyImportFailure(shelf, '侧车报告不是合法的 JSON', LATER);
  if (!failed.sidecarPresent || failed.importState !== 'imported') {
    fail('失败不应清掉上一份侧车');
  }
  if (blockedImport(failed) !== '侧车报告不是合法的 JSON') {
    fail('失败应挡住下一次 P1');
  }
  let again = applyKeepSidecar(failed, report('base', 0, DOPPEL_VERSION), LATER);
  if (again.failureReason.length !== 0 || blockedImport(again).length !== 0) {
    fail('新的成功报告应放开 P1');
  }
  if (blockedImport(emptyProbeShelf()) !== '导入失败') {
    fail('没有侧车时应停在导入失败');
  }

  let rejected = judgeSystemRejected(OFFICIAL_VERSION, AT, 17700011);
  if (rejected === undefined || rejected.verdict !== 'passive' || rejected.phrase !== '系统拒绝了更新' ||
    rejected.imageRole !== 'secure' || rejected.level !== 'L2') {
    fail('安全版拒绝更新应记成一条需要留意');
  }
  if (!acceptProbeRun('P1', rejected).ok) {
    fail('系统拒绝应能落盘');
  }
  let noted = nextFindings([], rejected);
  if (noted.findings.length !== 1 || noted.findings[0].findingId !== 'FND-A1' || noted.findings[0].status !== 'open') {
    fail('系统拒绝应只留下安装信任链这一条');
  }
  if (judgeSystemRejected(OFFICIAL_VERSION, AT, 202) !== undefined ||
    judgeSystemRejected(DOPPEL_VERSION, AT, 17700011) !== undefined) {
    fail('非验签失败或伪造包已装上时不能写成系统拒绝');
  }
  let intact = judgeInstallIntact(OFFICIAL_VERSION, LATER);
  if (intact === undefined || intact.verdict !== 'blocked' || intact.phrase !== '安装包校验通过' || intact.imageRole !== 'secure') {
    fail('安全版尚未更新时应判安装包没有风险');
  }
  if (judgeInstallIntact(DOPPEL_VERSION, AT) !== undefined) {
    fail('伪造包已装上时不能判安装包通过');
  }
  let prior = nextFindings([], replaced);
  let closed = nextFindings(prior.findings, intact);
  if (!closed.changed || closed.findings.length !== 1 || closed.findings[0].status !== 'fixed-by-patch') {
    fail('安全版确认安装包无风险后应收口旧记录');
  }
  if (!replaceImportFault('导入失败', 'blocked', OFFICIAL_VERSION, -1)) {
    fail('沙箱已拒绝且没有更新失败记录时，应撤掉导入失败');
  }
  if (replaceImportFault('导入失败', 'blocked', OFFICIAL_VERSION, 17700011) ||
    replaceImportFault('导入失败', 'hit', OFFICIAL_VERSION, -1) ||
    replaceImportFault('读回失败', 'blocked', OFFICIAL_VERSION, -1)) {
    fail('已有系统拒绝、沙箱未拦住或不是导入失败时，不能改写成通过');
  }
  if (canonicalRejectCode(9568322) !== 17700011 || canonicalRejectCode(9568320) !== -1 || canonicalRejectCode(202) !== -1) {
    fail('只有验签失败才归一成系统拒绝');
  }
  if (parseRejectCode('{"code":17700011}') !== 17700011 || parseRejectCode('{"code":202}') !== -1) {
    fail('拒绝记录只接受验签失败');
  }
}

function expectThrow(row: SidecarReport, versionCode: number, message: string): void {
  let thrown = false;
  try {
    judgeInstall(row, versionCode, AT);
  } catch (err) {
    thrown = true;
    if (!(err instanceof Error) || err.message !== message) {
      fail('失败原因应为 ' + message);
    }
  }
  if (!thrown) {
    fail('不一致的读回不能给出红或绿');
  }
}
