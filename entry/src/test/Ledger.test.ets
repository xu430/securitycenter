import { Catalog } from '../main/ets/model/Catalog';
import { ProbeEvidence, ProbeRun } from '../main/ets/probe/ProbeTypes';
import { nextFindings } from '../main/ets/report/Findings';
import { ledgerDetail, ledgerEntries, ledgerExport, pickImageTag, tallyVerdicts, countOpenFindings } from '../main/ets/report/Ledger';

const AT = '2026-10-15T16:00:00+08:00';
const LATER = '2026-10-15T16:05:00+08:00';

function fail(message: string): void {
  throw new Error(message);
}

function sample(id: string, verdict: string, role: string, at: string): ProbeRun {
  let run = new ProbeRun();
  run.probeId = id as 'P1';
  if (id === 'P2' || id === 'P3') {
    run.probeId = id;
  }
  run.verdict = verdict as 'hit';
  if (verdict === 'blocked' || verdict === 'passive') {
    run.verdict = verdict;
  }
  run.level = 'L1';
  if (verdict === 'passive') {
    run.level = 'L3';
  }
  run.phrase = verdict === 'hit' ? '读到沙箱文件' : '五条均被拒绝';
  if (verdict === 'passive') {
    run.phrase = '组件可回报';
  }
  run.imageRole = role as '';
  if (role === 'base' || role === 'secure') {
    run.imageRole = role;
  }
  run.createdAt = at;
  return run;
}

function withErrno(run: ProbeRun, raw: string): ProbeRun {
  let evidence = new ProbeEvidence();
  evidence.kind = 'errno';
  evidence.text = '已脱敏';
  evidence.raw = raw;
  evidence.at = run.createdAt;
  let list: ProbeEvidence[] = [];
  list.push(evidence);
  run.evidences = list;
  return run;
}

class ExportPeek {
  schema: string = '';
  schemaVersion: string = '';
  findings: ExportFinding[] = [];
}

class ExportFinding {
  findingId: string = '';
  status: string = '';
  runs: ExportRun[] = [];
}

class ExportRun {
  probeId: string = '';
  evidences: ExportEvidence[] = [];
}

class ExportEvidence {
  kind: string = '';
  text: string = '';
  raw: string = '';
  at: string = '';
}

