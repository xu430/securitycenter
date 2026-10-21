import { encodeProbeEvents, formatBundle, parseBundle, restoreArchive } from '../main/ets/model/D4Codec';
import { D4Event, validateEvent } from '../main/ets/model/D4Types';
import { ProbeEvidence, ProbeRun } from '../main/ets/probe/ProbeTypes';
import { Finding } from '../main/ets/report/Findings';

const AT = '2026-10-16T11:00:00+08:00';
const LATER = '2026-10-16T11:05:00+08:00';

function fail(message: string): void {
  throw new Error(message);
}

function finding(id: string, scenario: string, status: string, at: string, evidenceNo: string): Finding {
  let row = new Finding();
  row.findingId = id;
  row.scenarioId = scenario;
  row.title = scenario === 'A1' ? '安装信任链' : '沙箱隔离';
  if (scenario === 'C1') {
    row.title = '安全组件姿态';
  }
  row.affectedApp = scenario === 'C1' ? '' : 'com.jinyinhu.lakesidenotes';
  row.ruleRef = scenario === 'A1' ? 'hap_verify_v2.cpp:1010-1023; hap_verify_v2.cpp:960-988' : 'sandbox_helper.cpp:532-552; file_uri.cpp:154-200';
  row.patchRef = status === 'fixed-by-patch' ? '安全镜像已含该修复' : 'open';
  row.status = status;
  row.registeredAt = at;
  row.evidenceNo = evidenceNo;
  return row;
}

function run(id: 'P1' | 'P2' | 'P3', verdict: 'hit' | 'blocked' | 'passive', level: 'L1' | 'L2' | 'L3',
  role: 'base' | 'secure' | '', phrase: string, at: string): ProbeRun {
  let row = new ProbeRun();
  row.probeId = id;
  row.verdict = verdict;
  row.level = level;
  row.imageRole = role;
  row.phrase = phrase;
  row.createdAt = at;
  if (verdict === 'blocked' && id === 'P2') {
    let evidence = new ProbeEvidence();
    evidence.kind = 'errno';
    evidence.text = '穿越 files';
    evidence.raw = '穿越 stat=0x1';
    evidence.at = at;
    let rows: ProbeEvidence[] = [];
    rows.push(evidence);
    row.evidences = rows;
  }
  if (verdict === 'blocked' && id === 'P1') {
    let evidence = new ProbeEvidence();
    evidence.kind = 'sidecar-state';
    evidence.text = '态2';
    evidence.raw = '{"state":2,"retCode":7}';
    evidence.at = at;
    let rows: ProbeEvidence[] = [];
    rows.push(evidence);
    row.evidences = rows;
  }
  return row;
}

