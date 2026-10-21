import { Choice } from './D4Types';

export class ThreatRow {
  threatId: string = '';
  title: string = '';
  scenarioId: string = '';
  status: string = '';
  registeredAt: string = '';
  evidenceNo: string = '';
  basis: string = '';
  summary: string = '';
}

export class BaselineItem {
  slot: string = '';
  title: string = '';
  scenarioId: string = '';
  state: string = '';
  note: string = '';
}

export class SbomRow {
  name: string = '';
  version: string = '';
  license: string = '';
  scope: string = '';
  note: string = '';
}

export class ScriptStep {
  id: string = '';
  title: string = '';
  seconds: number = 0;
  caption: string = '';
  optional: boolean = false;
  scenarioId: string = '';
  needsEvents: boolean = false;
}

export class SampleRow {
  sampleId: string = '';
  title: string = '';
  expect: string = '';
  storage: string = '';
}

export class GlossaryRow {
  term: string = '';
  meaning: string = '';
}

export class ReadinessRow {
  title: string = '';
  done: boolean = false;
  note: string = '';
}

export class ShowCue {
  role: string = '';
  scenarioId: string = '';
  outcome: string = '';
  phrase: string = '';
  threatId: string = '';
}

function threat(threatId: string, title: string, scenarioId: string, status: string,
  registeredAt: string, evidenceNo: string, basis: string, summary: string): ThreatRow {
  let row = new ThreatRow();
  row.threatId = threatId;
  row.title = title;
  row.scenarioId = scenarioId;
  row.status = status;
  row.registeredAt = registeredAt;
  row.evidenceNo = evidenceNo;
  row.basis = basis;
  row.summary = summary;
  return row;
}

function choice(value: string, label: string): Choice {
  return new Choice(value, label);
}

export class Catalog {
  static readonly boundary: string = '今天能演示的，只是台账里已经接入的具体风险，不是装上应用就没有别的问题。威胁台账里还有待处理项，并且固定保留一条残余。安全是分层和持续的过程。';

  static threats(): ThreatRow[] {
    let rows: ThreatRow[] = [];
    rows.push(threat(
      'TM-S3',
      '非授权数据访问',
      'S3',
      'open',
      '',
      '',
      'APP_DEMO_PLAN.md 场景池首选。漏洞尚未配置，不能标成已缓解。',
      '计划中的行为是读取未保护接口或敏感公共事件并展示。本应用不执行这件事。'
    ));
    rows.push(threat(
      'TM-RES-01',
      '本阶段未覆盖的未知内核路径',
      '',
      'residual',
      '2026-10-13',
      'PLAN-V0.4-S0.3',
      'APP_DEMO_PLAN.md 第 0 节原则 3 与第 7 节。登记时点是计划修订日，不是现场拦截时间。',
      '这项登记为残余，下一阶段再收口。页面必须能把它单独打开。'
    ));
    return rows;
  }

  static findThreat(threatId: string): ThreatRow | undefined {
    let rows = Catalog.threats();
    for (let i = 0; i < rows.length; i++) {
      if (rows[i].threatId === threatId) {
        return rows[i];
      }
    }
    return undefined;
  }

  static residual(): ThreatRow {
    let rows = Catalog.threats();
    return rows[rows.length - 1];
  }

  static baseline(): BaselineItem[] {
    let items: BaselineItem[] = [];
    items.push(Catalog.baselineItem('CHK-S3', '应用层拒绝可归因到一条加固项', 'S3', '待 W4 编号', '依赖条目裁剪前必须换场景或走变更。条款号尚未冻结。'));
    items.push(Catalog.baselineItem('CHK-S1', '敏感信息源读取被拒绝并可留痕', 'S1', '待存在性验证', '若官方镜像上已经读不到，这条不能当得手场景。'));
    items.push(Catalog.baselineItem('CHK-S2', '未保护组件调用被拒绝且服务仍在', 'S2', '备选', '普通版若进入不稳态，这条排到最后。'));
    items.push(Catalog.baselineItem('CHK-D3', '非平台授权包被拒绝', 'D3', '样本未预置二进制', '只保存六类样本的说明，不安装。'));
    items.push(Catalog.baselineItem('CHK-AUD', '对照镜像仍保留审计与事件采集', '对照', '计划要求', '关掉加固时不能关掉取证，否则普通版没有记录。'));
    return items;
  }

