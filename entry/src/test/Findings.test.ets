import { Findings, formatFindings, nextFindings, parseFindings } from '../main/ets/report/Findings';
import { ProbeEvidence, ProbeRun } from '../main/ets/probe/ProbeTypes';

const AT = '2026-10-15T16:00:00+08:00';
const LATER = '2026-10-15T16:05:00+08:00';
const AGAIN = '2026-10-15T16:10:00+08:00';

function fail(message: string): void {
  throw new Error(message);
}

class Disk {
  writes: number = 0;
  text: string = '';

  save(text: string): void {
    this.writes = this.writes + 1;
    this.text = text;
  }
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

function withErrno(run: ProbeRun): ProbeRun {
  let evidence = new ProbeEvidence();
  evidence.kind = 'errno';
  evidence.text = '已拒绝';
  evidence.raw = 'stat=0xd3e86c open=0xd3e86c';
  evidence.at = run.createdAt;
  let list: ProbeEvidence[] = [];
  list.push(evidence);
  run.evidences = list;
  return run;
}

function withState2(run: ProbeRun, retCode: number): ProbeRun {
  let evidence = new ProbeEvidence();
  evidence.kind = 'sidecar-state';
  evidence.text = '态2';
  evidence.raw = '{"state":2,"retCode":' + retCode.toString() + '}';
  evidence.at = run.createdAt;
  let list: ProbeEvidence[] = [];
  list.push(evidence);
  run.evidences = list;
  return run;
}

function evidenceShape(evidenceNo: string, marker: string): boolean {
  let prefix = 'com.jinyinhu.lakesidenotes-' + marker + '-';
  if (evidenceNo.length !== prefix.length + 6 || evidenceNo.substring(0, prefix.length) !== prefix) {
    return false;
  }
  let tail = evidenceNo.substring(prefix.length);
  for (let i = 0; i < tail.length; i++) {
    let ch = tail.charAt(i);
    if (!((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f'))) {
      return false;
    }
  }
  return true;
}

function runLedgerLocks(): void {
  let disk = new Disk();
  Findings.bindWriter((text: string): void => {
    disk.save(text);
  });
  Findings.restore();
  Findings.load('');
  if (disk.writes !== 0 || Findings.list().length !== 0) {
    fail('没有探针结果时磁盘上不出现 Finding');
  }
  Findings.record(sample('P1', 'hit', 'base', AT));
  let opened = Findings.list();
  if (disk.writes !== 1 || opened.length !== 1 || opened[0].status !== 'open' || opened[0].findingId !== 'FND-A1') {
    fail('基础版 hit 得到 open');
  }
  Findings.record(sample('P1', 'blocked', 'secure', LATER));
  if (disk.writes !== 1 || Findings.list()[0].status !== 'open' || Findings.list()[0].evidenceNo !== '') {
    fail('没有 errno 或态 2 retCode 时保持 open');
  }
  Findings.record(withErrno(sample('P1', 'blocked', 'secure', LATER)));
  let fixed = Findings.list();
  if (disk.writes !== 2 || fixed.length !== 1 || fixed[0].status !== 'fixed-by-patch') {
    fail('安全版 blocked 且带 errno 才变成 fixed-by-patch');
  }
  if (fixed[0].registeredAt !== LATER || !evidenceShape(fixed[0].evidenceNo, '2') || fixed[0].patchRef !== '安全镜像已含该修复') {
    fail('已修复必须带登记时点和依据编号');
  }
  let stored = parseFindings(disk.text);
  if (stored === undefined || stored.length !== 1 || stored[0].status !== 'fixed-by-patch') {
    fail('台账键只在有探针结果后写入');
  }
  let passive = nextFindings([], sample('P3', 'passive', '', AT));
  if (passive.findings.length !== 1 || passive.findings[0].status !== 'open' || passive.findings[0].affectedApp !== '') {
    fail('被动探针应保持 open 且不指向应用');
  }
  if (passive.findings[0].ruleRef.indexOf('sec_comp_malicious_apps.cpp') < 0) {
    fail('安全组件姿态应带上恶意名单入口');
  }
  let still = nextFindings(passive.findings, withErrno(sample('P3', 'blocked', 'secure', LATER)));
  if (still.changed || still.findings[0].status !== 'open' || still.findings[0].evidenceNo !== '') {
    fail('被动条目不能改成 fixed-by-patch');
  }
}

export function runFindingsChecks(): void {
  runLedgerLocks();
  let none = nextFindings([], withErrno(sample('P2', 'blocked', '', AT)));
  if (none.changed || none.findings.length !== 0) {
    fail('基础版上的绿不应写成未收口缺陷');
  }
  let baseGreen = nextFindings([], withErrno(sample('P2', 'blocked', 'base', AT)));
  if (baseGreen.changed || baseGreen.findings.length !== 0) {
    fail('基础镜像上的拒绝不能记成缺陷');
  }
  let hit = nextFindings([], sample('P1', 'hit', 'base', AT));
  if (!hit.changed || hit.findings.length !== 1 || hit.findings[0].status !== 'open') {
    fail('命中应登记为 open');
  }
  if (hit.findings[0].findingId !== 'FND-A1' || hit.findings[0].evidenceNo !== '' || hit.findings[0].patchRef !== 'open') {
    fail('open 条目不应带已修复编号');
  }
  let repeat = nextFindings(hit.findings, sample('P1', 'hit', 'base', LATER));
  if (repeat.changed || repeat.findings[0].registeredAt !== AT || repeat.findings[0].status !== 'open') {
    fail('重复命中不应改写登记时点');
  }
  let held = nextFindings(hit.findings, withErrno(sample('P1', 'blocked', 'base', LATER)));
  if (held.changed || held.findings[0].status !== 'open' || held.findings[0].evidenceNo !== '') {
    fail('基础镜像上的绿不能把 open 收成已修复');
  }
  let bare = nextFindings(hit.findings, sample('P1', 'blocked', 'secure', LATER));
  if (bare.changed || bare.findings[0].status !== 'open') {
    fail('空证据不能收成已修复');
  }
  let accepted = nextFindings(hit.findings, withState2(sample('P1', 'blocked', 'secure', LATER), 0));
  if (accepted.changed || accepted.findings[0].status !== 'open') {
    fail('态 2 retCode 为 0 不是绿证据');
  }
  let byCode = nextFindings(hit.findings, withState2(sample('P1', 'blocked', 'secure', LATER), -1));
  if (!byCode.changed || byCode.findings[0].status !== 'fixed-by-patch' || byCode.findings[0].patchRef !== '安全镜像已含该修复') {
    fail('态 2 的非零 retCode 才能收口');
  }
  let fixed = nextFindings(hit.findings, withErrno(sample('P1', 'blocked', 'secure', LATER)));
  if (!fixed.changed || fixed.findings[0].status !== 'fixed-by-patch' || !evidenceShape(fixed.findings[0].evidenceNo, '2')) {
    fail('安全版上的 errno 应改为 fixed-by-patch');
  }
  let again = nextFindings(fixed.findings, withErrno(sample('P1', 'blocked', 'secure', AGAIN)));
  if (again.changed || again.findings[0].registeredAt !== LATER) {
    fail('已经收口的条目不应被同一次绿重复改写');
  }
  let reopened = nextFindings(fixed.findings, sample('P1', 'hit', 'secure', AGAIN));
  if (!reopened.changed || reopened.findings[0].status !== 'open' || reopened.findings[0].evidenceNo !== '') {
    fail('安全镜像上再次命中应重新打开');
  }
  if (reopened.findings[0].registeredAt !== AGAIN || reopened.findings[0].patchRef !== 'open') {
    fail('重新打开要改登记时点并清掉修复说明');
  }
  let alone = nextFindings([], withErrno(sample('P1', 'blocked', 'secure', AT)));
  if (alone.changed || alone.findings.length !== 0) {
    fail('没有先前的红，不能直接写成已修复');
  }
  let sandbox = nextFindings([], sample('P2', 'hit', 'base', AT));
  let sandboxBare = nextFindings(sandbox.findings, sample('P2', 'blocked', 'secure', LATER));
  if (sandboxBare.changed || sandboxBare.findings[0].status !== 'open') {
    fail('沙箱没有 errno 时保持 open');
  }
  let sandboxFixed = nextFindings(sandbox.findings, withErrno(sample('P2', 'blocked', 'secure', LATER)));
  if (sandboxFixed.findings[0].findingId !== 'FND-B1' || sandboxFixed.findings[0].status !== 'fixed-by-patch') {
    fail('沙箱 errno 应收口');
  }
  if (sandboxFixed.findings[0].patchRef !== 'open' || !evidenceShape(sandboxFixed.findings[0].evidenceNo, 'B')) {
    fail('沙箱收口不能写成候选 A 的修复说明');
  }
  let text = formatFindings(fixed.findings);
  let back = parseFindings(text);
  if (back === undefined || back.length !== 1 || back[0].evidenceNo !== fixed.findings[0].evidenceNo) {
    fail('台账文本应能按原样读回');
  }
  if (parseFindings(text.replace('fixed-by-patch', 'mitigated')) !== undefined) {
    fail('台账不能接受第四种状态');
  }
  if (parseFindings(text.replace('安装信任链', '得手')) !== undefined) {
    fail('台账标题不能被改成示意词');
  }
  if (parseFindings(text.replace('"evidenceNo": "' + fixed.findings[0].evidenceNo + '"', '"evidenceNo": "abc"')) !== undefined) {
    fail('手填的短编号不能当成已修复');
  }
  let openText = formatFindings(hit.findings);
  if (parseFindings(openText.replace('"evidenceNo": ""', '"evidenceNo": "abc"')) !== undefined) {
    fail('open 条目不能带着依据编号');
  }
  if (parseFindings(openText.replace('"registeredAt": "' + AT + '"', '"registeredAt": ""')) !== undefined) {
    fail('没有登记时点的条目不能读入');
  }
}
