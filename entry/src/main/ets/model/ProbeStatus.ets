import { acceptProbeRun } from '../probe/ProbeCodec';
import { ProbeRun, ProbeRunFault, ProbeShelf, isStamp } from '../probe/ProbeTypes';

export type ProbeTone = 'none' | 'risk' | 'safe' | 'note' | 'fault';

export const PROBE_IDS: string[] = ['P1', 'P2', 'P3'];

export function probeName(id: string): string {
  if (id === 'P1') {
    return '安装包检测';
  }
  if (id === 'P2') {
    return '应用隔离检测';
  }
  if (id === 'P3') {
    return '安全控件检测';
  }
  return id;
}

export function probeScope(id: string): string {
  if (id === 'P1') {
    return '检测是否有恶意安装包，是否有绕过安装等风险';
  }
  if (id === 'P2') {
    return '检测应用之间是否隔离，是否有读取私有文件的风险';
  }
  if (id === 'P3') {
    return '检测安全控件是否可信，是否有绕过授权的风险';
  }
  return '';
}

export function newestRun(shelf: ProbeShelf, id: string): ProbeRun | undefined {
  let runs = shelf.runs;
  for (let i = runs.length - 1; i >= 0; i--) {
    if (runs[i].probeId !== id) {
      continue;
    }
    if (acceptProbeRun(id, runs[i]).ok) {
      return runs[i];
    }
  }
  return undefined;
}

export function newestFault(shelf: ProbeShelf, id: string): ProbeRunFault | undefined {
  let faults = shelf.runFaults;
  for (let i = 0; i < faults.length; i++) {
    if (faults[i].probeId === id && isStamp(faults[i].at) && faults[i].reason.length > 0) {
      return faults[i];
    }
  }
  return undefined;
}

export function visibleRun(shelf: ProbeShelf, id: string): ProbeRun | undefined {
  let run = newestRun(shelf, id);
  if (run === undefined) {
    return undefined;
  }
  let fault = newestFault(shelf, id);
  if (fault !== undefined && fault.at >= run.createdAt) {
    return undefined;
  }
  return run;
}

export function visibleFault(shelf: ProbeShelf, id: string): ProbeRunFault | undefined {
  let fault = newestFault(shelf, id);
  if (fault === undefined) {
    return undefined;
  }
  let run = newestRun(shelf, id);
  if (run !== undefined && run.createdAt > fault.at) {
    return undefined;
  }
  return fault;
}

export function probeTone(shelf: ProbeShelf, id: string): ProbeTone {
  let run = visibleRun(shelf, id);
  if (run !== undefined) {
    if (run.verdict === 'hit') {
      return 'risk';
    }
    if (run.verdict === 'blocked') {
      return 'safe';
    }
    return 'note';
  }
  if (visibleFault(shelf, id) !== undefined) {
    return 'fault';
  }
  return 'none';
}

export function toneLabel(tone: ProbeTone): string {
  if (tone === 'risk') {
    return '发现风险';
  }
  if (tone === 'safe') {
    return '未发现风险';
  }
  if (tone === 'note') {
    return '需要留意';
  }
  if (tone === 'fault') {
    return '未完成';
  }
  return '未检测';
}

export class HomeSummary {
  tone: ProbeTone = 'none';
  risks: number = 0;
  notes: number = 0;
  lastAt: string = '';
}

export function homeSummary(shelf: ProbeShelf): HomeSummary {
  let summary = new HomeSummary();
  let checked = 0;
  for (let i = 0; i < PROBE_IDS.length; i++) {
    let id = PROBE_IDS[i];
    let tone = probeTone(shelf, id);
    if (tone === 'none') {
      continue;
    }
    checked++;
    if (tone === 'risk') {
      summary.risks++;
    } else if (tone === 'note' || tone === 'fault') {
      summary.notes++;
    }
    let at = stampOf(shelf, id);
    if (at > summary.lastAt) {
      summary.lastAt = at;
    }
  }
  if (checked === 0) {
    summary.tone = 'none';
  } else if (summary.risks > 0) {
    summary.tone = 'risk';
  } else if (summary.notes > 0) {
    summary.tone = 'note';
  } else {
    summary.tone = 'safe';
  }
  return summary;
}

export function shortStamp(at: string): string {
  if (!isStamp(at)) {
    return '';
  }
  return at.substring(5, 10) + ' ' + at.substring(11, 16);
}

function stampOf(shelf: ProbeShelf, id: string): string {
  let run = visibleRun(shelf, id);
  if (run !== undefined) {
    return run.createdAt;
  }
  let fault = visibleFault(shelf, id);
  if (fault !== undefined) {
    return fault.at;
  }
  return '';
}
