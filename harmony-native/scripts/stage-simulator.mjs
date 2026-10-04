import { cpSync, existsSync, mkdirSync, readFileSync, writeFileSync, unlinkSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const source = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const stage = resolve(process.argv[2] ?? 'D:/Dev/SaydianHarmonySimulator/current');
if (!stage.startsWith(resolve('D:/Dev/SaydianHarmonySimulator') + '/') && !stage.startsWith(resolve('D:/Dev/SaydianHarmonySimulator') + '\\')) throw new Error('Stage must stay under D:/Dev/SaydianHarmonySimulator');
if (existsSync(stage)) throw new Error('Choose a fresh simulator staging directory');
mkdirSync(stage, { recursive: true });
cpSync(source, stage, { recursive: true, filter: path => !['oh_modules', 'build', '.hvigor', '.idea', 'local.properties'].some(part => path.split(/[\\/]/).includes(part)) &&
  !/\.(p12|p7b|cer|pem|key|log)$/.test(path) });
const write = (path, text) => writeFileSync(resolve(stage, path), text);
write('entry/src/main/ets/services/VepWearableService.ets', readFileSync(resolve(source, 'simulator/NoHardwareWearableService.ets'), 'utf8'));
for (const [name, exported] of [['VepDeviceSettingsAdapter','vepDeviceSettings'], ['VepDeviceFeatureAdapter','vepDeviceFeatures']]) {
  const original = readFileSync(resolve(source, `entry/src/main/ets/services/${name}.ets`), 'utf8');
  const body = original.slice(original.indexOf(`class ${name}`));
  const imports = [...original.matchAll(/^import[\s\S]*?;\r?\n/gm)].map(match => match[0]).filter(text => !text.includes('@veepoo') && !text.includes('VepWearableService')).join('');
  const aliases = [...original.matchAll(/^export type [^\n]+/gm)].map(match => match[0]).join('\n');
  const methods = [...body.matchAll(/^  (?:async )?[a-zA-Z][a-zA-Z0-9_]*\([^\n]*\): [^{\n]+\{/gm)].map(match => match[0] + " throw new Error('模拟器不连接手表'); }").join('\n');
  write(`entry/src/main/ets/services/${name}.ets`, `${imports}\n${aliases}\nexport class ${name} {\n${methods}\n}\nexport const ${exported}: ${name} = new ${name}();\n`);
}
const abilityPath = 'entry/src/main/ets/entryability/EntryAbility.ets';
write(abilityPath, readFileSync(resolve(source, abilityPath), 'utf8').replace(/^import.*@veepoo.*\r?\n/m, '').replace(/    VPBleSDK.getInstance\(\).init\([\s\S]*?\n    \}\);/, '')
  .replace('  onCreate(want: Want): void {', `  onCreate(want: Want): void {
    const preview = String(want.parameters?.['preview'] ?? 'home');
    AppStorage.setOrCreate('SAYDIAN_UI_PREVIEW', ['home', 'login', 'care', 'articles', 'health-all', 'ecg-history'].includes(preview) ? preview : 'home');`));
const indexPath = 'entry/src/main/ets/pages/Index.ets';
write(indexPath, readFileSync(resolve(source, indexPath), 'utf8').replace("private screen: string = 'login'", "private screen: string = AppStorage.get<string>('SAYDIAN_UI_PREVIEW') ?? 'home'"));
unlinkSync(resolve(stage, 'entry/src/main/ets/services/YucWearableAdapter.ets'));
const packagePath = 'entry/oh-package.json5';
const pkg = JSON.parse(readFileSync(resolve(source, packagePath), 'utf8'));
delete pkg.dependencies['library']; delete pkg.dependencies['@veepoo/vpble-sdk']; write(packagePath, JSON.stringify(pkg, null, 2));
write('entry/build-profile.json5', JSON.stringify({ apiType: 'stageMode', buildOption: { externalNativeOptions: { abiFilters: ['x86_64'] },
  nativeLib: { filter: { excludes: ['**/arm64-v8a/**', '**/armeabi-v7a/**'] } } }, targets: [{ name: 'default' }] }, null, 2));
write('SIMULATOR-ONLY.txt', 'UI test build. No wearable SDKs and no synthetic health records. Same international API and bundle.\n');
console.log(`Simulator staged at ${stage}`);
