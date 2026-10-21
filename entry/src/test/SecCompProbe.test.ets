import { acceptProbeRun } from '../main/ets/probe/ProbeCodec';
import { buildClickResult, buildPostureResult, buildSecurePosture, postureNotes } from '../main/ets/probe/SecCompPostureProbe';
import { nextFindings } from '../main/ets/report/Findings';
import { ledgerEntries } from '../main/ets/report/Ledger';

const AT = '2026-10-15T16:00:00+08:00';
const LATER = '2026-10-15T16:05:00+08:00';

function fail(message: string): void {
  throw new Error(message);
}

export function runPostureChecks(): void {
  let listed = buildPostureResult('', AT);
  if (listed.verdict !== 'passive' || listed.level !== 'L3' || listed.phrase.indexOf('可回报') >= 0) {
    fail('扫描只记四条引用，不能写成可回报');
  }
  if (listed.evidences.length !== 4) {
    fail('扫描结果只挂四条源码引用');
  }
  for (let i = 0; i < listed.evidences.length; i++) {
    if (listed.evidences[i].kind !== 'source-ref') {
      fail('姿态引用必须是 source-ref，并且保持 L3');
    }
  }
  let notes = postureNotes();
  if (notes.length !== 4 || notes[2].raw !== 'sec_comp_malicious_apps.cpp') {
    fail('四条引用应包含恶意名单文件');
  }
  if (notes[2].text.indexOf('2026-07-14') < 0 || notes[2].text.indexOf('1f86d2d') < 0) {
    fail('恶意名单说明应写连续失败 3 次和 commit');
  }
  if (notes[3].text.indexOf('前台 HAP 门槛') < 0 || notes[3].text.indexOf('唯一硬门槛') < 0) {
    fail('前台门槛说明应出现在对应引用上');
  }
  if (listed.evidences[2].text !== notes[2].text || listed.evidences[3].text !== notes[3].text) {
    fail('源码说明应写进 source-ref 的 text');
  }
  let accepted = acceptProbeRun('P3', listed);
  if (!accepted.ok || accepted.run.verdict !== 'passive' || accepted.run.level !== 'L3') {
    fail('引用结果应能落盘且保持 L3 passive');
  }

  let reported = buildClickResult(AT, 'SUCCESS', 'secure');
  if (reported.verdict !== 'passive' || reported.level !== 'L1' || reported.phrase !== '组件可回报') {
    fail('点击结果单独记成 L1 passive');
  }
  if (reported.evidences.length !== 1 || reported.evidences[0].kind === 'source-ref') {
    fail('点击结果不能把源码引用标成 L1');
  }
  if (reported.evidences[0].text.indexOf('系统组件在本镜像可注册可回报') < 0 || reported.evidences[0].at !== AT) {
    fail('点击证据应带上回报原文和时间');
  }
  let stored = acceptProbeRun('P3', reported);
  if (!stored.ok) {
    fail('点击后的 passive 结果应能落盘');
  }
  let ledger = nextFindings([], stored.run);
  if (ledger.findings.length !== 1 || ledger.findings[0].findingId !== 'FND-C1' ||
    ledger.findings[0].status !== 'open' || ledger.findings[0].affectedApp !== '') {
    fail('P3 只记 FND-C1 且保持 open');
  }
  let still = nextFindings(ledger.findings, buildPostureResult('secure', LATER));
  if (still.findings[0].status !== 'open' || still.findings[0].evidenceNo !== '') {
    fail('P3 不能写成 fixed-by-patch');
  }
  let again = buildPostureResult('secure', LATER);
  if (again.level !== 'L3' || again.phrase.indexOf('可回报') >= 0) {
    fail('再次扫描不能把同一次点击再记一遍');
  }
  let screened = ledgerEntries(ledger.findings, [accepted.run]);
  if (screened.length !== 1) {
    fail('C1 应能进入台账');
  }
  let kept = false;
  let runs = screened[0].runs;
  for (let i = 0; i < runs.length; i++) {
    for (let j = 0; j < runs[i].evidences.length; j++) {
      if (runs[i].evidences[j].raw === 'sec_comp_malicious_apps.cpp' &&
        runs[i].evidences[j].text.indexOf('1f86d2d') >= 0) {
        kept = true;
      }
    }
  }
  if (!kept) {
    fail('没有行号的源码说明应保留');
  }
  let secured = buildSecurePosture(LATER);
  if (secured.verdict !== 'blocked' || secured.level === 'L3' || secured.phrase !== '控件已收紧' || secured.imageRole !== 'secure') {
    fail('安全版控件检测应判为没有风险');
  }
  if (!acceptProbeRun('P3', secured).ok) {
    fail('安全版控件结果应能落盘');
  }
  let cleared = nextFindings(ledger.findings, secured);
  if (!cleared.changed || cleared.findings.length !== 0) {
    fail('安全版应收起安全控件那条记录');
  }
}
