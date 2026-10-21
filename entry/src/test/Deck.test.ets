import { D4Event } from '../main/ets/model/D4Types';
import { ProbeEvidence, ProbeRun, emptyProbeShelf } from '../main/ets/probe/ProbeTypes';
import { applyImportFailure, applyKeepSidecar } from '../main/ets/probe/ProbeCodec';
import {
  ACT1_PHRASE,
  ACT2_NARRATION,
  ACT3_NARRATION,
  BLOCK_WORD,
  BOUNDARY_TEXT,
  BUNDLE_MISSING,
  HIT_WORD,
  PENDING_WORD,
  POSTURE_ACT3_TITLE,
  POSTURE_TITLE,
  SANDBOX_NARRATION,
  SANDBOX_TITLE,
  actFace,
  checklistReady,
  deckBeats,
  evaluateChecklist,
  pickLine,
  placeholderCount,
  sidecarReady,
  sightFromCode,
  sightInstalled
} from '../main/ets/deck/DeckScript';
import { PATCH_LINE } from '../main/ets/probe/InstallIntegrityProbe';
import { SidecarReport } from '../main/ets/probe/ProbeTypes';

const AT = '2026-10-16T10:00:00+08:00';
const LATER = '2026-10-16T10:05:00+08:00';

function fail(message: string): void {
  throw new Error(message);
}

function evidence(kind: 'errno' | 'bundle-state' | 'source-ref', text: string, raw: string): ProbeEvidence {
  let row = new ProbeEvidence();
  row.kind = kind;
  row.text = text;
  row.raw = raw;
  row.at = AT;
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
  return row;
}

function p1Hit(at: string): ProbeRun {
  let row = run('P1', 'hit', 'L2', 'base', '安装器收下了伪造', at);
  let rows: ProbeEvidence[] = [];
  rows.push(evidence('bundle-state', 'com.jinyinhu.lakesidenotes 态2 versionCode=1000001 读回 versionCode=1000000',
    'state2VersionCode=1000001 readbackVersionCode=1000000'));
  row.evidences = rows;
  return row;
}

function p1Blocked(at: string): ProbeRun {
  let row = run('P1', 'blocked', 'L2', 'secure', '安装器拒绝了伪造', at);
  let rows: ProbeEvidence[] = [];
  rows.push(evidence('source-ref', '安装验签两处', PATCH_LINE + '; hap_verify_v2.cpp:960-988'));
  row.evidences = rows;
  return row;
}

function p1Disclosure(at: string): ProbeRun {
  return run('P1', 'passive', 'L3', 'base', '基础版未收下', at);
}

function p2Hit(at: string): ProbeRun {
  let row = run('P2', 'hit', 'L1', 'base', '读到沙箱文件', at);
  let rows: ProbeEvidence[] = [];
  rows.push(evidence('errno', '穿越 files 一层', '穿越 stat=0x1'));
  rows.push(evidence('errno', '穿越 files 二层', '穿越 stat=0x1'));
  rows.push(evidence('errno', '穿越 files 三层', '穿越 stat=0x1'));
  rows.push(evidence('errno', '穿越 files 四层', '穿越 stat=0x1'));
  rows.push(evidence('errno', '穿越 files 五层', '穿越 stat=0x1'));
  row.evidences = rows;
  return row;
}

function postureRun(at: string): ProbeRun {
  let row = run('P3', 'passive', 'L3', '', '四条引用已列出', at);
  let rows: ProbeEvidence[] = [];
  rows.push(evidence('source-ref', '前台门槛', 'sec_comp_service.cpp:163-180'));
  row.evidences = rows;
  return row;
}

