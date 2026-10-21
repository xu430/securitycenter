import { common } from '@kit.AbilityKit';

/**
 * 探针契约。字段名与架构 §5.1、§10 一致。
 * LocalProbe：run 内直接执行，L1，API 返回即证据。
 * OrchestratedProbe：真执行在 PC 侧车，本端只导入回显并读回核验，L2。
 * 编解码在 ProbeCodec.ets，本文件不执行 P1 / P2 / P3。
 */

export type Verdict = 'hit' | 'blocked' | 'passive';
export type ProofLevel = 'L1' | 'L2' | 'L3';
export type ProbeId = 'P1' | 'P2' | 'P3';
export type ImageRole = 'base' | 'secure';
export type EvidenceKind = 'errno' | 'bundle-state' | 'hilog-line' | 'source-ref' | 'cmd-transcript' | 'sidecar-state';

export class ProbeLimits {
  static readonly schemaSidecar: string = 'jinyinhu.sidecar.report';
  static readonly schemaShelf: string = 'jinyinhu.probe.shelf';
  static readonly schemaVersion: string = '0.1';
  static readonly phraseMax: number = 12;
  static readonly evidenceTextMax: number = 400;
  static readonly rawMax: number = 8000;
  static readonly evidenceMax: number = 16;
  static readonly runMax: number = 30;
  static readonly stepMax: number = 8;
  static readonly sidecarTextMax: number = 100000;
  static readonly shelfTextMax: number = 800000;
  static readonly udidMax: number = 128;
  static readonly stampLength: number = 25;
  static readonly descMax: number = 200;
  static readonly cmdMax: number = 500;
  static readonly transcriptMax: number = 8000;
  static readonly reasonMax: number = 200;
  static readonly retCodeAbs: number = 1000000;
  static readonly importIdle: string = 'idle';
  static readonly importFailed: string = 'failed';
  static readonly importImported: string = 'imported';
}

export const VERIFY_REJECT_CODE: number = 17700011;
export const SYSTEM_REJECT_PHRASE: string = '系统拒绝了更新';
export const INSTALL_CLEAR_PHRASE: string = '安装包校验通过';
export const POSTURE_CLEAR_PHRASE: string = '控件已收紧';
export const ANOMALY_PHRASE: string = '发现异常';
export const NO_ANOMALY_PHRASE: string = '暂未发现异常';

export interface Evidence {
  kind: EvidenceKind;
  text: string;
  raw: string;
  at: string;
}

export interface ProbeResult {
  probeId: ProbeId;
  verdict: Verdict;
  phrase: string;
  level: ProofLevel;
  imageRole: ImageRole | '';
  evidences: Evidence[];
  createdAt: string;
}

export interface Probe {
  id: ProbeId;
  title: string;
  risk: string;
  level: ProofLevel;
  run(ctx: common.UIAbilityContext): Promise<ProbeResult>;
}

export interface ProbeSource {
  create(): Probe;
}

@Observed
export class ProbeEvidence implements Evidence {
  kind: EvidenceKind = 'source-ref';
  text: string = '';
  raw: string = '';
  at: string = '';
}

@Observed
export class ProbeRun implements ProbeResult {
  probeId: ProbeId = 'P1';
  verdict: Verdict = 'passive';
  phrase: string = '';
  level: ProofLevel = 'L3';
  imageRole: ImageRole | '' = '';
  evidences: ProbeEvidence[] = [];
  createdAt: string = '';
}

@Observed
export class ProbeRunFault {
  probeId: ProbeId = 'P1';
  reason: string = '';
  at: string = '';
}

@Observed
export class SidecarStep {
  state: number = 0;
  desc: string = '';
  cmd: string = '';
  retCode: number = 0;
  transcript: string = '';
  at: string = '';
}

@Observed
export class SidecarReport {
  schema: string = ProbeLimits.schemaSidecar;
  schemaVersion: string = ProbeLimits.schemaVersion;
  imageTag: string = '';
  boardUdid: string = '';
  boardClockAtRun: string = '';
  matrix: SidecarStep[] = [];
}

@Observed
export class ProbeShelf {
  runs: ProbeRun[] = [];
  sidecarPresent: boolean = false;
  sidecar: SidecarReport = new SidecarReport();
  importState: string = ProbeLimits.importIdle;
  importAt: string = '';
  failureReason: string = '';
  failureAt: string = '';
  boardUdid: string = '';
  runFaults: ProbeRunFault[] = [];
}

