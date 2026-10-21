import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../../..');
const files = [
  ['entry/src/main/ets/model/D4Types.ets', 'D4Types.ts'],
  ['entry/src/main/ets/model/D4Codec.ets', 'D4Codec.ts'],
  ['entry/src/main/ets/probe/ProbeTypes.ets', 'ProbeTypes.ts'],
  ['entry/src/main/ets/probe/ProbeCodec.ets', 'ProbeCodec.ts'],
  ['entry/src/main/ets/probe/SandboxIsolationProbe.ets', 'SandboxIsolationProbe.ts'],
  ['entry/src/main/ets/probe/SecCompPostureProbe.ets', 'SecCompPostureProbe.ts'],
  ['entry/src/main/ets/probe/InstallIntegrityProbe.ets', 'InstallIntegrityProbe.ts'],
  ['entry/src/main/ets/probe/UpdateReject.ets', 'UpdateReject.ts'],
  ['entry/src/main/ets/deck/DeckScript.ets', 'DeckScript.ts'],
  ['entry/src/main/ets/model/Catalog.ets', 'Catalog.ts'],
  ['entry/src/main/ets/report/Findings.ets', 'Findings.ts'],
  ['entry/src/main/ets/report/Ledger.ets', 'Ledger.ts'],
  ['entry/src/test/ProbeCodec.test.ets', 'ProbeCodec.test.ts'],
  ['entry/src/test/SandboxProbe.test.ets', 'SandboxProbe.test.ts'],
  ['entry/src/test/Findings.test.ets', 'Findings.test.ts'],
  ['entry/src/test/Ledger.test.ets', 'Ledger.test.ts'],
  ['entry/src/test/SecCompProbe.test.ets', 'SecCompProbe.test.ts'],
  ['entry/src/test/InstallProbe.test.ets', 'InstallProbe.test.ts'],
  ['entry/src/test/Deck.test.ets', 'Deck.test.ts'],
  ['entry/src/test/D4Contract.test.ets', 'D4Contract.test.ts']
];

function prep(source) {
  return source
    .replace(/@Observed\r?\n/g, '')
    .replace("import { common } from '@kit.AbilityKit';\n", '')
    .replace(/common\.UIAbilityContext/g, 'Object')
    .replaceAll("from '../main/ets/model/D4Types'", "from './D4Types.ts'")
    .replaceAll("from '../main/ets/model/D4Codec'", "from './D4Codec.ts'")
    .replaceAll("from '../main/ets/probe/ProbeCodec'", "from './ProbeCodec.ts'")
    .replaceAll("from '../main/ets/probe/ProbeTypes'", "from './ProbeTypes.ts'")
    .replaceAll("from '../main/ets/probe/SandboxIsolationProbe'", "from './SandboxIsolationProbe.ts'")
    .replaceAll("from '../main/ets/probe/SecCompPostureProbe'", "from './SecCompPostureProbe.ts'")
    .replaceAll("from '../main/ets/probe/InstallIntegrityProbe'", "from './InstallIntegrityProbe.ts'")
    .replaceAll("from '../main/ets/probe/UpdateReject'", "from './UpdateReject.ts'")
    .replaceAll("from './UpdateReject'", "from './UpdateReject.ts'")
    .replaceAll("from '../probe/InstallIntegrityProbe'", "from './InstallIntegrityProbe.ts'")
    .replaceAll("from '../main/ets/deck/DeckScript'", "from './DeckScript.ts'")
    .replaceAll("from '../report/Findings'", "from './Findings.ts'")
    .replaceAll("from '../probe/ProbeCodec'", "from './ProbeCodec.ts'")
    .replaceAll("from '../probe/ProbeTypes'", "from './ProbeTypes.ts'")
    .replaceAll("from '../main/ets/report/Findings'", "from './Findings.ts'")
    .replaceAll("from '../main/ets/report/Ledger'", "from './Ledger.ts'")
    .replaceAll("from '../main/ets/model/Catalog'", "from './Catalog.ts'")
    .replaceAll("from './Findings'", "from './Findings.ts'")
    .replace(/import \{ FileExchange \} from '\.\.\/model\/FileExchange';\n/,
      "const FileExchange = { async saveText() { return { ok: false, message: '', text: '' }; } };\n")
    .replace(/import \{ preferences \} from '@kit\.ArkData';\n/, '')
    .replaceAll("from './ProbeTypes'", "from './ProbeTypes.ts'")
    .replaceAll("from './ProbeCodec';", "from './ProbeCodec.ts';")
    .replaceAll("from '../model/D4Types'", "from './D4Types.ts'")
    .replaceAll("from './D4Types';", "from './D4Types.ts';")
    .replace(/import \{ LiveStore \} from '\.\.\/model\/LiveStore';\n/,
      "const LiveStore = { shelf() { return { sidecarPresent: false, sidecar: { imageTag: '' } }; } };\n")
    .replace(/import fs from '@ohos\.file\.fs';\n/,
      "const fs = { OpenMode: { READ_ONLY: 0 }, statSync() { throw { code: 13900012 }; }, openSync() { throw { code: 13900002 }; }, closeSync() {} };\n")
    .replace(/import fileUri from '@ohos\.file\.fileuri';\n/,
      "const fileUri = { FileUri: class { constructor() {} get path() { return ''; } } };\n")
    .replace(/import bundleManager from '@ohos\.bundle\.bundleManager';\n/,
      "const bundleManager = { BundleFlag: { GET_BUNDLE_INFO_DEFAULT: 0 }, getBundleInfoSync() { throw new Error('读回失败'); } };\n")
    .replace(/import \{ hilog \} from '@kit\.PerformanceAnalysisKit';\n/,
      "const hilog = { error() {}, info() {} };\n")
    .replace(/\bAppStorage\b/g, 'globalThis.AppStorage');
}

const dir = mkdtempSync(join(tmpdir(), 'probe-codec-'));
try {
  for (const [from, to] of files) {
    writeFileSync(join(dir, to), prep(readFileSync(resolve(root, from), 'utf8')));
  }
  writeFileSync(join(dir, 'main.ts'),
    "import { runProbeCodecChecks } from './ProbeCodec.test.ts';\nimport { runSandboxProbeChecks } from './SandboxProbe.test.ts';\nimport { runFindingsChecks } from './Findings.test.ts';\nimport { runLedgerChecks } from './Ledger.test.ts';\nimport { runPostureChecks } from './SecCompProbe.test.ts';\nimport { runInstallChecks } from './InstallProbe.test.ts';\nimport { runDeckChecks } from './Deck.test.ts';\nimport { runD4ContractChecks } from './D4Contract.test.ts';\nconst slots = new Map();\nglobalThis.AppStorage = { has(key) { return slots.has(key); }, get(key) { return slots.get(key); }, setOrCreate(key, value) { slots.set(key, value); } };\nrunProbeCodecChecks();\nrunSandboxProbeChecks();\nrunFindingsChecks();\nrunLedgerChecks();\nrunPostureChecks();\nrunInstallChecks();\nrunDeckChecks();\nrunD4ContractChecks();\n");
  const run = spawnSync(process.execPath, ['--experimental-strip-types', join(dir, 'main.ts')], {
    encoding: 'utf8'
  });
  if (run.status !== 0) {
    process.stderr.write(run.stdout || '');
    process.stderr.write(run.stderr || '');
    process.exit(run.status === null ? 1 : run.status);
  }
} finally {
  rmSync(dir, { recursive: true, force: true });
}
