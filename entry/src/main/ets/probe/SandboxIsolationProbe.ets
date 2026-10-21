import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import fs from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import { nowIso } from '../model/D4Types';
import { LiveStore } from '../model/LiveStore';
import type { ImageRole, Probe, ProbeId, ProbeResult, ProofLevel, Verdict } from './ProbeTypes';
import { ANOMALY_PHRASE, NO_ANOMALY_PHRASE, ProbeEvidence } from './ProbeTypes';

const DOMAIN = 0x4A59;
const TAG = 'SandboxProbe';
const LEAF = 'com.jinyinhu.lakesidenotes/haps/entry/files/lakeside-notes.json';
const ENOENT = 13900002;
const EPERM = 13900001;
const EACCES = 13900012;
const EINVAL = 13900020;
const BAD_PARAM = 401;

class ErrorBox {
  code: number = 0;
}

class SandboxStep {
  category: string = '';
  paths: string[] = [];
}

export class FsOutcome {
  gotStat: boolean = false;
  gotHandle: boolean = false;
  statCode: number = -1;
  openCode: number = -1;
}

export class AttemptFacts {
  category: string = '';
  calls: FsOutcome[] = [];
  at: string = '';
}

export class SandboxJudge {
  decided: boolean = false;
  reason: string = '';
  verdict: Verdict = 'blocked';
  phrase: string = '';
  texts: string[] = [];
  raws: string[] = [];
  ats: string[] = [];
}

export function denialCode(code: number): boolean {
  return code === ENOENT || code === EPERM || code === EACCES || code === EINVAL || code === BAD_PARAM;
}

export function judgeSandbox(attempts: AttemptFacts[]): SandboxJudge {
  let judge = new SandboxJudge();
  let anyHit = false;
  for (let i = 0; i < attempts.length; i++) {
    let attempt = attempts[i];
    let kind = attemptKind(attempt);
    if (kind === 'unknown') {
      judge.decided = false;
      judge.reason = attempt.category + ' 未知错误 ' + unknownText(attempt);
      judge.phrase = '';
      return judge;
    }
    if (kind === 'hit') {
      anyHit = true;
    }
    let outcome = '已拒绝';
    if (kind === 'hit') {
      outcome = '已打开';
    }
    judge.texts.push(attempt.category + ' ' + outcome + ' 已脱敏');
    judge.raws.push(attemptRaw(attempt));
    judge.ats.push(attempt.at);
  }
  judge.decided = true;
  if (anyHit) {
    judge.verdict = 'hit';
    judge.phrase = ANOMALY_PHRASE;
  } else {
    judge.verdict = 'blocked';
    judge.phrase = NO_ANOMALY_PHRASE;
  }
  return judge;
}

export class SandboxIsolationProbe implements Probe {
  id: ProbeId = 'P2';
  title: string = '沙箱隔离';
  risk: string = '检测应用之间是否隔离，是否有读取私有文件的风险';
  level: ProofLevel = 'L1';

  async run(ctx: common.UIAbilityContext): Promise<ProbeResult> {
    let steps = buildSteps(ctx.filesDir);
    let facts: AttemptFacts[] = [];
    for (let i = 0; i < steps.length; i++) {
      let fact = new AttemptFacts();
      fact.category = steps[i].category;
      for (let j = 0; j < steps[i].paths.length; j++) {
        fact.calls.push(executePath(steps[i].category, steps[i].paths[j]));
      }
      fact.at = nowIso();
      facts.push(fact);
      LiveStore.advanceScan('P2', facts.length, steps.length, fact.category, attemptRaw(fact), fact.at);
      await yieldTurn();
    }
    let judged = judgeSandbox(facts);
    if (!judged.decided) {
      throw new Error(judged.reason);
    }
    let result = new ProbeResultBox();
    result.probeId = 'P2';
    result.verdict = judged.verdict;
    result.phrase = judged.phrase;
    result.level = 'L1';
    result.imageRole = imageRoleNow();
    let evidences: ProbeEvidence[] = [];
    for (let i = 0; i < judged.texts.length; i++) {
      let evidence = new ProbeEvidence();
      evidence.kind = 'errno';
      evidence.text = judged.texts[i];
      evidence.raw = judged.raws[i];
      evidence.at = judged.ats[i];
      evidences.push(evidence);
    }
    result.evidences = evidences;
    result.createdAt = judged.ats.length > 0 ? judged.ats[judged.ats.length - 1] : nowIso();
    return result;
  }
}

class ProbeResultBox implements ProbeResult {
  probeId: ProbeId = 'P2';
  verdict: Verdict = 'blocked';
  phrase: string = '';
  level: ProofLevel = 'L1';
  imageRole: ImageRole | '' = '';
  evidences: ProbeEvidence[] = [];
  createdAt: string = '';
}

function yieldTurn(): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(resolve, 0);
  });
}

function buildSteps(filesDir: string): SandboxStep[] {
  let prefix = trimSlash(filesDir);
  let landing = LEAF;
  let variant = '../../../../' + LEAF;
  let encoded = '%2E%2E%2F%2E%2E%2F%2E%2E%2F%2E%2E%2F' + LEAF;
  if (prefix.length > 0) {
    landing = prefix + '/../../../' + LEAF;
    variant = prefix + '/../../../../' + LEAF;
    encoded = prefix + '/%2E%2E%2F%2E%2E%2F%2E%2E%2F%2E%2E%2F' + LEAF;
  }
  let steps: SandboxStep[] = [];
  steps.push(stepOf('明文相对路径', [landing, variant]));
  steps.push(stepOf('编码路径', [encoded]));
  steps.push(stepOf('外部存储', ['file://docs/storage/Users/currentUser/Download/lakeside-notes.json']));
  steps.push(stepOf('跨包URI', ['file://com.jinyinhu.lakesidenotes/data/storage/el2/base/haps/entry/files/lakeside-notes.json']));
  steps.push(stepOf('姿态URI', ['file://media/lakeside-notes.json']));
  return steps;
}

