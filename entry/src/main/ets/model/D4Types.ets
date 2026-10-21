@Observed
export class D4Event {
  schema: string = 'jinyinhu.d4.event';
  schemaVersion: string = '0.1';
  eventId: string = '';
  seq: number = 0;
  deviceId: string = '';
  imageRole: string = '';
  imageVersion: string = '';
  imageHashTail: string = '';
  appId: string = '';
  appVersion: string = '';
  scenarioId: string = '';
  outcome: string = '';
  phrase: string = '';
  occurredAt: string = '';
  ruleId: string = '';
  baselineClause: string = '';
  threatId: string = '';
  threatStatus: string = '';
  registeredAt: string = '';
  evidenceNo: string = '';
  source: string = '';
  detail: string = '';
}

@Observed
export class BoardCard {
  role: string = '';
  title: string = '';
  deviceId: string = '';
  imageVersion: string = '7.0.0.40';
  hashTail: string = '';
  appVersion: string = '1.0.0';
}

@Observed
export class BoardPair {
  vanilla: BoardCard = new BoardCard();
  secure: BoardCard = new BoardCard();
}

export class Choice {
  value: string = '';
  label: string = '';

  constructor(value: string, label: string) {
    this.value = value;
    this.label = label;
  }
}

export class ParseResult {
  ok: boolean = false;
  message: string = '';
  events: D4Event[] = [];
  skipped: number = 0;
}

export class EventDraft {
  imageRole: string = 'base';
  deviceId: string = '';
  imageVersion: string = '7.0.0.40';
  imageHashTail: string = '';
  scenarioId: string = 'S3';
  outcome: string = 'unconfigured';
  phrase: string = '';
  ruleId: string = '';
  baselineClause: string = '';
  threatId: string = '';
  threatStatus: string = 'open';
  registeredAt: string = '';
  evidenceNo: string = '';
  detail: string = '';
  appId: string = '';
}

export class BuildInfo {
  static readonly schemaEvent: string = 'jinyinhu.d4.event';
  static readonly schemaBundle: string = 'jinyinhu.d4.bundle';
  static readonly schemaVersion: string = '0.1';
  static readonly appVersion: string = '1.0.0';
  static readonly imageLock: string = '7.0.0.40';
  static readonly bundleNote: string = '现场交换文件。已缓解只承认同时带登记时点和依据编号的条目。';
}

export function defaultBoards(): BoardPair {
  let pair = new BoardPair();
  pair.vanilla.role = 'vanilla-demo';
  pair.vanilla.title = '普通版';
  pair.vanilla.deviceId = 'board-vanilla';
  pair.vanilla.imageVersion = BuildInfo.imageLock;
  pair.vanilla.hashTail = '';
  pair.vanilla.appVersion = BuildInfo.appVersion;
  pair.secure.role = 'secure';
  pair.secure.title = '安全版';
  pair.secure.deviceId = 'board-secure';
  pair.secure.imageVersion = BuildInfo.imageLock;
  pair.secure.hashTail = '';
  pair.secure.appVersion = BuildInfo.appVersion;
  return pair;
}

export function pad2(value: number): string {
  if (value < 10) {
    return '0' + value.toString();
  }
  return value.toString();
}

export function nowIso(): string {
  let date = new Date();
  let offset = -date.getTimezoneOffset();
  let sign = '+';
  let abs = offset;
  if (offset < 0) {
    sign = '-';
    abs = -offset;
  }
  let hours = Math.floor(abs / 60);
  let minutes = abs % 60;
  return date.getFullYear().toString() + '-' + pad2(date.getMonth() + 1) + '-' + pad2(date.getDate()) +
    'T' + pad2(date.getHours()) + ':' + pad2(date.getMinutes()) + ':' + pad2(date.getSeconds()) +
    sign + pad2(hours) + ':' + pad2(minutes);
}

export function createEventId(seq: number): string {
  return 'evt-' + Date.now().toString() + '-' + seq.toString();
}

export function nextSeq(list: D4Event[]): number {
  let max = 0;
  for (let i = 0; i < list.length; i++) {
    if (list[i].seq > max) {
      max = list[i].seq;
    }
  }
  return max + 1;
}

export function isHexTail(value: string): boolean {
  if (value.length === 0) {
    return true;
  }
  if (value.length !== 4) {
    return false;
  }
  for (let i = 0; i < value.length; i++) {
    let code = value.charCodeAt(i);
    let digit = code >= 48 && code <= 57;
    let upper = code >= 65 && code <= 70;
    if (!digit && !upper) {
      return false;
    }
  }
  return true;
}

