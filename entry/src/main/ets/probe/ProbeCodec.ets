import type { Evidence, ProbeId, ProbeResult, ProbeShelf } from './ProbeTypes';
import {
  ProbeEvidence,
  ProbeLimits,
  ProbeRun,
  ProbeRunFault,
  SidecarReport,
  SidecarStep,
  asEvidenceKind,
  asImageRole,
  asProbeId,
  asProofLevel,
  asStoredImageRole,
  asVerdict,
  clampReason,
  cleanUdid,
  copyProbeRun,
  copyShelf,
  copySidecar,
  emptyProbeShelf,
  isEvidenceKind,
  isImageRole,
  isProbeId,
  isProofLevel,
  isStamp,
  isTightLine,
  isVerdict,
  oneLineOrEmpty,
  stampOrEmpty
} from './ProbeTypes';

export class SidecarAccept {
  ok: boolean = false;
  reason: string = '';
  report: SidecarReport = new SidecarReport();
}

export class ProbeRunAccept {
  ok: boolean = false;
  reason: string = '';
  run: ProbeRun = new ProbeRun();
}

class SidecarPeek {
  schema: string = '';
  schemaVersion: string = '';
  imageTag: string = '';
  boardUdid: string = '';
  boardClockAtRun: string = '';
  matrix: StepPeek[] = [];
}

class StepPeek {
  state: number = 0;
  desc: string = '';
  cmd: string = '';
  retCode: number = 0;
  transcript: string = '';
  at: string = '';
}

class ShelfPeek {
  schema: string = '';
  schemaVersion: string = '';
  boardUdid: string = '';
  importState: string = '';
  importReason: string = '';
  importAt: string = '';
  failureReason: string = '';
  failureAt: string = '';
  sidecarPresent: boolean = false;
  sidecar: SidecarPeek = new SidecarPeek();
  runs: RunPeek[] = [];
  runFaults: FaultPeek[] = [];
}

class RunPeek {
  probeId: string = '';
  verdict: string = '';
  phrase: string = '';
  level: string = '';
  imageRole: string = '';
  evidences: EvidencePeek[] = [];
  createdAt: string = '';
}

class EvidencePeek {
  kind: string = '';
  text: string = '';
  raw: string = '';
  at: string = '';
}

class FaultPeek {
  probeId: string = '';
  reason: string = '';
  at: string = '';
}

class RunListRead {
  ok: boolean = false;
  runs: ProbeRun[] = [];
}

class FaultListRead {
  ok: boolean = false;
  faults: ProbeRunFault[] = [];
}

export function acceptSidecar(text: string, registeredUdid: string): SidecarAccept {
  let failed = new SidecarAccept();
  if (typeof text !== 'string' || text.trim().length === 0) {
    failed.reason = '侧车报告是空的';
    return failed;
  }
  if (text.length > ProbeLimits.sidecarTextMax) {
    failed.reason = '侧车报告过长';
    return failed;
  }
  let trimmed = stripBom(text.trim());
  if (trimmed.charAt(0) !== '{') {
    failed.reason = '侧车报告不是对象';
    return failed;
  }
  try {
    let parsed = JSON.parse(trimmed) as SidecarPeek;
    if (!parsed || typeof parsed !== 'object' || parsed instanceof Array) {
      failed.reason = '侧车报告不是对象';
      return failed;
    }
    return readSidecar(parsed, true, registeredUdid);
  } catch (err) {
    failed.reason = '侧车报告不是合法的 JSON';
    return failed;
  }
}

export function acceptSidecarReport(report: SidecarReport, registeredUdid: string): SidecarAccept {
  return acceptSidecar(formatSidecarDocument(report), registeredUdid);
}

