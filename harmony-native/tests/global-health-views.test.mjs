import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { registerHooks } from 'node:module';
registerHooks({resolve(specifier, context, next) { return next(specifier.startsWith('.') && context.parentURL?.endsWith('.ts') && !/\.[a-z]+$/.test(specifier) ? specifier+'.ts' : specifier, context); }});
const { AccountClient } = await import('../entry/src/main/ets/services/AccountClient.ts');
const { setAppLocale, APP_LOCALES, appText } = await import('../entry/src/main/ets/model/GlobalLocale.ts');
const { globalViewRecords } = await import('../entry/src/main/ets/model/GlobalHealthViews.ts');
const { validateGlobalEcg } = await import('../entry/src/main/ets/model/GlobalEcg.ts');
const { trendWindow, trendRecords, trendSeries } = await import('../entry/src/main/ets/model/HealthTrend.ts');
const id = '10000000-0000-4000-8000-000000000001', relation = '20000000-0000-4000-8000-000000000001';
const now = Date.UTC(2026,9,4), envelope = data => ({code:200,data});
const sample = (metric='blood_pressure') => ({id:'synthetic-record',metric,observedAt:new Date(now).toISOString(),values:{systolic:120,diastolic:80,pulse:73}});
async function fixture(handler, waveform) {
  const calls=[];const client=new AccountClient({async request(...args){calls.push(args);return envelope(args[0].endsWith('/auth/login')?
    {accessToken:'synthetic-access',refreshToken:'synthetic-refresh',expiresAt:new Date(now+3600000).toISOString(),member:{id,nickname:'Synthetic'}}:await handler(...args));},waveform},
  {async read(){},async write(){},async clear(){}},()=>now,true);
  await client.login('synthetic@example.com','fixture-password');return {client,calls};
}
test('encyclopedia requests keep UUIDs, selected locale and V2 routes without legacy fallback', async()=>{
  setAppLocale('zh-Hans'); const f=await fixture(path=>path.includes('/categories')?[{id:relation,name:'中文分类'}]:path.includes('articles?')?{items:[{id:relation,title:'中文文章'}]}:{id:relation,title:'中文文章',contentHtml:'<p>正文</p>'});
  assert.equal((await f.client.articleCategories())[0].id,relation);
  assert.equal((await f.client.articlesByCategory(relation))[0].title,'中文文章');
  assert.equal((await f.client.article(relation,false)).content,'<p>正文</p>');
  for(const [path] of f.calls.slice(1)){assert.ok(path.startsWith('/api/saydian-app/v2/content/'));assert.ok(path.includes('locale=zh-Hans'));}
  assert.ok(f.calls[2][0].includes(`categoryId=${relation}`));setAppLocale('en');
});
test('care UUID relationship, exact UTC date range and isolated server fields are preserved', async()=>{
  const f=await fixture(path=>path.endsWith('/relationships')?[{id:relation,direction:'sent',status:'active',recipient:{nickname:'Synthetic member'},metrics:['blood_pressure']}]:path.endsWith('/summary')?{metrics:['blood_pressure'],records:[sample()]}:[sample()]);
  assert.equal((await f.client.globalCareRelationships())[0].id,relation);
  const overview=await f.client.globalCareSummary(relation);assert.deepEqual(overview.metrics,['blood_pressure']);
  assert.equal(overview.records[0].deviceKey,`care:${relation}`);assert.equal(overview.records[0].values[0].name,'收缩压');
  const window=trendWindow('2026-10-04','month');await f.client.globalCareRecords(relation,'blood_pressure',window.start,window.end);
  assert.ok(f.calls.at(-1)[0].includes(`from=${encodeURIComponent(new Date(window.start).toISOString())}`));
  await assert.rejects(f.client.globalCareRecords('31','blood_pressure',window.start,window.end));
});
test('late care data cannot cross account generations', async()=>{
  let resolve;const loading=new Promise(yes=>resolve=yes);const f=await fixture(()=>loading);
  const read=f.client.globalCareSummary(relation);await new Promise(yes=>setImmediate(yes));await f.client.logout();resolve({metrics:['ecg'],records:[sample('ecg')]});
  await assert.rejects(read,/旧账号|Account|Session|账号/);
});
test('permissions, respond and revoke use the relationship endpoint and correct verbs', async()=>{
  const f=await fixture(()=>({}));await f.client.globalCareWrite(relation,'permissions',{metrics:['ecg']});await f.client.globalCareWrite(relation,'respond',{accepted:false});await f.client.globalCareWrite(relation,'revoke');
  assert.equal(f.calls.at(-1)[4],'DELETE');assert.equal(f.calls.at(-1)[3],undefined);
  assert.deepEqual(JSON.parse(f.calls.at(-3)[3]),{metrics:['ecg']});
});
test('waveform validates full samples, digest and rate/count instead of trusting a success response',()=>{
  const digest='a'.repeat(64),expected={sampleRateHz:250,sampleCount:3,sha256:digest};
  assert.deepEqual(validateGlobalEcg([1,2,3],250,3,digest,expected).samples,[1,2,3]);
  for(const [samples,rate,count,sha] of [[[1,2],250,3,digest],[[1,NaN,3],250,3,digest],[[1,2,3],0,3,digest],[[1,2,3],250,3,'b'.repeat(64)]])assert.throws(()=>validateGlobalEcg(samples,rate,count,sha,expected));
});
test('ECG care read is authenticated per relationship and rejects stale account responses',async()=>{
  let resolve;const f=await fixture(()=>({}),async(path,session)=>{assert.equal(session.memberId,id);assert.ok(path.includes(`/care/relationships/${relation}/health/synthetic-record/ecg`));return new Promise(yes=>resolve=yes)});
  const record=globalViewRecords([sample('ecg')],`care:${relation}`)[0];const loading=f.client.globalEcg(record,relation);
  await new Promise(yes=>setImmediate(yes));await f.client.logout();resolve({samples:[1,2],sampleRateHz:250,sampleCount:2,sha256:'a'.repeat(64)});
  await assert.rejects(loading,/旧账号|账号/);
});
test('daily summary uses its data date and latest version, never adds re-reads',()=>{
  const base={id:'old',deviceKey:'device',metric:'activity',timestamp:new Date(2026,9,4,12).getTime(),source:'watch_history',values:[{name:'步数',value:100,unit:'步'}],samples:[],sampleFrequency:0,aggregation:{kind:'daily_summary',localDate:'2026-10-03',version:1}};
  const rows=[base,{...base,id:'new',timestamp:base.timestamp+1000,values:[{name:'步数',value:120,unit:'步'}]}];
  assert.equal(trendRecords(rows,'activity','device',trendWindow('2026-10-04','day')).length,0);
  const selected=trendRecords(rows,'activity','device',trendWindow('2026-10-03','day'));assert.equal(selected.length,1);assert.equal(selected[0].id,'new');
  assert.deepEqual(trendSeries(selected,'步数','month',{distance:'km',temperature:'c'}).points.map(point=>point.value),[120]);
});
test('new health interaction prompts are present in all eight languages',()=>{
  for(const locale of APP_LOCALES)for(const key of ['待同步','波形预览','暂无授权指标','波形加载失败，重试','管理'])assert.ok(appText(key,locale).trim());
});

test('new component actions and prompts have translations outside Chinese locales',()=>{
  for(const name of ['GlobalCarePage','EcgWaveformView','OwnEcgHistoryPage','UrionFeaturesPage']) {
    const source=readFileSync(new URL(`../entry/src/main/ets/components/${name}.ets`,import.meta.url),'utf8');
    for(const [,key] of source.matchAll(/this\.tr\('([^']+)'\)/g)) {
      for(const locale of ['en','de','fr','es']) assert.doesNotMatch(appText(key,locale),/[\u4e00-\u9fff]/,`${name}: ${locale}: ${key}`);
    }
  }
});