export function emptyProbeShelf(): ProbeShelf {
  return new ProbeShelf();
}

export function asVerdict(value: string): Verdict | undefined {
  if (value === 'hit' || value === 'blocked' || value === 'passive') {
    return value;
  }
  return undefined;
}

export function asProofLevel(value: string): ProofLevel | undefined {
  if (value === 'L1' || value === 'L2' || value === 'L3') {
    return value;
  }
  return undefined;
}

export function asProbeId(value: string): ProbeId | undefined {
  if (value === 'P1' || value === 'P2' || value === 'P3') {
    return value;
  }
  return undefined;
}

export function asImageRole(value: string): ImageRole | undefined {
  if (value === 'base' || value === 'secure') {
    return value;
  }
  return undefined;
}

export function asStoredImageRole(value: string): ImageRole | '' | undefined {
  if (value === '') {
    return '';
  }
  return asImageRole(value);
}

export function asEvidenceKind(value: string): EvidenceKind | undefined {
  if (value === 'errno' || value === 'bundle-state' || value === 'hilog-line' ||
    value === 'source-ref' || value === 'cmd-transcript' || value === 'sidecar-state') {
    return value;
  }
  return undefined;
}

export function isVerdict(value: string): boolean {
  return asVerdict(value) !== undefined;
}

export function isProofLevel(value: string): boolean {
  return asProofLevel(value) !== undefined;
}

export function isProbeId(value: string): boolean {
  return asProbeId(value) !== undefined;
}

export function isImageRole(value: string): boolean {
  return asImageRole(value) !== undefined;
}

export function isEvidenceKind(value: string): boolean {
  return asEvidenceKind(value) !== undefined;
}

export function isStamp(value: string): boolean {
  if (typeof value !== 'string' || value.length !== ProbeLimits.stampLength) {
    return false;
  }
  if (value.charAt(4) !== '-' || value.charAt(7) !== '-' || value.charAt(10) !== 'T') {
    return false;
  }
  if (value.charAt(13) !== ':' || value.charAt(16) !== ':') {
    return false;
  }
  let sign = value.charAt(19);
  if (sign !== '+' && sign !== '-') {
    return false;
  }
  if (value.charAt(22) !== ':') {
    return false;
  }
  let year = readDigits(value, 0, 4);
  let month = readDigits(value, 5, 2);
  let day = readDigits(value, 8, 2);
  let hour = readDigits(value, 11, 2);
  let minute = readDigits(value, 14, 2);
  let second = readDigits(value, 17, 2);
  let offHour = readDigits(value, 20, 2);
  let offMinute = readDigits(value, 23, 2);
  if (year === undefined || month === undefined || day === undefined || hour === undefined) {
    return false;
  }
  if (minute === undefined || second === undefined || offHour === undefined || offMinute === undefined) {
    return false;
  }
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return false;
  }
  if (hour > 23 || minute > 59 || second > 59 || offHour > 23 || offMinute > 59) {
    return false;
  }
  let parsed = Date.parse(value);
  if (!isFiniteNumber(parsed)) {
    return false;
  }
  let offset = offHour * 60 + offMinute;
  if (sign === '-') {
    offset = -offset;
  }
  let shifted = new Date(parsed + offset * 60000);
  if (shifted.getUTCFullYear() !== year || shifted.getUTCMonth() + 1 !== month) {
    return false;
  }
  if (shifted.getUTCDate() !== day || shifted.getUTCHours() !== hour) {
    return false;
  }
  if (shifted.getUTCMinutes() !== minute || shifted.getUTCSeconds() !== second) {
    return false;
  }
  return true;
}

export function isTightLine(value: string, max: number): boolean {
  if (typeof value !== 'string' || value.length < 1 || value.length > max) {
    return false;
  }
  if (value !== value.trim()) {
    return false;
  }
  if (value.indexOf('\n') >= 0 || value.indexOf('\r') >= 0) {
    return false;
  }
  return true;
}

export function cleanUdid(value: string): string {
  if (typeof value !== 'string') {
    return '';
  }
  let trimmed = value.trim();
  if (trimmed.length > ProbeLimits.udidMax) {
    return '';
  }
  if (trimmed.indexOf('\n') >= 0 || trimmed.indexOf('\r') >= 0) {
    return '';
  }
  return trimmed;
}