  private static baselineItem(slot: string, title: string, scenarioId: string, state: string, note: string): BaselineItem {
    let item = new BaselineItem();
    item.slot = slot;
    item.title = title;
    item.scenarioId = scenarioId;
    item.state = state;
    item.note = note;
    return item;
  }

  static sbom(selfName: string): SbomRow[] {
    let rows: SbomRow[] = [];
    rows.push(Catalog.sbomRow(selfName, '1.0.0', '随阶段工程交付', 'delivery', '当前安装包。无第三方 ohpm 运行时依赖。'));
    rows.push(Catalog.sbomRow('D4 交换契约 0.1', '0.1', '工程内契约', 'contract', '安全中心与对照台共用。正式 D4 schema 未入库，验收时再对齐。'));
    rows.push(Catalog.sbomRow('缺陷演示应用', '未提供', '未纳入', 'pending', '预留后续接入。本包不包含它，也不包含攻击代码。'));
    return rows;
  }

  private static sbomRow(name: string, version: string, license: string, scope: string, note: string): SbomRow {
    let row = new SbomRow();
    row.name = name;
    row.version = version;
    row.license = license;
    row.scope = scope;
    row.note = note;
    return row;
  }

  static script(): ScriptStep[] {
    let steps: ScriptStep[] = [];
    steps.push(Catalog.step('stage', '双板亮相', 20, '两块板，同一个系统，同一个应用。差别只在一块打开了全部安全加固。', false, '', false));
    steps.push(Catalog.step('vanilla', '普通版现场', 45, '这一下，不该看的已经上了屏幕。', false, 'S3', true));
    steps.push(Catalog.step('secure', '安全版现场', 45, '同一下。系统拒绝，而且这一下已经入账。', false, 'S3', true));
    steps.push(Catalog.step('evidence', '对照证据', 75, '一边是已经出现的内容，一边是拒绝和时间。底下这条残余，下一阶段再收口。', false, '', true));
    steps.push(Catalog.step('s2', '服务异常', 45, '一边服务停了。另一边拦住了，服务还在。', true, 'S2', true));
    steps.push(Catalog.step('samples', '六类样本', 30, '六类样本依次过场。安全版应当拒绝安装。', false, 'D3', false));
    steps.push(Catalog.step('close', '边界', 45, '记录留在本机。今天只覆盖已经接入的具体风险。安全是分层和持续的过程。', false, '', false));
    return steps;
  }

  private static step(id: string, title: string, seconds: number, caption: string, optional: boolean,
    scenarioId: string, needsEvents: boolean): ScriptStep {
    let step = new ScriptStep();
    step.id = id;
    step.title = title;
    step.seconds = seconds;
    step.caption = caption;
    step.optional = optional;
    step.scenarioId = scenarioId;
    step.needsEvents = needsEvents;
    return step;
  }

  static samples(): SampleRow[] {
    let rows: SampleRow[] = [];
    rows.push(Catalog.sample('SAM-01', '未签名', '安全版应拒绝安装', '只有说明，没有安装包'));
    rows.push(Catalog.sample('SAM-02', '内容与签名不一致', '安全版应拒绝安装', '只有说明，没有安装包'));
    rows.push(Catalog.sample('SAM-03', '证书已过期', '安全版应拒绝安装', '只有说明，没有安装包'));
    rows.push(Catalog.sample('SAM-04', '证书链不完整', '安全版应拒绝安装', '只有说明，没有安装包'));
    rows.push(Catalog.sample('SAM-05', '非发布描述文件', '安全版应拒绝安装', '只有说明，没有安装包'));
    rows.push(Catalog.sample('SAM-06', '链有效但不是平台授权', '安全版应拒绝安装', '兜底主线。只有说明，没有安装包'));
    return rows;
  }

  private static sample(sampleId: string, title: string, expect: string, storage: string): SampleRow {
    let row = new SampleRow();
    row.sampleId = sampleId;
    row.title = title;
    row.expect = expect;
    row.storage = storage;
    return row;
  }

  static glossary(): GlossaryRow[] {
    let rows: GlossaryRow[] = [];
    rows.push(Catalog.gloss('普通版', '演示用对照镜像，不是交付物。壁纸和标签都要能看出这一点。'));
    rows.push(Catalog.gloss('安全版', '加固打开的交付镜像。演示镜像、验收镜像和复现镜像是同一套。'));
    rows.push(Catalog.gloss('残余', '已经登记、本阶段不声称处理好的事项。必须能在页面上单独打开。'));
    rows.push(Catalog.gloss('登记时点', '台账写入的时间。已缓解来自预登记，不是现场拦截当场生成的。'));
    rows.push(Catalog.gloss('只存不装', '验签样本只留说明或文件，不在演示应用里安装。'));
    rows.push(Catalog.gloss('AVC', '系统安全模块的拒绝记录，相当于门禁刷卡失败记录。'));
    return rows;
  }