export function outcomeLabel(outcome: string): string {
  if (outcome === 'succeeded') {
    return '得手';
  }
  if (outcome === 'blocked') {
    return '已拒绝';
  }
  if (outcome === 'alive') {
    return '服务仍在';
  }
  if (outcome === 'down') {
    return '服务异常';
  }
  if (outcome === 'unconfigured') {
    return '未接入';
  }
  return '未知结果';
}

export function sourceLabel(source: string): string {
  if (source === 'onsite') {
    return '现场';
  }
  if (source === 'rehearsal') {
    return '版式样例';
  }
  if (source === 'imported') {
    return '外部导入';
  }
  if (source === 'show') {
    return '演示稿';
  }
  if (source === 'probe') {
    return '探针';
  }
  return '未知来源';
}

export function roleLabel(role: string): string {
  if (role === 'base') {
    return '基础版';
  }
  if (role === 'vanilla-demo') {
    return '普通版';
  }
  if (role === 'secure') {
    return '安全版';
  }
  return '未分侧';
}

export function statusLabel(status: string): string {
  if (status === 'mitigated') {
    return '已缓解';
  }
  if (status === 'residual') {
    return '残余';
  }
  if (status === 'open') {
    return '待处理';
  }
  return '未登记';
}

export function scenarioLabel(scenarioId: string): string {
  if (scenarioId === 'S3') {
    return 'S3 非授权数据访问';
  }
  if (scenarioId === 'S1') {
    return 'S1 信息泄露';
  }
  if (scenarioId === 'S2') {
    return 'S2 服务异常';
  }
  if (scenarioId === 'D3') {
    return 'D3 安装验签';
  }
  if (scenarioId === 'A1') {
    return 'A1 安装信任链';
  }
  if (scenarioId === 'B1') {
    return 'B1 沙箱隔离';
  }
  if (scenarioId === 'C1') {
    return 'C1 安全组件姿态';
  }
  return scenarioId;
}

export function outcomeTone(outcome: string): string {
  if (outcome === 'succeeded' || outcome === 'down') {
    return 'danger';
  }
  if (outcome === 'blocked' || outcome === 'alive') {
    return 'ok';
  }
  return 'gold';
}

export function copyEvents(list: D4Event[]): D4Event[] {
  let copy: D4Event[] = [];
  for (let i = 0; i < list.length; i++) {
    copy.push(list[i]);
  }
  return copy;
}

export function sortedEvents(list: D4Event[]): D4Event[] {
  let copy = copyEvents(list);
  copy.sort((left: D4Event, right: D4Event) => {
    if (left.occurredAt === right.occurredAt) {
      return right.seq - left.seq;
    }
    if (left.occurredAt < right.occurredAt) {
      return 1;
    }
    return -1;
  });
  return copy;
}

export function filterEvents(list: D4Event[], role: string, scenarioId: string): D4Event[] {
  let out: D4Event[] = [];
  for (let i = 0; i < list.length; i++) {
    let item = list[i];
    let roleOk = role === '' || item.imageRole === role;
    let scenarioOk = scenarioId === '' || item.scenarioId === scenarioId;
    if (roleOk && scenarioOk) {
      out.push(item);
    }
  }
  return sortedEvents(out);
}

export function countSource(list: D4Event[], source: string): number {
  let count = 0;
  for (let i = 0; i < list.length; i++) {
    if (list[i].source === source) {
      count++;
    }
  }
  return count;
}

export function hasRehearsal(list: D4Event[]): boolean {
  return countSource(list, 'rehearsal') > 0;
}

export function hasEventId(list: D4Event[], eventId: string): boolean {
  for (let i = 0; i < list.length; i++) {
    if (list[i].eventId === eventId) {
      return true;
    }
  }
  return false;
}

export function removeEvent(list: D4Event[], eventId: string): D4Event[] {
  let out: D4Event[] = [];
  for (let i = 0; i < list.length; i++) {
    if (list[i].eventId !== eventId) {
      out.push(list[i]);
    }
  }
  return out;
}

function inSet(value: string, allowed: string[]): boolean {
  for (let i = 0; i < allowed.length; i++) {
    if (allowed[i] === value) {
      return true;
    }
  }
  return false;
}

function checkText(value: string, name: string, low: number, high: number): string {
  if (value.length < low || value.length > high) {
    return name + '长度需在 ' + low.toString() + ' 到 ' + high.toString() + ' 之间';
  }
  return '';
}

