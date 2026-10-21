import { common } from '@kit.AbilityKit';
import { nowIso } from '../model/D4Types';
import { LiveStore } from '../model/LiveStore';
import { Findings } from '../report/Findings';
import { acceptProbeRun } from './ProbeCodec';
import type { ImageRole, Probe, ProbeId, ProbeResult, ProbeShelf, ProofLevel } from './ProbeTypes';
import { POSTURE_CLEAR_PHRASE, ProbeEvidence, ProbeRun, VERIFY_REJECT_CODE, isStamp } from './ProbeTypes';
import { loadRejectCode } from './UpdateReject';

const REPORT_TEXT = '系统组件在本镜像可注册可回报';
const PHRASE_LISTED = '四条引用已列出';
const PHRASE_REPORTED = '组件可回报';
const PASTE_PREFIX = 'PasteButton:';

export class PostureNote {
  raw: string = '';
  text: string = '';
}

export class SecCompPostureProbe implements Probe {
  id: ProbeId = 'P3';
  title: string = '安全组件姿态';
  risk: string = '检测安全控件是否可信，是否有绕过授权的风险';
  level: ProofLevel = 'L3';

  async run(ctx: common.UIAbilityContext): Promise<ProbeResult> {
    if (ctx === undefined) {
      throw new Error('没有应用上下文');
    }
    if (postureSecured(ctx.filesDir)) {
      return buildSecurePosture(nowIso());
    }
    return buildPostureResult(imageRoleNow(), nowIso());
  }

  static noteClick(at: string, token: string): void {
    if (!isStamp(at)) {
      throw new Error('点击时间无法落盘');
    }
    let result = buildClickResult(at, token, imageRoleNow());
    let accepted = acceptProbeRun('P3', result);
    if (!accepted.ok) {
      throw new Error(accepted.reason);
    }
    LiveStore.appendProbeRun(accepted.run);
    try {
      Findings.record(accepted.run);
    } catch (err) {
      LiveStore.setStatus('台账写入失败');
    }
  }
}

export function postureNotes(): PostureNote[] {
  let rows: PostureNote[] = [];
  rows.push(note('window_info_helper.cpp:168-170', 'windowId 含 UIExtension 位时直接跳过覆盖检查'));
  rows.push(note('sec_comp_entity.cpp:53-78', '点击时间戳只查 5 秒窗且由调用方自报'));
  rows.push(note('sec_comp_malicious_apps.cpp', '自 2026-07-14 起连续失败 3 次才入恶意名单，commit 1f86d2d'));
  rows.push(note('sec_comp_service.cpp:163-180', '前台 HAP 门槛，当前唯一硬门槛'));
  return rows;
}

export function buildSecurePosture(createdAt: string): ProbeResult {
  let result = new ProbeRun();
  result.probeId = 'P3';
  result.verdict = 'blocked';
  result.level = 'L2';
  result.phrase = POSTURE_CLEAR_PHRASE;
  result.imageRole = 'secure';
  result.createdAt = isStamp(createdAt) ? createdAt : nowIso();
  let evidences: ProbeEvidence[] = [];
  evidences.push(sourceEvidence(note('sec_comp_service.cpp:163-180', '安全版已收紧安全控件'), result.createdAt));
  result.evidences = evidences;
  return result;
}

export function buildPostureResult(imageRole: ImageRole | '', createdAt: string): ProbeResult {
  let result = new ProbeRun();
  result.probeId = 'P3';
  result.verdict = 'passive';
  result.level = 'L3';
  result.phrase = PHRASE_LISTED;
  result.imageRole = imageRole === 'base' || imageRole === 'secure' ? imageRole : '';
  result.createdAt = isStamp(createdAt) ? createdAt : nowIso();
  let evidences: ProbeEvidence[] = [];
  let notes = postureNotes();
  for (let i = 0; i < notes.length; i++) {
    evidences.push(sourceEvidence(notes[i], result.createdAt));
  }
  result.evidences = evidences;
  return result;
}

export function buildClickResult(clickAt: string, token: string, imageRole: ImageRole | ''): ProbeResult {
  let result = new ProbeRun();
  result.probeId = 'P3';
  result.verdict = 'passive';
  result.level = 'L1';
  result.phrase = PHRASE_REPORTED;
  result.imageRole = imageRole === 'base' || imageRole === 'secure' ? imageRole : '';
  result.createdAt = clickAt;
  let evidences: ProbeEvidence[] = [];
  evidences.push(clickEvidence(clickAt, token));
  result.evidences = evidences;
  return result;
}

export function isPasteRaw(raw: string): boolean {
  return typeof raw === 'string' && raw.indexOf(PASTE_PREFIX) === 0;
}

function note(raw: string, text: string): PostureNote {
  let row = new PostureNote();
  row.raw = raw;
  row.text = text;
  return row;
}

function sourceEvidence(row: PostureNote, at: string): ProbeEvidence {
  let evidence = new ProbeEvidence();
  evidence.kind = 'source-ref';
  evidence.text = row.text;
  evidence.raw = row.raw;
  evidence.at = at;
  return evidence;
}

function clickEvidence(at: string, token: string): ProbeEvidence {
  let evidence = new ProbeEvidence();
  evidence.kind = 'hilog-line';
  evidence.text = REPORT_TEXT;
  evidence.raw = PASTE_PREFIX + cleanToken(token);
  evidence.at = at;
  return evidence;
}

function cleanToken(token: string): string {
  if (token === 'SUCCESS' || token === 'TEMPORARY_AUTHORIZATION_FAILED') {
    return token;
  }
  return 'CALLBACK';
}

function postureSecured(filesDir: string): boolean {
  if (imageRoleNow() === 'secure') {
    return true;
  }
  if (loadRejectCode(filesDir) === VERIFY_REJECT_CODE) {
    return true;
  }
  return sandboxBlocked();
}

function sandboxBlocked(): boolean {
  let shelf = LiveStore.shelf();
  return blockedRun(shelf);
}

function blockedRun(shelf: ProbeShelf): boolean {
  let runs = shelf.runs;
  for (let i = runs.length - 1; i >= 0; i--) {
    if (runs[i].probeId !== 'P2' || runs[i].verdict !== 'blocked') {
      continue;
    }
    let faults = shelf.runFaults;
    for (let j = 0; j < faults.length; j++) {
      if (faults[j].probeId === 'P2' && faults[j].at >= runs[i].createdAt) {
        return false;
      }
    }
    return true;
  }
  return false;
}

function imageRoleNow(): ImageRole | '' {
  let shelf = LiveStore.shelf();
  if (shelf !== undefined && shelf.sidecarPresent && shelf.sidecar !== undefined && shelf.sidecar.imageTag === 'secure') {
    return 'secure';
  }
  if (shelf !== undefined && shelf.sidecarPresent && shelf.sidecar !== undefined && shelf.sidecar.imageTag === 'base') {
    return 'base';
  }
  return '';
}
