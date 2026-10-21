import { nowIso } from '../main/ets/model/D4Types';
import {
  acceptProbeRun,
  acceptSidecar,
  applyAppendRun,
  applyImportFailure,
  applyKeepSidecar,
  formatProbeShelf,
  parseProbeShelf
} from '../main/ets/probe/ProbeCodec';
import { ProbeRun, ProbeLimits, emptyProbeShelf, isStamp } from '../main/ets/probe/ProbeTypes';

const AT = '2026-10-15T15:42:00+08:00';

function fail(message: string): void {
  throw new Error(message);
}

function step(state: number, ret: number): string {
  return '{"state":' + state.toString() + ',"desc":"官方签名","cmd":"hdc install","retCode":' +
    ret.toString() + ',"transcript":"ok","at":"' + AT + '"}';
}

function report(matrix: string, udid: string, schema: string, version: string): string {
  return '{"schema":"' + schema + '","schemaVersion":"' + version + '","imageTag":"base","boardUdid":"' +
    udid + '","boardClockAtRun":"' + AT + '","matrix":[' + matrix + ']}';
}

function nineSteps(): string {
  let steps = step(2, 0);
  for (let i = 0; i < 8; i++) {
    steps += ',' + step(1, 0);
  }
  return steps;
}

function validRun(): ProbeRun {
  let run = new ProbeRun();
  run.probeId = 'P2';
  run.verdict = 'blocked';
  run.level = 'L1';
  run.phrase = '沙箱拒绝读取';
  run.imageRole = 'base';
  run.createdAt = AT;
  return run;
}

export function runProbeCodecChecks(): void {
  let empty = acceptSidecar('', '');
  if (empty.ok) {
    fail('空串不应导入');
  }
  let broken = acceptSidecar('{', '');
  if (broken.ok || broken.reason !== '侧车报告不是合法的 JSON') {
    fail('坏 JSON 原因不对');
  }
  let schema = acceptSidecar(report(step(2, 0), '', 'jinyinhu.other', '0.1'), '');
  if (schema.ok || schema.reason !== '不是侧车报告') {
    fail('错 schema 应拒绝');
  }
  let version = acceptSidecar(report(step(2, 0), '', ProbeLimits.schemaSidecar, '9.9'), '');
  if (version.ok || version.reason !== '侧车报告版本不是 0.1') {
    fail('错版本应拒绝');
  }
  let missing = acceptSidecar(report(step(1, 0), '', ProbeLimits.schemaSidecar, '0.1'), '');
  if (missing.ok || missing.reason !== '侧车报告缺少态 2') {
    fail('缺态 2 的原因不对');
  }
  let udid = acceptSidecar(report(step(2, 0), 'OTHER', ProbeLimits.schemaSidecar, '0.1'), 'BOARD');
  if (udid.ok || udid.reason !== '侧车 UDID 与准备页登记不一致') {
    fail('UDID 不一致应拒绝');
  }
  let tooMany = acceptSidecar(report(nineSteps(), '', ProbeLimits.schemaSidecar, '0.1'), '');
  if (tooMany.ok || tooMany.reason !== '侧车步骤超过 8 条') {
    fail('超过 8 步不应说缺少态 2');
  }
  let red = acceptSidecar(report(step(2, 0), '', ProbeLimits.schemaSidecar, '0.1'), '');
  if (!red.ok) {
    fail('态 2 retCode 0 的报告应能导入');
  }
  let kept = applyKeepSidecar(emptyProbeShelf(), red.report, AT);
  if (kept.runs.length !== 0 || kept.importState !== ProbeLimits.importImported || !kept.sidecarPresent) {
    fail('导入侧车不应生成探针结论');
  }
  let again = applyImportFailure(kept, '侧车报告不是合法的 JSON', AT);
  if (again.importState !== ProbeLimits.importImported || !again.sidecarPresent) {
    fail('失败导入改掉了成功报告');
  }
  if (again.sidecar.imageTag !== 'base' || again.failureReason !== '侧车报告不是合法的 JSON') {
    fail('失败记录没有单独留下');
  }
  if (again.runs.length !== 0) {
    fail('失败导入不应写出 hit 或 blocked');
  }
  let first = applyImportFailure(emptyProbeShelf(), '侧车报告是空的', AT);
  if (first.sidecarPresent || first.importState !== ProbeLimits.importIdle || first.failureReason.length === 0) {
    fail('第一次失败不应留下侧车');
  }
  if (isStamp('T123456789012345') || isStamp('2026-99-99T99:99:99+99:99') || isStamp('2026-02-31T00:00:00+08:00')) {
    fail('垃圾时间不应通过');
  }
  if (!isStamp(AT) || !isStamp(nowIso())) {
    fail('合法时间被拒绝');
  }
  let forged = validRun();
  forged.createdAt = 'T123456789012345';
  if (acceptProbeRun('P2', forged).ok) {
    fail('垃圾时间的探针结果不应落盘');
  }
  let painted = validRun();
  painted.verdict = 'hit';
  painted.level = 'L3';
  painted.createdAt = AT;
  if (acceptProbeRun('P2', painted).ok) {
    fail('L3 的 hit 不应落盘');
  }
  let shelf = applyAppendRun(kept, validRun());
  let text = formatProbeShelf(shelf);
  let parsed = parseProbeShelf(text);
  if (parsed === undefined || parsed.runs.length !== 1 || parsed.runs[0].phrase !== '沙箱拒绝读取') {
    fail('货架往返后证据变了');
  }
  if (parsed === undefined || parsed.importState !== ProbeLimits.importImported) {
    fail('往返后成功报告状态变了');
  }
  let damaged = text.replace('"createdAt": "' + AT + '"', '"createdAt": "T123456789012345"');
  if (parseProbeShelf(damaged) !== undefined) {
    fail('损坏的单条记录不应被悄悄丢掉');
  }
  let legacy = text.replace('"importState": "imported"', '"importState": "failed",\n  "importReason": "不是侧车报告"');
  let migrated = parseProbeShelf(legacy);
  if (migrated === undefined || migrated.importState !== ProbeLimits.importImported) {
    fail('旧的失败标记不应盖掉成功报告');
  }
  if (migrated === undefined || migrated.failureReason !== '不是侧车报告' || migrated.runs.length !== 1) {
    fail('旧失败原因或证据没有保留');
  }
}