export function acceptProbeRun(expectedId: string, raw: ProbeResult): ProbeRunAccept {
  let failed = new ProbeRunAccept();
  if (!raw || typeof raw !== 'object') {
    failed.reason = '探针没有返回结果';
    return failed;
  }
  if (typeof raw.probeId !== 'string' || raw.probeId !== expectedId || asProbeId(raw.probeId) === undefined) {
    failed.reason = '探针编号不一致';
    return failed;
  }
  if (typeof raw.verdict !== 'string' || asVerdict(raw.verdict) === undefined) {
    failed.reason = '探针结论无法落盘';
    return failed;
  }
  if (typeof raw.level !== 'string' || asProofLevel(raw.level) === undefined) {
    failed.reason = '探针结论无法落盘';
    return failed;
  }
  if ((raw.verdict === 'hit' || raw.verdict === 'blocked') && raw.level === 'L3') {
    failed.reason = '探针结论无法落盘';
    return failed;
  }
  if (typeof raw.phrase !== 'string' || !isTightLine(raw.phrase, ProbeLimits.phraseMax)) {
    failed.reason = phraseProblem(raw.phrase);
    return failed;
  }
  if (typeof raw.imageRole !== 'string' || asStoredImageRole(raw.imageRole) === undefined) {
    failed.reason = '探针结论无法落盘';
    return failed;
  }
  if (typeof raw.createdAt !== 'string' || !isStamp(raw.createdAt)) {
    failed.reason = '探针结论无法落盘';
    return failed;
  }
  if (!(raw.evidences instanceof Array) || raw.evidences.length > ProbeLimits.evidenceMax) {
    failed.reason = '证据无法落盘';
    return failed;
  }
  let run = new ProbeRun();
  run.probeId = raw.probeId;
  run.verdict = raw.verdict;
  run.phrase = raw.phrase;
  run.level = raw.level;
  run.imageRole = raw.imageRole;
  run.createdAt = raw.createdAt;
  let evidences: ProbeEvidence[] = [];
  for (let i = 0; i < raw.evidences.length; i++) {
    let copied = readEvidence(raw.evidences[i]);
    if (copied === undefined) {
      failed.reason = '证据无法落盘';
      return failed;
    }
    evidences.push(copied);
  }
  run.evidences = evidences;
  let accepted = new ProbeRunAccept();
  accepted.ok = true;
  accepted.run = run;
  return accepted;
}

export function applyImportFailure(shelf: ProbeShelf, reason: string, at: string): ProbeShelf {
  let next = copyShelf(shelf);
  next.failureReason = clampReason(reason, '导入失败');
  next.failureAt = at;
  if (next.sidecarPresent && next.importState === ProbeLimits.importImported) {
    return next;
  }
  next.sidecarPresent = false;
  next.sidecar = new SidecarReport();
  next.importState = ProbeLimits.importIdle;
  next.importAt = '';
  return next;
}

export function applyKeepSidecar(shelf: ProbeShelf, report: SidecarReport, at: string): ProbeShelf {
  let next = copyShelf(shelf);
  next.sidecar = copySidecar(report);
  next.sidecarPresent = true;
  next.importState = ProbeLimits.importImported;
  next.importAt = at;
  next.failureReason = '';
  next.failureAt = '';
  return next;
}

export function applyAppendRun(shelf: ProbeShelf, run: ProbeRun): ProbeShelf {
  let next = copyShelf(shelf);
  let runs: ProbeRun[] = [];
  for (let i = 0; i < next.runs.length; i++) {
    runs.push(next.runs[i]);
  }
  runs.push(copyProbeRun(run));
  while (runs.length > ProbeLimits.runMax) {
    let trimmed: ProbeRun[] = [];
    for (let i = 1; i < runs.length; i++) {
      trimmed.push(runs[i]);
    }
    runs = trimmed;
  }
  next.runs = runs;
  next.runFaults = faultsExcept(next.runFaults, run.probeId);
  return next;
}

export function applyRunFault(shelf: ProbeShelf, probeId: ProbeId, reason: string, at: string): ProbeShelf {
  let next = copyShelf(shelf);
  let faults = faultsExcept(next.runFaults, probeId);
  let fault = new ProbeRunFault();
  fault.probeId = probeId;
  fault.reason = clampReason(reason, '探针没有落盘');
  fault.at = at;
  faults.push(fault);
  next.runFaults = faults;
  return next;
}

