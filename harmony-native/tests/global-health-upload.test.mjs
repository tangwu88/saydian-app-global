import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { registerHooks } from 'node:module';
registerHooks({resolve(specifier,context,next){return next(specifier.startsWith('.') && context.parentURL?.endsWith('.ts') && !/\.[a-z]+$/.test(specifier)?specifier+'.ts':specifier,context)}});
const { globalHealthRow, globalHealthAccepted } = await import('../entry/src/main/ets/model/GlobalHealthUpload.ts');
const { AccountClient } = await import('../entry/src/main/ets/services/AccountClient.ts');
const { HealthUploadService } = await import('../entry/src/main/ets/services/HealthUploadService.ts');
const now=Date.UTC(2026,9,4), owner='10000000-0000-4000-8000-000000000001';
const record=(id='synthetic-one')=>({id,deviceKey:'Urion|synthetic',metric:'pressure',timestamp:now,source:'watch_history',
  values:[{name:'收缩压',value:120,unit:'mmHg'},{name:'舒张压',value:80,unit:'mmHg'}],samples:[],sampleFrequency:0,
  model:'U19',firmware:'fixture',quality:'unknown',rawVersion:2,timezoneOffsetMinutes:480});
function clientFixture(handler) {
  const calls=[];
  const vault={async read(){return undefined},async write(){},async clear(){}};
  const transport={async request(...args){calls.push(args);return {code:200,data:args[0].endsWith('/auth/login')?
    {accessToken:'fixture-access',refreshToken:'fixture-refresh',expiresAt:new Date(now+3600000).toISOString(),member:{id:owner,nickname:'Synthetic user'}}:
    await handler(...args)}},async hash(text){return createHash('sha256').update(text).digest('hex')}};
  const client=new AccountClient(transport,vault,()=>now,true);
  return {client,calls};
}
test('V2 preserves record id, original instant, offset, source and canonical pressure fields',()=>{
  const row=globalHealthRow(record(),false);
  assert.equal(row.id,'synthetic-one');assert.equal(row.metric,'blood_pressure');
  assert.equal(row.observedAt,new Date(now).toISOString());assert.equal(row.timezoneOffsetMinutes,480);
  assert.deepEqual(row.values,{systolic:120,diastolic:80});assert.equal(row.source.platform,'harmony');
});
test('old records and unknown waveform timing stay pending without invented metadata',()=>{
  for(const field of ['quality','rawVersion','timezoneOffsetMinutes']){
    const row=record();delete row[field];assert.equal(globalHealthRow(row,false),undefined);
  }
  const ecg={...record(),metric:'ecg',samples:[1,2,3],sampleFrequency:0};
  assert.equal(globalHealthRow(ecg,false),undefined);
});
test('daily summaries require explicit supported version and keep date and version',()=>{
  const row={...record(),metric:'activity',aggregation:{kind:'daily_summary',localDate:'2026-10-03',version:1}};
  assert.equal(globalHealthRow(row,false),undefined);
  assert.deepEqual(globalHealthRow(row,true).aggregation,row.aggregation);
  assert.equal(globalHealthRow({...row,aggregation:{...row.aggregation,localDate:'2026-02-30'}},true),undefined);
});
test('waveform receipt must match full samples, rate and private object location',()=>{
  const row={...record(),metric:'ecg',samples:[1,2,3],sampleFrequency:250,ecgArtifact:{
    uploadObjectKey:'ecg/private-fixture',sampleRateHz:250,sampleCount:3,sha256:'a'.repeat(64),byteSize:28,encoding:'gzip_json_v1'}};
  assert.equal(globalHealthRow(row,false).values.sampleCount,3);
  for(const changes of [{sampleCount:2},{sampleRateHz:200},{uploadObjectKey:'public/fixture'},{sha256:'bad'}])
    assert.equal(globalHealthRow({...row,ecgArtifact:{...row.ecgArtifact,...changes}},false),undefined);
});
test('only explicit valid per-record acknowledgements succeed',()=>{
  assert.deepEqual(globalHealthAccepted({acceptedIds:['a'],rejected:[{id:'b'}]},['a','b']),['a']);
  assert.deepEqual(globalHealthAccepted({acceptedIds:[],rejected:[]},['a']),[]);
  for(const ack of [undefined,{}, {acceptedIds:['a']}, {acceptedIds:['foreign'],rejected:[]},
    {acceptedIds:['a','a'],rejected:[]},{acceptedIds:['a'],rejected:[{id:'a'}]},
    {acceptedIds:[],rejected:[{id:'a'},{id:'a'}]}, {acceptedIds:['a'],rejected:[],nextCursor:1}])
    assert.throws(()=>globalHealthAccepted(ack,['a']));
});
test('actual AccountClient sends a V2 batch with a deterministic idempotency key',async()=>{
  const f=clientFixture((path,fields,session,body)=>({acceptedIds:JSON.parse(body).records.map(row=>row.id),rejected:[]}));
  await f.client.login('synthetic@example.com','fixture-password');
  assert.deepEqual(await f.client.uploadGlobalHealthRecords([record()],f.client.healthSession()),['synthetic-one']);
  const call=f.calls.at(-1);assert.equal(call[0],'/api/saydian-app/v2/health/records/batch');
  assert.equal(call[6],'global-health-'+createHash('sha256').update(call[3]).digest('hex'));
  assert.equal(JSON.parse(call[3]).records[0].source.platform,'harmony');
});
test('actual daily capability response gates summary uploads',async()=>{
  for(const supported of [false,true]){
    const f=clientFixture(path=>path.endsWith('/capabilities')?{dailySummaryVersions:supported,dailySummaryVersion:1}:
      {acceptedIds:['synthetic-one'],rejected:[]});
    await f.client.login('synthetic@example.com','fixture-password');
    const row={...record(),aggregation:{kind:'daily_summary',localDate:'2026-10-03',version:1}};
    assert.deepEqual(await f.client.uploadGlobalHealthRecords([row],f.client.healthSession()),supported?['synthetic-one']:[]);
    assert.equal(f.calls.some(call=>call[0].endsWith('/records/batch')),supported);
  }
});
test('coordinator persists waveform receipt before upload and marks only ACKed rows',async()=>{
  const order=[],marked=[];let rows=[record('a'),record('b')];
  const session={ownerId:owner,generation:1};
  const store={async pending(owner,excluded=[]){return rows.filter(row=>!excluded.includes(row.id))},async pendingCount(){return rows.length},
    async savePreparedRecord(owner,previous,next){order.push('persist:'+next.id)},
    async markUploaded(owner,records){marked.push(...records.map(row=>row.id));rows=rows.filter(row=>!records.some(record=>record.id===row.id))}};
  const api={globalHealthEnabled:true,healthSession(){return session},
    async prepareGlobalHealthRecord(row){return {...row,firmware:'prepared'}},
    async uploadGlobalHealthRecords(prepared){order.push('batch');return ['a']}};
  const result=await new HealthUploadService(store,api).synchronize();
  assert.deepEqual(order,['persist:a','persist:b','batch']);assert.deepEqual(marked,['a']);
  assert.equal(result.state,'retry');assert.equal(result.uploaded,1);assert.equal(result.pending,1);
});
test('account switch during preparation never persists, uploads or acknowledges old data',async()=>{
  let session={ownerId:owner,generation:1},writes=0;
  const store={async pending(){return [record()]},async pendingCount(){return 1},
    async savePreparedRecord(){writes++},async markUploaded(){writes++}};
  const api={globalHealthEnabled:true,healthSession(){return session},
    async prepareGlobalHealthRecord(row){session={ownerId:'another-owner',generation:2};return {...row,firmware:'prepared'}},
    async uploadGlobalHealthRecords(){writes++;return []}};
  const result=await new HealthUploadService(store,api).synchronize();
  assert.equal(result.state,'cancelled');assert.equal(writes,0);
});
test('missing metadata cannot starve later valid records and is never marked synced',async()=>{
  let rows=[...Array.from({length:20},(_,index)=>({...record('incomplete-'+index),quality:undefined})),record('valid-later')];
  const marked=[],session={ownerId:owner,generation:1};
  const store={async pending(owner,excluded=[]){return rows.filter(row=>!excluded.includes(row.id)).slice(0,20)},async pendingCount(){return rows.length},async savePreparedRecord(){},
    async markUploaded(owner,records){marked.push(...records.map(row=>row.id));rows=rows.filter(row=>!records.some(record=>record.id===row.id))}};
  const api={globalHealthEnabled:true,healthSession(){return session},async prepareGlobalHealthRecord(row){return row},async uploadGlobalHealthRecords(records){return records.filter(row=>globalHealthRow(row,false)).map(row=>row.id)}};
  const result=await new HealthUploadService(store,api).synchronize();
  assert.deepEqual(marked,['valid-later']);assert.equal(result.pending,20);assert.equal(result.state,'retry');
});
