import { AttemptFacts, FsOutcome, denialCode, judgeSandbox } from '../main/ets/probe/SandboxIsolationProbe';
import { ProbeLimits, isTightLine } from '../main/ets/probe/ProbeTypes';

function fail(message: string): void {
  throw new Error(message);
}

function denial(statCode: number, openCode: number): FsOutcome {
  let call = new FsOutcome();
  call.statCode = statCode;
  call.openCode = openCode;
  return call;
}

function attempt(category: string, call: FsOutcome): AttemptFacts {
  let item = new AttemptFacts();
  item.category = category;
  item.calls = [];
  item.calls.push(call);
  return item;
}

function five(codes: number[]): AttemptFacts[] {
  let names: string[] = ['明文相对路径', '编码路径', '外部存储', '跨包URI', '姿态URI'];
  let rows: AttemptFacts[] = [];
  for (let i = 0; i < names.length; i++) {
    rows.push(attempt(names[i], denial(codes[i], codes[i])));
  }
  return rows;
}

export function runSandboxProbeChecks(): void {
  if (!denialCode(13900002) || !denialCode(13900012) || !denialCode(13900020) || !denialCode(401)) {
    fail('四类拒绝码未进白名单');
  }
  if (denialCode(-1) || denialCode(13900042)) {
    fail('未知码不能参与判绿');
  }
  if (!denialCode(13900001)) {
    fail('操作不被允许应算拒绝');
  }
  let blocked = judgeSandbox(five([13900002, 13900012, 13900020, 401, 13900002]));
  if (!blocked.decided || blocked.verdict !== 'blocked' || blocked.phrase !== '暂未发现异常') {
    fail('四类拒绝码应得到 blocked');
  }
  if (!isTightLine(blocked.phrase, ProbeLimits.phraseMax)) {
    fail('拒绝短语不能落盘');
  }
  let handle = denial(13900012, 13900012);
  handle.gotHandle = true;
  let opened = five([13900002, 13900012, 13900020, 401, 13900002]);
  opened[1] = attempt('编码路径', handle);
  let hit = judgeSandbox(opened);
  if (!hit.decided || hit.verdict !== 'hit' || hit.phrase !== '发现异常') {
    fail('拿到句柄应得到 hit');
  }
  if (hit.raws[1].indexOf('拿到句柄') < 0) {
    fail('命中 raw 应标明拿到句柄');
  }
  if (hit.raws[1].indexOf('lakeside') >= 0 || hit.raws[1].indexOf('{') >= 0 || hit.raws[1].indexOf('file://') >= 0) {
    fail('命中 raw 不应带文件内容或路径');
  }
  let unknown = five([13900002, 13900042, 13900020, 401, 13900002]);
  let rejected = judgeSandbox(unknown);
  if (rejected.decided || rejected.phrase === '暂未发现异常') {
    fail('未知码不应产生 blocked');
  }
  let missing = five([13900002, -1, 13900020, 401, 13900002]);
  let unread = judgeSandbox(missing);
  if (unread.decided || unread.phrase === '暂未发现异常') {
    fail('解析不出的异常不应判绿');
  }
  let landing = denial(13900012, 13900012);
  let crossed = denial(13900002, 13900002);
  crossed.gotStat = true;
  let both = new AttemptFacts();
  both.category = '明文相对路径';
  both.calls = [];
  both.calls.push(landing);
  both.calls.push(crossed);
  let mixed = five([13900002, 13900012, 13900020, 401, 13900002]);
  mixed[0] = both;
  let openedLanding = judgeSandbox(mixed);
  if (!openedLanding.decided || openedLanding.verdict !== 'hit') {
    fail('落点或穿越任一拿到 stat 时本条应命中');
  }
}