export function formatProbeShelf(shelf: ProbeShelf): string {
  if (shelf.runs.length > ProbeLimits.runMax) {
    throw new Error('探针记录超过 30 条');
  }
  for (let i = 0; i < shelf.runs.length; i++) {
    if (!writableRun(shelf.runs[i])) {
      throw new Error('探针记录无法写入');
    }
  }
  for (let i = 0; i < shelf.runFaults.length; i++) {
    if (!writableFault(shelf.runFaults[i])) {
      throw new Error('探针记录无法写入');
    }
  }
  if (shelf.sidecarPresent && !writableSidecar(shelf.sidecar)) {
    throw new Error('探针记录无法写入');
  }
  let imported = shelf.sidecarPresent && shelf.importState === ProbeLimits.importImported;
  let lines = '{\n';
  lines += '  "schema": ' + quote(ProbeLimits.schemaShelf) + ',\n';
  lines += '  "schemaVersion": ' + quote(ProbeLimits.schemaVersion) + ',\n';
  lines += '  "boardUdid": ' + quote(cleanUdid(shelf.boardUdid)) + ',\n';
  lines += '  "importState": ' + quote(imported ? ProbeLimits.importImported : ProbeLimits.importIdle) + ',\n';
  lines += '  "importAt": ' + quote(imported ? stampOrEmpty(shelf.importAt) : '') + ',\n';
  lines += '  "failureReason": ' + quote(oneLineOrEmpty(shelf.failureReason, ProbeLimits.reasonMax)) + ',\n';
  lines += '  "failureAt": ' + quote(stampOrEmpty(shelf.failureAt)) + ',\n';
  lines += '  "sidecarPresent": ' + (shelf.sidecarPresent ? 'true' : 'false') + ',\n';
  if (shelf.sidecarPresent) {
    lines += '  "sidecar": ' + formatSidecar(shelf.sidecar, '  ') + ',\n';
  }
  lines += '  "runs": [\n';
  for (let i = 0; i < shelf.runs.length; i++) {
    if (i > 0) {
      lines += ',\n';
    }
    lines += formatRun(shelf.runs[i], '    ');
  }
  if (shelf.runs.length > 0) {
    lines += '\n';
  }
  lines += '  ],\n';
  lines += '  "runFaults": [\n';
  for (let i = 0; i < shelf.runFaults.length; i++) {
    if (i > 0) {
      lines += ',\n';
    }
    lines += formatFault(shelf.runFaults[i], '    ');
  }
  if (shelf.runFaults.length > 0) {
    lines += '\n';
  }
  lines += '  ]\n}\n';
  return lines;
}

export function parseProbeShelf(text: string): ProbeShelf | undefined {
  if (typeof text !== 'string' || text.length === 0 || text.length > ProbeLimits.shelfTextMax) {
    return undefined;
  }
  try {
    let trimmed = stripBom(text.trim());
    if (trimmed.charAt(0) !== '{') {
      return undefined;
    }
    let parsed = JSON.parse(trimmed) as ShelfPeek;
    if (!parsed || typeof parsed !== 'object' || parsed instanceof Array) {
      return undefined;
    }
    if (parsed.schema !== ProbeLimits.schemaShelf || parsed.schemaVersion !== ProbeLimits.schemaVersion) {
      return undefined;
    }
    let runs = readRuns(parsed.runs);
    if (!runs.ok) {
      return undefined;
    }
    let faults = readFaults(parsed.runFaults);
    if (!faults.ok) {
      return undefined;
    }
    let shelf = emptyProbeShelf();
    shelf.boardUdid = cleanUdid(typeof parsed.boardUdid === 'string' ? parsed.boardUdid : '');
    shelf.runs = runs.runs;
    shelf.runFaults = faults.faults;
    let legacyFailed = parsed.importState === ProbeLimits.importFailed;
    let failureReason = '';
    if (typeof parsed.failureReason === 'string' && parsed.failureReason.length > 0) {
      failureReason = parsed.failureReason;
    } else if (legacyFailed && typeof parsed.importReason === 'string') {
      failureReason = parsed.importReason;
    }
    let failureAt = '';
    if (typeof parsed.failureAt === 'string' && parsed.failureAt.length > 0) {
      failureAt = parsed.failureAt;
    } else if (legacyFailed && typeof parsed.importAt === 'string') {
      failureAt = parsed.importAt;
    }
    shelf.failureReason = oneLineOrEmpty(failureReason, ProbeLimits.reasonMax);
    shelf.failureAt = stampOrEmpty(failureAt);
    if (parsed.sidecarPresent === true) {
      let sidecar = readSidecar(parsed.sidecar, false, '');
      if (!sidecar.ok) {
        return undefined;
      }
      shelf.sidecarPresent = true;
      shelf.sidecar = sidecar.report;
      shelf.importState = ProbeLimits.importImported;
      if (!legacyFailed) {
        shelf.importAt = stampOrEmpty(typeof parsed.importAt === 'string' ? parsed.importAt : '');
      }
    }
    return shelf;
  } catch (err) {
    return undefined;
  }
}

