import { Catalog } from './Catalog';
import { BoardCard, BoardPair, BuildInfo, D4Event, isHexTail, nowIso } from './D4Types';

export function clockText(value: string): string {
  if (value.length >= 19) {
    return value.substring(0, 10) + '  ' + value.substring(11, 19);
  }
  return value;
}

export function resolveShow(list: D4Event[], role: string, scenarioId: string, pair: BoardPair, appId: string,
  current: D4Event): D4Event {
  let next = materializeShow(list, role, scenarioId, pair, appId);
  if (next.source === 'show' && current.source === 'show' && current.phrase.length > 0) {
    return current;
  }
  return next;
}

export function materializeShow(list: D4Event[], role: string, scenarioId: string, pair: BoardPair,
  appId: string): D4Event {
  let live = preferLive(list, role, scenarioId);
  if (live !== undefined) {
    return live;
  }
  let cue = Catalog.cue(role, scenarioId);
  let board = pair.secure;
  if (role === 'vanilla-demo') {
    board = pair.vanilla;
  }
  return deckEvent(role, scenarioId, cue.outcome, cue.phrase, cue.threatId, board, appId);
}

function preferLive(list: D4Event[], role: string, scenarioId: string): D4Event | undefined {
  let onsite = newest(list, role, scenarioId, 'onsite');
  if (onsite !== undefined) {
    return onsite;
  }
  return newest(list, role, scenarioId, 'imported');
}

function newest(list: D4Event[], role: string, scenarioId: string, source: string): D4Event | undefined {
  let best: D4Event | undefined = undefined;
  for (let i = 0; i < list.length; i++) {
    let item = list[i];
    if (item.imageRole !== role || item.scenarioId !== scenarioId || item.source !== source) {
      continue;
    }
    if (best === undefined || item.occurredAt > best.occurredAt) {
      best = item;
    }
  }
  return best;
}

function deckEvent(role: string, scenarioId: string, outcome: string, phrase: string, threatId: string,
  board: BoardCard, appId: string): D4Event {
  let event = new D4Event();
  event.schema = BuildInfo.schemaEvent;
  event.schemaVersion = BuildInfo.schemaVersion;
  event.eventId = 'show-' + role + '-' + scenarioId;
  event.seq = deckSeq(role, scenarioId);
  event.deviceId = board.deviceId;
  if (event.deviceId.length === 0) {
    event.deviceId = role === 'vanilla-demo' ? 'board-vanilla' : 'board-secure';
  }
  event.imageRole = role;
  event.imageVersion = board.imageVersion.length === 0 ? BuildInfo.imageLock : board.imageVersion;
  let tail = board.hashTail.toUpperCase();
  event.imageHashTail = isHexTail(tail) ? tail : '';
  event.appId = appId;
  event.appVersion = BuildInfo.appVersion;
  event.scenarioId = scenarioId;
  event.outcome = outcome;
  event.phrase = phrase;
  event.occurredAt = nowIso();
  event.threatId = threatId;
  event.threatStatus = 'open';
  event.source = 'show';
  event.detail = '演示稿画面，不含数据。';
  return event;
}

function deckSeq(role: string, scenarioId: string): number {
  if (scenarioId === 'S2') {
    return role === 'vanilla-demo' ? 3 : 4;
  }
  return role === 'vanilla-demo' ? 1 : 2;
}