export function runLedgerChecks(): void {
  let stray = withErrno(sample('P2', 'blocked', 'base', AT), 'stat=0xd3e86c open=0xd3e86c');
  if (ledgerEntries([], [stray]).length !== 0 || ledgerExport([], [stray]) !== '') {
    fail('没有 Finding 时不生成台账，也不导出');
  }
  let threats = Catalog.threats();
  for (let i = 0; i < threats.length; i++) {
    if (threats[i].threatId === 'TM-S1' || threats[i].threatId === 'TM-S2' || threats[i].threatId === 'TM-D3') {
      fail('S1/S2/D3 旧台账行应已移交');
    }
  }
  if (Catalog.findThreat('TM-S3') === undefined || Catalog.residual().threatId !== 'TM-RES-01') {
    fail('S3 和残余应保留');
  }
  if (Catalog.baseline().length !== 5 || Catalog.samples().length !== 6 || Catalog.script().length !== 7) {
    fail('基线、样本和脚本不应被这次删除带走');
  }
  let keptScript = false;
  let steps = Catalog.script();
  for (let i = 0; i < steps.length; i++) {
    if (steps[i].scenarioId === 'S2') {
      keptScript = true;
    }
  }
  if (!keptScript) {
    fail('S2 的脚本步骤应留下来');
  }
  let cues = Catalog.cues();
  if (cues.length !== 2) {
    fail('只保留还能对上威胁行的台词');
  }
  for (let i = 0; i < cues.length; i++) {
    if (cues[i].scenarioId === 'S2' || cues[i].threatId === 'TM-S2') {
      fail('S2 台词不能再指向已删除的威胁行');
    }
    if (cues[i].threatId !== 'TM-S3') {
      fail('S3 台词应保留');
    }
  }
  let dropped = Catalog.cue('vanilla-demo', 'S2');
  if (dropped.threatId === 'TM-S2' || dropped.phrase === '服务已被打停') {
    fail('删掉的 S2 台词不能再声称一次具体拦截');
  }
  if (Catalog.glossary().length !== 6 || Catalog.scenarioChoices().length !== 4) {
    fail('术语和场景选项不应被这次删除带走');
  }

  let hit = nextFindings([], sample('P1', 'hit', 'base', AT));
  let older = withErrno(sample('P1', 'hit', 'base', AT), 'stat=0x1 open=0x1');
  let newer = withErrno(sample('P1', 'blocked', 'secure', LATER), 'stat=0xd3e86c open=0xd3e86c');
  let other = withErrno(sample('P2', 'hit', 'base', LATER), 'stat=0x22 open=0x22');
  let rows = ledgerEntries(hit.findings, [older, other, newer]);
  if (rows.length !== 1 || rows[0].status !== 'open' || rows[0].findingId !== 'FND-A1' || rows[0].title !== '安装信任链') {
    fail('打开台账不能把 open 改成已修复');
  }
  if (rows[0].runs.length !== 2 || rows[0].runs[0].createdAt !== LATER || rows[0].runs[1].createdAt !== AT) {
    fail('关联探针结果应按时间倒序，并且不串到别的探针');
  }
  let opened = ledgerDetail('FND-A1', hit.findings, [older, other, newer]);
  if (opened === undefined || opened.runs[0].evidences.length !== 1) {
    fail('点开后应能看到关联证据');
  }
  let evidence = opened.runs[0].evidences[0];
  if (evidence.kind !== 'errno' || evidence.text !== '已脱敏' || evidence.raw.indexOf('0xd3e86c') < 0 || evidence.at !== LATER) {
    fail('证据应保留 kind、text、raw、at');
  }
  if (opened.runs[0].evidences[0].raw.indexOf('0x22') >= 0) {
    fail('A1 不应带上 B1 的证据');
  }

  let fixed = nextFindings(hit.findings, withErrno(sample('P1', 'blocked', 'secure', LATER), 'stat=0xd3e86c open=0xd3e86c'));
  let sandbox = nextFindings([], sample('P2', 'hit', 'base', AT));
  let both = fixed.findings.slice(0);
  both.push(sandbox.findings[0]);
  let ordered = ledgerEntries(both, []);
  if (ordered.length !== 2 || ordered[0].findingId !== 'FND-A1' || ordered[1].findingId !== 'FND-B1') {
    fail('台账应按登记时点倒序');
  }
  if (ordered[1].runs.length !== 0) {
    fail('没有探针结果时条目下不该有证据');
  }

  let text = ledgerExport(hit.findings, [newer]);
  if (text.indexOf('得手') >= 0 || text.indexOf('阻断') >= 0 || text.indexOf('TM-S1') >= 0) {
    fail('导出不能带示意词或旧场景样例');
  }
  let parsed = JSON.parse(text) as ExportPeek;
  if (parsed.schema !== 'jinyinhu.ledger.export' || parsed.schemaVersion !== '0.1') {
    fail('导出应交给后续归档识别');
  }
  if (parsed.findings.length !== 1 || parsed.findings[0].status !== 'open') {
    fail('导出应保持只读状态');
  }
  if (parsed.findings[0].runs[0].probeId !== 'P1' || parsed.findings[0].runs[0].evidences[0].kind !== 'errno') {
    fail('导出应带上关联证据');
  }
  let leaked = withErrno(sample('P1', 'hit', 'base', AT), 'stat=0x1 {"note":"门锁重置码"}');
  let hidden = ledgerEntries(hit.findings, [leaked]);
  if (hidden.length !== 1 || hidden[0].runs[0].evidences[0].raw !== '已脱敏' || hidden[0].runs[0].evidences[0].raw.indexOf('门锁') >= 0) {
    fail('文件内容不能从台账原文打开');
  }
  let dump = sample('P1', 'hit', 'base', AT);
  let dumpEvidence = new ProbeEvidence();
  dumpEvidence.kind = 'cmd-transcript';
  dumpEvidence.text = '三态命令回显';
  dumpEvidence.raw = '态2 bm dump\n{"versionCode":1000001}\n路径 已脱敏';
  dumpEvidence.at = AT;
  let dumpList: ProbeEvidence[] = [];
  dumpList.push(dumpEvidence);
  dump.evidences = dumpList;
  let dumpRows = ledgerEntries(hit.findings, [dump]);
  let dumpRaw = dumpRows[0].runs[0].evidences[0].raw;
  if (dumpRaw === '已脱敏' || dumpRaw.indexOf('versionCode') < 0 || dumpRaw.indexOf('路径 已脱敏') < 0) {
    fail('命令回显应保留 bm dump，已脱敏的路径保持原样');
  }
  let side = sample('P1', 'blocked', 'secure', LATER);
  let sideEvidence = new ProbeEvidence();
  sideEvidence.kind = 'sidecar-state';
  sideEvidence.text = '态2';
  sideEvidence.raw = '{"state":2,"retCode":-1,"transcript":"门锁重置码"}';
  sideEvidence.at = LATER;
  let sideList: ProbeEvidence[] = [];
  sideList.push(sideEvidence);
  side.evidences = sideList;
  let sideRows = ledgerEntries(hit.findings, [side]);
  if (sideRows[0].runs[0].evidences[0].raw.indexOf('门锁') >= 0 || sideRows[0].runs[0].evidences[0].raw.indexOf('-1') < 0) {
    fail('侧车原文只留下态号和 retCode');
  }
  let emptyTally = tallyVerdicts([]);
  if (emptyTally.hit !== 0 || emptyTally.blocked !== 0 || emptyTally.passive !== 0) {
    fail('没有探针结果时态势环应为 0');
  }
  let counted = tallyVerdicts([
    sample('P1', 'hit', 'base', AT),
    sample('P2', 'blocked', 'secure', LATER),
    sample('P3', 'passive', '', AT)
  ]);
  if (counted.hit !== 1 || counted.blocked !== 1 || counted.passive !== 1) {
    fail('红绿灰应按已落盘结论计数');
  }
  if (pickImageTag('', '', 'secure', true, AT) !== 'secure') {
    fail('镜像标签应来自成功导入的侧车');
  }
  if (pickImageTag('base', LATER, 'secure', true, AT) !== 'base') {
    fail('较新的手动选择应覆盖较早的侧车标签');
  }
  if (pickImageTag('base', AT, 'secure', true, LATER) !== 'secure') {
    fail('较新的侧车导入应覆盖较早的手动选择');
  }
  if (pickImageTag('', '', 'base', false, AT) !== '') {
    fail('没有成功导入时不能把侧车标签当成当前镜像');
  }
  if (countOpenFindings(hit.findings) !== 1) {
    fail('未收口条数应来自 Findings');
  }
}