function stepOf(category: string, paths: string[]): SandboxStep {
  let step = new SandboxStep();
  step.category = category;
  step.paths = paths;
  return step;
}

function trimSlash(filesDir: string): string {
  let prefix = '';
  if (typeof filesDir === 'string') {
    prefix = filesDir;
  }
  while (prefix.length > 0 && prefix.charAt(prefix.length - 1) === '/') {
    prefix = prefix.substring(0, prefix.length - 1);
  }
  return prefix;
}

function executePath(category: string, path: string): FsOutcome {
  let outcome = new FsOutcome();
  try {
    fs.statSync(path);
    outcome.gotStat = true;
  } catch (err) {
    let boxed: ErrorBox = err as ErrorBox;
    outcome.statCode = numericCode(boxed);
    hilog.error(DOMAIN, TAG, '%{public}s stat %{public}s', category, hexErrno(outcome.statCode));
  }
  try {
    let opened = fs.openSync(path, fs.OpenMode.READ_ONLY);
    outcome.gotHandle = true;
    try {
      fs.closeSync(opened);
    } catch (closeErr) {
      let boxed: ErrorBox = closeErr as ErrorBox;
      hilog.error(DOMAIN, TAG, '%{public}s close %{public}s', category, hexErrno(numericCode(boxed)));
    }
  } catch (err) {
    let boxed: ErrorBox = err as ErrorBox;
    outcome.openCode = numericCode(boxed);
    hilog.error(DOMAIN, TAG, '%{public}s open %{public}s', category, hexErrno(outcome.openCode));
  }
  followUri(category, path, outcome);
  return outcome;
}

function followUri(category: string, path: string, outcome: FsOutcome): void {
  if (outcome.gotStat || outcome.gotHandle || path.indexOf('file:') !== 0) {
    return;
  }
  let resolved = '';
  try {
    let parsed = new fileUri.FileUri(path);
    resolved = parsed.path;
  } catch (err) {
    hilog.error(DOMAIN, TAG, '%{public}s uri %{public}s', category, 'na');
    return;
  }
  if (resolved.length === 0 || resolved === path) {
    return;
  }
  try {
    fs.statSync(resolved);
    outcome.gotStat = true;
  } catch (err) {
    let boxed: ErrorBox = err as ErrorBox;
    outcome.statCode = numericCode(boxed);
  }
  try {
    let opened = fs.openSync(resolved, fs.OpenMode.READ_ONLY);
    outcome.gotHandle = true;
    try {
      fs.closeSync(opened);
    } catch (closeErr) {
      hilog.error(DOMAIN, TAG, '%{public}s close %{public}s', category, 'na');
    }
  } catch (err) {
    let boxed: ErrorBox = err as ErrorBox;
    outcome.openCode = numericCode(boxed);
    hilog.error(DOMAIN, TAG, '%{public}s resolved %{public}s', category, hexErrno(outcome.openCode));
  }
}

function attemptKind(attempt: AttemptFacts): string {
  let unknown = false;
  for (let i = 0; i < attempt.calls.length; i++) {
    let kind = callKind(attempt.calls[i]);
    if (kind === 'hit') {
      return 'hit';
    }
    if (kind === 'unknown') {
      unknown = true;
    }
  }
  if (unknown || attempt.calls.length === 0) {
    return 'unknown';
  }
  return 'denial';
}

function callKind(call: FsOutcome): string {
  if (call.gotHandle) {
    return 'hit';
  }
  if (call.gotStat) {
    return denialCode(call.openCode) ? 'denial' : 'hit';
  }
  if (denialCode(call.statCode) && denialCode(call.openCode)) {
    return 'denial';
  }
  return 'unknown';
}

function attemptRaw(attempt: AttemptFacts): string {
  if (attempt.calls.length === 1) {
    return callRaw(attempt.calls[0]);
  }
  let parts = '';
  for (let i = 0; i < attempt.calls.length; i++) {
    if (i > 0) {
      parts += ' ';
    }
    if (i === 0) {
      parts += '落点 ' + callRaw(attempt.calls[i]);
    } else {
      parts += '穿越 ' + callRaw(attempt.calls[i]);
    }
  }
  return parts;
}

function callRaw(call: FsOutcome): string {
  if (call.gotStat && call.gotHandle) {
    return '拿到stat 拿到句柄';
  }
  if (call.gotStat) {
    return '拿到stat';
  }
  if (call.gotHandle) {
    return 'stat=' + hexErrno(call.statCode) + ' 拿到句柄';
  }
  return 'stat=' + hexErrno(call.statCode) + ' open=' + hexErrno(call.openCode);
}

function unknownText(attempt: AttemptFacts): string {
  for (let i = 0; i < attempt.calls.length; i++) {
    if (callKind(attempt.calls[i]) === 'unknown') {
      return callRaw(attempt.calls[i]);
    }
  }
  return 'na';
}

function imageRoleNow(): ImageRole | '' {
  let shelf = LiveStore.shelf();
  if (shelf.sidecarPresent && shelf.sidecar.imageTag === 'secure') {
    return 'secure';
  }
  if (shelf.sidecarPresent && shelf.sidecar.imageTag === 'base') {
    return 'base';
  }
  return '';
}

function numericCode(boxed: ErrorBox): number {
  if (typeof boxed.code === 'number' && boxed.code === boxed.code) {
    return boxed.code;
  }
  return -1;
}

function hexErrno(code: number): string {
  if (typeof code !== 'number' || code !== code || code < 0) {
    return 'na';
  }
  return '0x' + code.toString(16);
}