export function runDeckChecks(): void {
  let beats = deckBeats();
  if (beats.length !== 6 || beats[0].seconds !== 30 || beats[1].seconds !== 15 || beats[2].seconds !== 60 ||
    beats[3].seconds !== 15 || beats[4].seconds !== 60 || beats[5].seconds !== 15) {
    fail('三幕和边界声明的时长不对');
  }
  let opening = actFace('act1', []);
  if (opening.phrase !== ACT1_PHRASE || opening.outcome !== 'pending' || opening.phrase === HIT_WORD) {
    fail('第一幕应是普通软件，不是红绿结论');
  }
  let gap = actFace('gap1', [p1Hit(AT)]);
  if (gap.phrase !== BOUNDARY_TEXT || gap.outcome !== 'pending') {
    fail('幕间应只放边界声明');
  }
  let empty = actFace('act2', []);
  if (empty.phrase !== PENDING_WORD || empty.showTrophy || empty.outcome !== 'pending' || empty.phrase === HIT_WORD) {
    fail('没有取证时第二幕不能变成得手');
  }
  let hit = actFace('act2', [p1Hit(AT)]);
  if (hit.phrase !== HIT_WORD || !hit.showTrophy || hit.outcome !== 'succeeded' || hit.ink !== 'danger') {
    fail('最近一次 P1 为 hit 才显示得手');
  }
  if (hit.narration !== ACT2_NARRATION) {
    fail('主线第二幕仍应使用得手讲解词');
  }
  if (hit.lines.join(' ').indexOf('1000001') < 0 || hit.lines.join(' ').indexOf('1000000') < 0) {
    fail('得手应带上那次的 versionCode 证据');
  }
  let bare = p1Hit(AT);
  bare.evidences = [];
  if (actFace('act2', [bare]).phrase !== PENDING_WORD) {
    fail('没有 versionCode 证据不能写得手');
  }
  let afterSecure = actFace('act2', [p1Hit(AT), p1Blocked(LATER)]);
  if (afterSecure.phrase !== PENDING_WORD || afterSecure.phrase === HIT_WORD) {
    fail('最近一次不是 hit 时，第二幕要回到尚未取证');
  }
  let blocked = actFace('act3', [p1Hit(AT), p1Blocked(LATER)]);
  if (blocked.phrase !== BLOCK_WORD || !blocked.showPatch || blocked.patchLine !== PATCH_LINE || blocked.ink !== 'ok') {
    fail('最近一次是安全版 blocked 才显示阻断和补丁行');
  }
  if (actFace('act3', [p1Hit(AT)]).phrase !== PENDING_WORD) {
    fail('只有基础版 hit 时第三幕不能写阻断');
  }
  let noPatch = p1Blocked(LATER);
  noPatch.evidences = [];
  if (actFace('act3', [noPatch]).phrase !== PENDING_WORD) {
    fail('没有补丁行证据不能写阻断');
  }
  let disclosed = p1Disclosure(AT);
  let sandbox = p2Hit(LATER);
  if (pickLine([disclosed, sandbox]) !== 'P2') {
    fail('基础版态 2 被拒且沙箱读到文件时，主线应升到 P2');
  }
  let sandFace = actFace('act2', [disclosed, sandbox]);
  if (sandFace.phrase === HIT_WORD || sandFace.phrase === BLOCK_WORD || sandFace.lines.length !== 10 || sandFace.ink !== 'danger') {
    fail('降级第二幕应播五条 errno，不能写得手或阻断');
  }
  if (sandFace.lines.join('\n').indexOf('0x1') < 0 || sandFace.title !== SANDBOX_TITLE || sandFace.narration !== SANDBOX_NARRATION) {
    fail('沙箱幕应带上 raw 里的 errno，标题和讲解词不能再说得手');
  }
  if (sandFace.narration.indexOf('收下了') >= 0) {
    fail('沙箱幕讲解词不能说基础版收下了');
  }
  let refused = run('P2', 'blocked', 'L1', 'secure', '五条均被拒绝', LATER);
  let refusedRows: ProbeEvidence[] = [];
  refusedRows.push(evidence('errno', '穿越 files 一层', '穿越 stat=0xd3e86c'));
  refused.evidences = refusedRows;
  if (pickLine([disclosed, refused]) !== 'P2') {
    fail('P2 被拒时主线仍应演沙箱，不能直接进姿态披露');
  }
  let green = actFace('act2', [disclosed, refused]);
  if (green.phrase !== '五条均被拒绝' || green.ink !== 'ok' || green.outcome !== 'blocked' || green.phrase === BLOCK_WORD) {
    fail('P2 为绿时红绿应跟真实 verdict，短语不能写成阻断');
  }
  if (green.lines.join('\n').indexOf('0xd3e86c') < 0) {
    fail('P2 为绿时也要列出 raw 里的 errno');
  }
  let afterBox = actFace('act3', [disclosed, refused]);
  if (afterBox.narration.indexOf('不可被利用') >= 0 || afterBox.narration === ACT3_NARRATION || afterBox.title.indexOf('得手') >= 0) {
    fail('沙箱降级后第三幕不能念已修复');
  }
  if (pickLine([disclosed]) !== 'P3') {
    fail('P2 也没有红时，主线应转为姿态披露');
  }
  let posture = postureRun(LATER);
  let quiet = actFace('act2', [disclosed, posture]);
  if (quiet.phrase === HIT_WORD || quiet.phrase === BLOCK_WORD || quiet.outcome !== 'pending' || quiet.ink !== 'gold') {
    fail('姿态披露不能出现红绿');
  }
  if (quiet.detail !== BOUNDARY_TEXT || quiet.narration !== BOUNDARY_TEXT || quiet.title !== POSTURE_TITLE) {
    fail('姿态披露应解读 passive 证据和边界声明');
  }
  if (quiet.lines.join(' ').indexOf('sec_comp_service.cpp:163-180') < 0 || quiet.narration.indexOf('收下了') >= 0) {
    fail('姿态披露的讲解词不能说基础版收下了');
  }
  let quietEnd = actFace('act3', [disclosed, posture]);
  if (quietEnd.phrase === BLOCK_WORD || quietEnd.narration !== BOUNDARY_TEXT || quietEnd.title !== POSTURE_ACT3_TITLE) {
    fail('姿态披露的第三幕也不能写阻断或已修复');
  }
  if (quietEnd.narration.indexOf('不可被利用') >= 0) {
    fail('姿态披露不能念安装验签已经修好');
  }
  let passed = evaluateChecklist(2026, true, sightInstalled(1000000), 0);
  if (!checklistReady(passed)) {
    fail('四项真实检查都通过后才能开演');
  }
  if (checklistReady(evaluateChecklist(2021, true, sightInstalled(1000000), 0))) {
    fail('板时钟停在 2021 不能开演');
  }
  if (checklistReady(evaluateChecklist(2026, false, sightInstalled(1000000), 0))) {
    fail('没有可用侧车不能开演');
  }
  if (checklistReady(evaluateChecklist(2026, true, sightFromCode(201), 0))) {
    fail('读回没有明确结果不能开演');
  }
  if (!evaluateChecklist(2026, true, sightFromCode(BUNDLE_MISSING), 0)[1].passed) {
    fail('确认未安装应算明确结果');
  }
  let shown = new D4Event();
  shown.source = 'show';
  shown.detail = '演示稿画面，不含数据';
  if (placeholderCount([shown]) !== 1 || checklistReady(evaluateChecklist(2026, true, sightInstalled(1000000), 1))) {
    fail('事件流里的 L3 占位没清掉不能开演');
  }
  let shelf = applyKeepSidecar(emptyProbeShelf(), new SidecarReport(), AT);
  if (!sidecarReady(shelf)) {
    fail('成功导入的侧车应算最新报告');
  }
  let failed = applyImportFailure(shelf, '侧车报告不是合法的 JSON', LATER);
  if (sidecarReady(failed)) {
    fail('后一次导入失败应让最新报告不可用');
  }
}