  private static gloss(term: string, meaning: string): GlossaryRow {
    let row = new GlossaryRow();
    row.term = term;
    row.meaning = meaning;
    return row;
  }

  static readiness(onsiteCount: number): ReadinessRow[] {
    let rows: ReadinessRow[] = [];
    rows.push(Catalog.ready('现场记录可以清空', true, '避免彩排时间戳留在正式演示里。'));
    rows.push(Catalog.ready('可以导入和导出 D4 文件', true, '普通版记录导出后，由安全中心统一打开。'));
    rows.push(Catalog.ready('残余条目固定展示', true, 'TM-RES-01 不依赖现场有没有事件。'));
    rows.push(Catalog.ready('边界声明固定展示', true, '收尾时念这一段，不另编口径。'));
    rows.push(Catalog.ready('现场记录和台账分开', true, '拦截结果不会自动改写成已缓解。'));
    rows.push(Catalog.ready('已有现场观察记录', onsiteCount > 0, '漏洞场景接入并记下一笔之后，这一项才算完成。'));
    return rows;
  }

  private static ready(title: string, done: boolean, note: string): ReadinessRow {
    let row = new ReadinessRow();
    row.title = title;
    row.done = done;
    row.note = note;
    return row;
  }

  static scenarioChoices(): Choice[] {
    let rows: Choice[] = [];
    rows.push(choice('S3', 'S3 数据访问'));
    rows.push(choice('S1', 'S1 信息泄露'));
    rows.push(choice('S2', 'S2 服务异常'));
    rows.push(choice('D3', 'D3 安装验签'));
    return rows;
  }

  static scenarioFilters(): Choice[] {
    let rows: Choice[] = [];
    rows.push(choice('', '全部场景'));
    let scenarios = Catalog.scenarioChoices();
    for (let i = 0; i < scenarios.length; i++) {
      rows.push(scenarios[i]);
    }
    return rows;
  }

  static roleChoices(): Choice[] {
    let rows: Choice[] = [];
    rows.push(choice('vanilla-demo', '普通版'));
    rows.push(choice('secure', '安全版'));
    return rows;
  }

  static outcomeChoices(): Choice[] {
    let rows: Choice[] = [];
    rows.push(choice('unconfigured', '未接入'));
    rows.push(choice('succeeded', '得手'));
    rows.push(choice('blocked', '已拒绝'));
    rows.push(choice('alive', '服务仍在'));
    rows.push(choice('down', '服务异常'));
    return rows;
  }

  static statusChoices(): Choice[] {
    let rows: Choice[] = [];
    rows.push(choice('open', '待处理'));
    rows.push(choice('residual', '残余'));
    rows.push(choice('mitigated', '已缓解'));
    return rows;
  }

  static cues(): ShowCue[] {
    let rows: ShowCue[] = [];
    rows.push(Catalog.oneCue('vanilla-demo', 'S3', 'succeeded', '不该看的已上屏', 'TM-S3'));
    rows.push(Catalog.oneCue('secure', 'S3', 'blocked', '系统拒绝并已入账', 'TM-S3'));
    return rows;
  }

  static cue(role: string, scenarioId: string): ShowCue {
    let rows = Catalog.cues();
    for (let i = 0; i < rows.length; i++) {
      if (rows[i].role === role && rows[i].scenarioId === scenarioId) {
        return rows[i];
      }
    }
    return Catalog.oneCue(role, scenarioId, 'blocked', '系统留下了记录', '');
  }

  private static oneCue(role: string, scenarioId: string, outcome: string, phrase: string,
    threatId: string): ShowCue {
    let cue = new ShowCue();
    cue.role = role;
    cue.scenarioId = scenarioId;
    cue.outcome = outcome;
    cue.phrase = phrase;
    cue.threatId = threatId;
    return cue;
  }

  static threatChoices(): Choice[] {
    let rows: Choice[] = [];
    rows.push(choice('', '不关联'));
    let threats = Catalog.threats();
    for (let i = 0; i < threats.length; i++) {
      rows.push(choice(threats[i].threatId, threats[i].threatId));
    }
    return rows;
  }
}