export function validateEvent(event: D4Event): string {
  if (event.schema !== BuildInfo.schemaEvent || event.schemaVersion !== BuildInfo.schemaVersion) {
    return 'schema 不是 jinyinhu.d4.event 0.1';
  }
  let eventIdError = checkText(event.eventId, '事件编号', 1, 80);
  if (eventIdError !== '') {
    return eventIdError;
  }
  if (event.seq < 1 || event.seq > 1000000 || Math.floor(event.seq) !== event.seq) {
    return '序号必须是 1 到 1000000 的整数';
  }
  let deviceError = checkText(event.deviceId, '设备标识', 1, 64);
  if (deviceError !== '') {
    return deviceError;
  }
  if (!inSet(event.imageRole, ['vanilla-demo', 'secure', 'base'])) {
    return '镜像角色只能是基础版、普通版或安全版';
  }
  let versionError = checkText(event.imageVersion, '镜像版本', 1, 32);
  if (versionError !== '') {
    return versionError;
  }
  if (!isHexTail(event.imageHashTail)) {
    return '镜像哈希尾号要留空，或填 4 位大写十六进制';
  }
  let appError = checkText(event.appId, '记录方应用', 1, 80);
  if (appError !== '') {
    return appError;
  }
  let appVersionError = checkText(event.appVersion, '应用版本', 1, 32);
  if (appVersionError !== '') {
    return appVersionError;
  }
  if (!inSet(event.scenarioId, ['S1', 'S2', 'S3', 'D3', 'A1', 'B1', 'C1'])) {
    return '场景只能是 S1、S2、S3、D3、A1、B1 或 C1';
  }
  if (!inSet(event.outcome, ['succeeded', 'blocked', 'alive', 'down', 'unconfigured'])) {
    return '现场结果不在约定范围内';
  }
  if (event.phrase.indexOf('\n') >= 0 || event.phrase.indexOf('\r') >= 0) {
    return '短语不能换行';
  }
  if (event.phrase.length > 12) {
    return '短语不能超过 12 个字';
  }
  if (event.outcome !== 'unconfigured' && event.phrase.length === 0) {
    return '除未接入外，都要写 12 字以内的短语';
  }
  let timeError = checkText(event.occurredAt, '时间', 16, 40);
  if (timeError !== '') {
    return timeError;
  }
  let ruleError = checkText(event.ruleId, '规则编号', 0, 64);
  if (ruleError !== '') {
    return ruleError;
  }
  let clauseError = checkText(event.baselineClause, '条款号', 0, 64);
  if (clauseError !== '') {
    return clauseError;
  }
  let threatError = checkText(event.threatId, '威胁编号', 0, 64);
  if (threatError !== '') {
    return threatError;
  }
  if (!inSet(event.threatStatus, ['open', 'residual', 'mitigated'])) {
    return '台账状态只能是待处理、残余或已缓解';
  }
  if (!inSet(event.source, ['onsite', 'rehearsal', 'imported', 'show', 'probe'])) {
    return '来源只能是现场、版式样例、外部导入、演示稿或探针';
  }
  if (event.registeredAt.length > 40 || event.evidenceNo.length > 64) {
    return '登记时点或依据编号过长';
  }
  if (event.threatStatus === 'mitigated') {
    if (event.registeredAt.length < 10 || event.evidenceNo.length < 3) {
      return '已缓解必须同时填写登记时点和依据编号';
    }
  }
  if (event.detail.length > 280) {
    return '详情不能超过 280 字';
  }
  return '';
}

export function draftToEvent(draft: EventDraft, seq: number): D4Event {
  let event = new D4Event();
  event.schema = BuildInfo.schemaEvent;
  event.schemaVersion = BuildInfo.schemaVersion;
  event.eventId = createEventId(seq);
  event.seq = seq;
  event.deviceId = draft.deviceId;
  event.imageRole = draft.imageRole;
  event.imageVersion = draft.imageVersion;
  event.imageHashTail = draft.imageHashTail.toUpperCase();
  event.appId = draft.appId;
  event.appVersion = BuildInfo.appVersion;
  event.scenarioId = draft.scenarioId;
  event.outcome = draft.outcome;
  event.phrase = draft.phrase;
  event.occurredAt = nowIso();
  event.ruleId = draft.ruleId.trim();
  event.baselineClause = draft.baselineClause.trim();
  event.threatId = draft.threatId.trim();
  event.threatStatus = draft.threatStatus;
  event.registeredAt = draft.registeredAt.trim();
  event.evidenceNo = draft.evidenceNo.trim();
  event.source = 'onsite';
  event.detail = draft.detail.trim();
  return event;
}

export function readinessDone(list: D4Event[]): number {
  let done = 5;
  if (countSource(list, 'onsite') > 0) {
    done = 6;
  }
  return done;
}