function readSidecar(raw: SidecarPeek, checkUdid: boolean, registeredUdid: string): SidecarAccept {
  let failed = new SidecarAccept();
  if (!raw || typeof raw !== 'object' || raw instanceof Array) {
    failed.reason = '侧车报告不是对象';
    return failed;
  }
  if (raw.schema !== ProbeLimits.schemaSidecar) {
    failed.reason = '不是侧车报告';
    return failed;
  }
  if (raw.schemaVersion !== ProbeLimits.schemaVersion) {
    failed.reason = '侧车报告版本不是 0.1';
    return failed;
  }
  if (typeof raw.imageTag !== 'string' || !isImageRole(raw.imageTag)) {
    failed.reason = '镜像标签只能是 base 或 secure';
    return failed;
  }
  if (typeof raw.boardClockAtRun !== 'string' || !isStamp(raw.boardClockAtRun)) {
    failed.reason = '侧车报告缺少板时钟';
    return failed;
  }
  let udid = '';
  if (typeof raw.boardUdid === 'string') {
    udid = raw.boardUdid.trim();
  } else if (raw.boardUdid !== undefined) {
    failed.reason = '侧车报告不是对象';
    return failed;
  }
  if (udid.length > ProbeLimits.udidMax || udid.indexOf('\n') >= 0 || udid.indexOf('\r') >= 0) {
    failed.reason = '侧车 UDID 与准备页登记不一致';
    return failed;
  }
  let registered = cleanUdid(registeredUdid);
  if (checkUdid && registered.length > 0 && udid !== registered) {
    failed.reason = '侧车 UDID 与准备页登记不一致';
    return failed;
  }
  if (!(raw.matrix instanceof Array)) {
    failed.reason = '侧车报告缺少态 2';
    return failed;
  }
  if (raw.matrix.length > ProbeLimits.stepMax) {
    failed.reason = '侧车步骤超过 8 条';
    return failed;
  }
  if (raw.matrix.length === 0) {
    failed.reason = '侧车报告缺少态 2';
    return failed;
  }
  let matrix: SidecarStep[] = [];
  let seenState2 = false;
  for (let i = 0; i < raw.matrix.length; i++) {
    let step = readStep(raw.matrix[i]);
    if (step === undefined) {
      failed.reason = '侧车步骤无法读取';
      return failed;
    }
    if (step.state === 2) {
      seenState2 = true;
    }
    matrix.push(step);
  }
  if (!seenState2) {
    failed.reason = '侧车报告缺少态 2';
    return failed;
  }
  let report = new SidecarReport();
  report.schema = ProbeLimits.schemaSidecar;
  report.schemaVersion = ProbeLimits.schemaVersion;
  report.imageTag = raw.imageTag;
  report.boardUdid = udid;
  report.boardClockAtRun = raw.boardClockAtRun;
  report.matrix = matrix;
  let accepted = new SidecarAccept();
  accepted.ok = true;
  accepted.report = report;
  return accepted;
}

function readStep(raw: StepPeek): SidecarStep | undefined {
  if (!raw || typeof raw !== 'object' || raw instanceof Array) {
    return undefined;
  }
  if (!isWhole(raw.state, 1, 9)) {
    return undefined;
  }
  if (typeof raw.desc !== 'string' || !isTightLine(raw.desc, ProbeLimits.descMax)) {
    return undefined;
  }
  let cmd = '';
  if (typeof raw.cmd === 'string') {
    if (raw.cmd.length > ProbeLimits.cmdMax || raw.cmd.indexOf('\n') >= 0 || raw.cmd.indexOf('\r') >= 0) {
      return undefined;
    }
    cmd = raw.cmd;
  } else if (raw.cmd !== undefined) {
    return undefined;
  }
  if (!isWhole(raw.retCode, -ProbeLimits.retCodeAbs, ProbeLimits.retCodeAbs)) {
    return undefined;
  }
  if (typeof raw.transcript !== 'string' || raw.transcript.length > ProbeLimits.transcriptMax) {
    return undefined;
  }
  if (typeof raw.at !== 'string' || !isStamp(raw.at)) {
    return undefined;
  }
  let step = new SidecarStep();
  step.state = raw.state;
  step.desc = raw.desc;
  step.cmd = cmd;
  step.retCode = raw.retCode;
  step.transcript = raw.transcript;
  step.at = raw.at;
  return step;
}