export function runD4ContractChecks(): void {
  let old = new D4Event();
  old.schema = 'jinyinhu.d4.event';
  old.schemaVersion = '0.1';
  old.eventId = 'old-1';
  old.seq = 1;
  old.deviceId = 'board-vanilla';
  old.imageRole = 'vanilla-demo';
  old.imageVersion = '7.0.0.40';
  old.appId = 'com.jinyinhu.securitycenter';
  old.appVersion = '1.0.0';
  old.scenarioId = 'S3';
  old.outcome = 'blocked';
  old.phrase = '系统拒绝并已入账';
  old.occurredAt = AT;
  old.source = 'rehearsal';
  old.threatStatus = 'open';
  if (validateEvent(old) !== '') {
    fail('历史 vanilla-demo 仍应能读入');
  }
  old.imageRole = 'base';
  old.scenarioId = 'A1';
  old.source = 'probe';
  old.phrase = '安装器收下了伪造';
  old.outcome = 'succeeded';
  if (validateEvent(old) !== '' || old.schemaVersion !== '0.1') {
    fail('新枚举应在 0.1 下通过校验');
  }

  let open = finding('FND-A1', 'A1', 'open', AT, '');
  let hit = run('P1', 'hit', 'L2', 'base', '安装器收下了伪造', AT);
  let exported = encodeProbeEvents([open], [hit], 'B05FC428', '7.0.0.40');
  if (exported.length !== 1 || exported[0].imageRole !== 'base' || exported[0].scenarioId !== 'A1' ||
    exported[0].source !== 'probe' || exported[0].outcome !== 'succeeded' || exported[0].threatStatus !== 'open') {
    fail('P1 判红应导出基础版 A1 探针事件');
  }
  if (exported[0].phrase !== '安装器收下了伪造' || exported[0].phrase === '得手') {
    fail('短语应来自探针记录，不能写成得手');
  }
  if (exported[0].schemaVersion !== '0.1') {
    fail('schemaVersion 必须保持 0.1');
  }

  let posture = finding('FND-C1', 'C1', 'open', AT, '');
  let passive = run('P3', 'passive', 'L3', '', '四条引用已列出', AT);
  if (encodeProbeEvents([posture], [passive], '', '7.0.0.40').length !== 0) {
    fail('C1 和 passive 不能写成 D4 事件');
  }

  let fixed = finding('FND-A1', 'A1', 'fixed-by-patch', LATER, 'com.jinyinhu.lakesidenotes-2-abc123');
  let green = run('P1', 'blocked', 'L2', 'secure', '安装器拒绝了伪造', LATER);
  let mitigated = encodeProbeEvents([fixed], [hit, green], '', '7.0.0.40');
  if (mitigated.length !== 1 || mitigated[0].threatStatus !== 'mitigated' || mitigated[0].outcome !== 'blocked' ||
    mitigated[0].imageRole !== 'secure' || mitigated[0].evidenceNo !== fixed.evidenceNo || mitigated[0].registeredAt !== LATER) {
    fail('已修复应映射为 mitigated，并带上登记时点和依据编号');
  }
  if (mitigated[0].phrase === '阻断') {
    fail('判绿短语不能写成阻断');
  }
  let bare = finding('FND-A1', 'A1', 'fixed-by-patch', LATER, '');
  if (encodeProbeEvents([bare], [green], '', '7.0.0.40').length !== 0) {
    fail('没有 evidenceNo 的 fixed-by-patch 不能写出');
  }
  let shortTime = finding('FND-A1', 'A1', 'fixed-by-patch', '2026', fixed.evidenceNo);
  if (encodeProbeEvents([shortTime], [green], '', '7.0.0.40').length !== 0) {
    fail('registeredAt 不够长的 fixed-by-patch 不能写出');
  }
  let laterBase = '2026-10-16T11:10:00+08:00';
  let baseBlocked = run('P1', 'blocked', 'L2', 'base', '安装器拒绝了伪造', laterBase);
  let paired = encodeProbeEvents([fixed], [green, baseBlocked], '', '7.0.0.40');
  if (paired.length !== 1 || paired[0].imageRole !== 'secure' || paired[0].occurredAt !== LATER) {
    fail('已缓解只能配到安全版的那次 blocked');
  }
  let disclosed = finding('FND-A1', 'A1', 'open', laterBase, '');
  let disclosedRun = run('P1', 'passive', 'L3', 'base', '基础版未收下', laterBase);
  if (encodeProbeEvents([disclosed], [hit, disclosedRun], '', '7.0.0.40').length !== 0) {
    fail('披露态不能再把历史上的红导出');
  }
  let text = formatBundle(exported);
  let parsed = parseBundle(text);
  if (!parsed.ok || parsed.skipped !== 0 || parsed.events.length !== exported.length) {
    fail('合法归档应能恢复同一组记录');
  }
  let restored = restoreArchive(parsed.events);
  if (!restored.ok || restored.findings.length !== 1 || restored.findings[0].status !== 'open') {
    fail('导入应还原出台账，而不是只写入现场事件');
  }
  let again = encodeProbeEvents(restored.findings, restored.runs, exported[0].deviceId, exported[0].imageVersion);
  if (again.length !== exported.length || again[0].phrase !== exported[0].phrase || again[0].eventId !== exported[0].eventId ||
    again[0].outcome !== exported[0].outcome || again[0].imageRole !== exported[0].imageRole) {
    fail('还原后的台账应编出同一组事件');
  }
  let fixedText = formatBundle(mitigated);
  let fixedParsed = parseBundle(fixedText);
  let fixedBack = restoreArchive(fixedParsed.events);
  if (!fixedBack.ok || fixedBack.findings[0].status !== 'fixed-by-patch' || fixedBack.runs[0].imageRole !== 'secure') {
    fail('已缓解应还原成安全版绿和 fixed-by-patch');
  }
  let fixedAgain = encodeProbeEvents(fixedBack.findings, fixedBack.runs, mitigated[0].deviceId, mitigated[0].imageVersion);
  if (fixedAgain.length !== 1 || fixedAgain[0].threatStatus !== 'mitigated' || fixedAgain[0].imageRole !== 'secure' ||
    fixedAgain[0].evidenceNo !== mitigated[0].evidenceNo) {
    fail('还原后的已缓解应编出同一条事件');
  }
  let broken = parseBundle('{');
  if (broken.ok || broken.message.length === 0) {
    fail('不合法文件不能显示为导入成功');
  }
}
