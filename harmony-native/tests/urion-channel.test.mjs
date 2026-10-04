import test from 'node:test';
import assert from 'node:assert/strict';
import { registerHooks } from 'node:module';
registerHooks({resolve(specifier,context,next){return next(specifier.startsWith('.') && context.parentURL?.endsWith('.ts') && !/\.[a-z]+$/.test(specifier)?specifier+'.ts':specifier,context)}});
const {Eb1Frame}=await import('../entry/src/main/ets/model/UrionEb1Protocol.ts');
const {UrionCommandChannel}=await import('../entry/src/main/ets/services/UrionCommandChannel.ts');
const tick=()=>new Promise(resolve=>setImmediate(resolve));
test('Urion commands are serialized through complete fragmented responses',async()=>{
  const writes=[],notifications=[];
  const channel=new UrionCommandChannel(async bytes=>writes.push(bytes),()=>{},frame=>notifications.push(frame),500);
  const first=channel.exchange(7,[0],2),second=channel.exchange(3);
  await tick();assert.equal(writes.length,1);
  channel.receive(Eb1Frame.request(0x73,[2]).bytes,channel.session());assert.equal(notifications.length,1);
  const daily0=Eb1Frame.request(7,[0]).bytes,daily1=Eb1Frame.request(7,[1]).bytes;
  channel.receive(daily0.slice(0,7),channel.session());await tick();assert.equal(writes.length,1);
  channel.receive([...daily0.slice(7),...daily1],channel.session());assert.equal((await first).length,2);
  await tick();assert.equal(writes.length,2);
  channel.receive(Eb1Frame.request(3,[81]).bytes,channel.session());assert.equal((await second)[0].bytes[1],81);
});
test('retired connection callbacks cannot settle a new command or keep old queued work',async()=>{
  const writes=[],channel=new UrionCommandChannel(async bytes=>writes.push(bytes),()=>{},()=>{},500);
  const oldGeneration=channel.session();
  const first=channel.exchange(3),queued=channel.exchange(7,[0],2);
  const rejections=Promise.all([assert.rejects(first),assert.rejects(queued)]);
  await tick();channel.retire();await rejections;
  const fresh=channel.exchange(3);await tick();
  channel.receive(Eb1Frame.request(3,[20]).bytes,oldGeneration);
  channel.receive(Eb1Frame.request(3,[90]).bytes,channel.session());
  assert.equal((await fresh)[0].bytes[1],90);assert.equal(writes.length,2);
});
test('timeout releases the connection and rejects queued commands',async()=>{
  let releases=0,writes=0;
  const channel=new UrionCommandChannel(async()=>{writes++},()=>{releases++},()=>{},20);
  await Promise.all([assert.rejects(channel.exchange(3)),assert.rejects(channel.exchange(7,[0],2))]);
  assert.equal(releases,1);assert.equal(writes,1);
});
test('unsupported replies close only that command; malformed packet order retires the session',async()=>{
  let releases=0;
  const channel=new UrionCommandChannel(async()=>{},()=>{releases++},()=>{},500);
  const unsupported=channel.exchange(0x36);await tick();
  channel.receive(Eb1Frame.request(0xb6,[0xee]).bytes,channel.session());await assert.rejects(unsupported,/unsupported/);
  assert.equal(releases,0);
  const bad=channel.exchange(7,[0],2);const rejection=assert.rejects(bad);await tick();
  channel.receive(Eb1Frame.request(7,[1]).bytes,channel.session());await rejection;assert.equal(releases,1);
});