function readEvidence(raw: Evidence): ProbeEvidence | undefined {
  if (!raw || typeof raw !== 'object') {
    return undefined;
  }
  if (typeof raw.kind !== 'string' || !isEvidenceKind(raw.kind)) {
    return undefined;
  }
  if (typeof raw.text !== 'string' || !isTightLine(raw.text, ProbeLimits.evidenceTextMax)) {
    return undefined;
  }
  if (typeof raw.raw !== 'string' || raw.raw.length > ProbeLimits.rawMax || raw.raw.indexOf('\u0000') >= 0) {
    return undefined;
  }
  if (typeof raw.at !== 'string' || !isStamp(raw.at)) {
    return undefined;
  }
  let evidence = new ProbeEvidence();
  evidence.kind = raw.kind;
  evidence.text = raw.text;
  evidence.raw = raw.raw;
  evidence.at = raw.at;
  return evidence;
}

function readRuns(items: RunPeek[]): RunListRead {
  let read = new RunListRead();
  if (items === undefined) {
    read.ok = true;
    return read;
  }
  if (!(items instanceof Array)) {
    return read;
  }
  if (items.length > ProbeLimits.runMax) {
    return read;
  }
  for (let i = 0; i < items.length; i++) {
    let run = readStoredRun(items[i]);
    if (run === undefined) {
      return read;
    }
    read.runs.push(run);
  }
  read.ok = true;
  return read;
}

function readStoredRun(raw: RunPeek): ProbeRun | undefined {
  if (!raw || typeof raw !== 'object' || raw instanceof Array) {
    return undefined;
  }
  if (typeof raw.probeId !== 'string' || typeof raw.verdict !== 'string' || typeof raw.level !== 'string') {
    return undefined;
  }
  if (typeof raw.imageRole !== 'string' || typeof raw.phrase !== 'string' || typeof raw.createdAt !== 'string') {
    return undefined;
  }
  let probeId = asProbeId(raw.probeId);
  let verdict = asVerdict(raw.verdict);
  let level = asProofLevel(raw.level);
  let imageRole = asStoredImageRole(raw.imageRole);
  if (probeId === undefined || verdict === undefined || level === undefined || imageRole === undefined) {
    return undefined;
  }
  if ((verdict === 'hit' || verdict === 'blocked') && level === 'L3') {
    return undefined;
  }
  if (!isTightLine(raw.phrase, ProbeLimits.phraseMax) || !isStamp(raw.createdAt)) {
    return undefined;
  }
  if (!(raw.evidences instanceof Array) || raw.evidences.length > ProbeLimits.evidenceMax) {
    return undefined;
  }
  let run = new ProbeRun();
  run.probeId = probeId;
  run.verdict = verdict;
  run.phrase = raw.phrase;
  run.level = level;
  run.imageRole = imageRole;
  run.createdAt = raw.createdAt;
  let evidences: ProbeEvidence[] = [];
  for (let i = 0; i < raw.evidences.length; i++) {
    let evidence = readStoredEvidence(raw.evidences[i]);
    if (evidence === undefined) {
      return undefined;
    }
    evidences.push(evidence);
  }
  run.evidences = evidences;
  return run;
}

function readStoredEvidence(raw: EvidencePeek): ProbeEvidence | undefined {
  if (!raw || typeof raw !== 'object') {
    return undefined;
  }
  if (typeof raw.kind !== 'string' || typeof raw.text !== 'string' || typeof raw.raw !== 'string') {
    return undefined;
  }
  let kind = asEvidenceKind(raw.kind);
  if (kind === undefined || !isTightLine(raw.text, ProbeLimits.evidenceTextMax)) {
    return undefined;
  }
  if (raw.raw.length > ProbeLimits.rawMax || raw.raw.indexOf('\u0000') >= 0) {
    return undefined;
  }
  if (typeof raw.at !== 'string' || !isStamp(raw.at)) {
    return undefined;
  }
  let evidence = new ProbeEvidence();
  evidence.kind = kind;
  evidence.text = raw.text;
  evidence.raw = raw.raw;
  evidence.at = raw.at;
  return evidence;
}

function readFaults(items: FaultPeek[]): FaultListRead {
  let read = new FaultListRead();
  if (items === undefined) {
    read.ok = true;
    return read;
  }
  if (!(items instanceof Array) || items.length > 3) {
    return read;
  }
  for (let i = 0; i < items.length; i++) {
    let fault = readFault(items[i]);
    if (fault === undefined) {
      return read;
    }
    read.faults.push(fault);
  }
  read.ok = true;
  return read;
}