export function oneLineOrEmpty(value: string, max: number): string {
  if (typeof value !== 'string' || value.length === 0) {
    return '';
  }
  if (value.length > max || value.indexOf('\n') >= 0 || value.indexOf('\r') >= 0) {
    return '';
  }
  return value;
}

export function stampOrEmpty(value: string): string {
  if (typeof value === 'string' && isStamp(value)) {
    return value;
  }
  return '';
}

export function clampReason(value: string, fallback: string): string {
  if (typeof value !== 'string') {
    return fallback;
  }
  let line = value;
  let newline = line.indexOf('\n');
  if (newline >= 0) {
    line = line.substring(0, newline);
  }
  let carriage = line.indexOf('\r');
  if (carriage >= 0) {
    line = line.substring(0, carriage);
  }
  line = line.trim();
  if (line.length === 0) {
    return fallback;
  }
  if (line.length > ProbeLimits.reasonMax) {
    return line.substring(0, ProbeLimits.reasonMax);
  }
  return line;
}

export function copyProbeRun(raw: ProbeRun): ProbeRun {
  let run = new ProbeRun();
  run.probeId = raw.probeId;
  run.verdict = raw.verdict;
  run.phrase = raw.phrase;
  run.level = raw.level;
  run.imageRole = raw.imageRole;
  run.createdAt = raw.createdAt;
  let evidences: ProbeEvidence[] = [];
  for (let i = 0; i < raw.evidences.length; i++) {
    evidences.push(copyEvidence(raw.evidences[i]));
  }
  run.evidences = evidences;
  return run;
}

export function copySidecar(raw: SidecarReport): SidecarReport {
  let report = new SidecarReport();
  report.schema = raw.schema;
  report.schemaVersion = raw.schemaVersion;
  report.imageTag = raw.imageTag;
  report.boardUdid = raw.boardUdid;
  report.boardClockAtRun = raw.boardClockAtRun;
  let matrix: SidecarStep[] = [];
  for (let i = 0; i < raw.matrix.length; i++) {
    matrix.push(copyStep(raw.matrix[i]));
  }
  report.matrix = matrix;
  return report;
}

export function copyShelf(raw: ProbeShelf): ProbeShelf {
  let shelf = new ProbeShelf();
  let runs: ProbeRun[] = [];
  for (let i = 0; i < raw.runs.length; i++) {
    runs.push(copyProbeRun(raw.runs[i]));
  }
  shelf.runs = runs;
  shelf.sidecarPresent = raw.sidecarPresent;
  shelf.sidecar = copySidecar(raw.sidecar);
  shelf.importState = raw.importState;
  shelf.importAt = raw.importAt;
  shelf.failureReason = raw.failureReason;
  shelf.failureAt = raw.failureAt;
  shelf.boardUdid = raw.boardUdid;
  let faults: ProbeRunFault[] = [];
  for (let i = 0; i < raw.runFaults.length; i++) {
    faults.push(copyFault(raw.runFaults[i]));
  }
  shelf.runFaults = faults;
  return shelf;
}

function copyEvidence(raw: ProbeEvidence): ProbeEvidence {
  let evidence = new ProbeEvidence();
  evidence.kind = raw.kind;
  evidence.text = raw.text;
  evidence.raw = raw.raw;
  evidence.at = raw.at;
  return evidence;
}

function copyStep(raw: SidecarStep): SidecarStep {
  let step = new SidecarStep();
  step.state = raw.state;
  step.desc = raw.desc;
  step.cmd = raw.cmd;
  step.retCode = raw.retCode;
  step.transcript = raw.transcript;
  step.at = raw.at;
  return step;
}

function copyFault(raw: ProbeRunFault): ProbeRunFault {
  let fault = new ProbeRunFault();
  fault.probeId = raw.probeId;
  fault.reason = raw.reason;
  fault.at = raw.at;
  return fault;
}

function readDigits(value: string, start: number, count: number): number | undefined {
  let parsed = 0;
  for (let i = 0; i < count; i++) {
    let code = value.charCodeAt(start + i);
    if (code < 48 || code > 57) {
      return undefined;
    }
    parsed = parsed * 10 + (code - 48);
  }
  return parsed;
}

function isFiniteNumber(value: number): boolean {
  return typeof value === 'number' && value === value;
}