function readFault(raw: FaultPeek): ProbeRunFault | undefined {
  if (!raw || typeof raw !== 'object' || raw instanceof Array) {
    return undefined;
  }
  if (typeof raw.probeId !== 'string' || typeof raw.reason !== 'string' || typeof raw.at !== 'string') {
    return undefined;
  }
  let probeId = asProbeId(raw.probeId);
  if (probeId === undefined || !isTightLine(raw.reason, ProbeLimits.reasonMax) || !isStamp(raw.at)) {
    return undefined;
  }
  let fault = new ProbeRunFault();
  fault.probeId = probeId;
  fault.reason = raw.reason;
  fault.at = raw.at;
  return fault;
}

function writableRun(run: ProbeRun): boolean {
  if (!isProbeId(run.probeId) || !isVerdict(run.verdict) || !isProofLevel(run.level)) {
    return false;
  }
  if ((run.verdict === 'hit' || run.verdict === 'blocked') && run.level === 'L3') {
    return false;
  }
  if (!isTightLine(run.phrase, ProbeLimits.phraseMax) || asStoredImageRole(run.imageRole) === undefined || !isStamp(run.createdAt)) {
    return false;
  }
  if (run.evidences.length > ProbeLimits.evidenceMax) {
    return false;
  }
  for (let i = 0; i < run.evidences.length; i++) {
    let evidence = run.evidences[i];
    if (!isEvidenceKind(evidence.kind) || !isTightLine(evidence.text, ProbeLimits.evidenceTextMax)) {
      return false;
    }
    if (evidence.raw.length > ProbeLimits.rawMax || !isStamp(evidence.at)) {
      return false;
    }
  }
  return true;
}

function writableFault(fault: ProbeRunFault): boolean {
  return isProbeId(fault.probeId) && isTightLine(fault.reason, ProbeLimits.reasonMax) && isStamp(fault.at);
}

function writableSidecar(report: SidecarReport): boolean {
  if (report.schema !== ProbeLimits.schemaSidecar || report.schemaVersion !== ProbeLimits.schemaVersion) {
    return false;
  }
  if (!isImageRole(report.imageTag) || !isStamp(report.boardClockAtRun)) {
    return false;
  }
  if (report.matrix.length === 0 || report.matrix.length > ProbeLimits.stepMax) {
    return false;
  }
  let seenState2 = false;
  for (let i = 0; i < report.matrix.length; i++) {
    let step = report.matrix[i];
    if (!isWhole(step.state, 1, 9) || !isTightLine(step.desc, ProbeLimits.descMax) || !isStamp(step.at)) {
      return false;
    }
    if (step.state === 2) {
      seenState2 = true;
    }
  }
  return seenState2;
}

function faultsExcept(faults: ProbeRunFault[], probeId: ProbeId): ProbeRunFault[] {
  let next: ProbeRunFault[] = [];
  for (let i = 0; i < faults.length; i++) {
    if (faults[i].probeId !== probeId) {
      next.push(faults[i]);
    }
  }
  return next;
}

function formatSidecarDocument(report: SidecarReport): string {
  return '{\n' +
    '  "schema": ' + quote(report.schema) + ',\n' +
    '  "schemaVersion": ' + quote(report.schemaVersion) + ',\n' +
    '  "imageTag": ' + quote(report.imageTag) + ',\n' +
    '  "boardUdid": ' + quote(report.boardUdid) + ',\n' +
    '  "boardClockAtRun": ' + quote(report.boardClockAtRun) + ',\n' +
    '  "matrix": [\n' + formatMatrix(report, '  ') +
    '  ]\n}\n';
}

function formatSidecar(report: SidecarReport, pad: string): string {
  let inner = pad + '  ';
  return '{\n' +
    inner + '"schema": ' + quote(ProbeLimits.schemaSidecar) + ',\n' +
    inner + '"schemaVersion": ' + quote(ProbeLimits.schemaVersion) + ',\n' +
    inner + '"imageTag": ' + quote(report.imageTag) + ',\n' +
    inner + '"boardUdid": ' + quote(report.boardUdid) + ',\n' +
    inner + '"boardClockAtRun": ' + quote(report.boardClockAtRun) + ',\n' +
    inner + '"matrix": [\n' + formatMatrix(report, inner) +
    inner + ']\n' +
    pad + '}';
}

function formatMatrix(report: SidecarReport, pad: string): string {
  let lines = '';
  for (let i = 0; i < report.matrix.length; i++) {
    lines += formatStep(report.matrix[i], pad + '  ');
    if (i + 1 < report.matrix.length) {
      lines += ',\n';
    } else {
      lines += '\n';
    }
  }
  return lines;
}

function formatStep(step: SidecarStep, pad: string): string {
  let inner = pad + '  ';
  return pad + '{\n' +
    inner + '"state": ' + step.state.toString() + ',\n' +
    inner + '"desc": ' + quote(step.desc) + ',\n' +
    inner + '"cmd": ' + quote(step.cmd) + ',\n' +
    inner + '"retCode": ' + step.retCode.toString() + ',\n' +
    inner + '"transcript": ' + quote(step.transcript) + ',\n' +
    inner + '"at": ' + quote(step.at) + '\n' +
    pad + '}';
}

function formatRun(run: ProbeRun, pad: string): string {
  let inner = pad + '  ';
  let lines = pad + '{\n';
  lines += inner + '"probeId": ' + quote(run.probeId) + ',\n';
  lines += inner + '"verdict": ' + quote(run.verdict) + ',\n';
  lines += inner + '"phrase": ' + quote(run.phrase) + ',\n';
  lines += inner + '"level": ' + quote(run.level) + ',\n';
  lines += inner + '"imageRole": ' + quote(run.imageRole) + ',\n';
  lines += inner + '"createdAt": ' + quote(run.createdAt) + ',\n';
  lines += inner + '"evidences": [\n';
  for (let i = 0; i < run.evidences.length; i++) {
    lines += formatEvidence(run.evidences[i], inner + '  ');
    if (i + 1 < run.evidences.length) {
      lines += ',\n';
    } else {
      lines += '\n';
    }
  }
  lines += inner + ']\n';
  lines += pad + '}';
  return lines;
}

function formatEvidence(evidence: ProbeEvidence, pad: string): string {
  let inner = pad + '  ';
  return pad + '{\n' +
    inner + '"kind": ' + quote(evidence.kind) + ',\n' +
    inner + '"text": ' + quote(evidence.text) + ',\n' +
    inner + '"raw": ' + quote(evidence.raw) + ',\n' +
    inner + '"at": ' + quote(evidence.at) + '\n' +
    pad + '}';
}

function formatFault(fault: ProbeRunFault, pad: string): string {
  let inner = pad + '  ';
  return pad + '{\n' +
    inner + '"probeId": ' + quote(fault.probeId) + ',\n' +
    inner + '"reason": ' + quote(fault.reason) + ',\n' +
    inner + '"at": ' + quote(fault.at) + '\n' +
    pad + '}';
}

function phraseProblem(phrase: string): string {
  if (typeof phrase !== 'string') {
    return '短语无法落盘';
  }
  if (phrase.indexOf('\n') >= 0 || phrase.indexOf('\r') >= 0) {
    return '短语不能换行';
  }
  if (phrase.length > ProbeLimits.phraseMax) {
    return '短语超过 12 字';
  }
  return '短语无法落盘';
}

function isWhole(value: number, low: number, high: number): boolean {
  if (typeof value !== 'number' || value !== value) {
    return false;
  }
  if (value < low || value > high) {
    return false;
  }
  return Math.floor(value) === value;
}

function stripBom(value: string): string {
  if (value.charAt(0) === '\uFEFF') {
    return value.substring(1).trim();
  }
  return value;
}

function jsonEscape(value: string): string {
  let out = '';
  for (let i = 0; i < value.length; i++) {
    let code = value.charCodeAt(i);
    if (code === 34) {
      out += '\\"';
    } else if (code === 92) {
      out += '\\\\';
    } else if (code === 10) {
      out += '\\n';
    } else if (code === 13) {
      out += '\\r';
    } else if (code === 9) {
      out += '\\t';
    } else if (code < 32) {
      let hex = code.toString(16);
      if (hex.length < 2) {
        hex = '0' + hex;
      }
      out += '\\u00' + hex;
    } else {
      out += value.charAt(i);
    }
  }
  return out;
}

function quote(value: string): string {
  return '"' + jsonEscape(value) + '"';
}
