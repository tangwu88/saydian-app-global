import test from 'node:test';
import assert from 'node:assert/strict';
import { yucBattery, vepBatteryCharge } from '../entry/src/main/ets/model/WearableBattery.ts';
import { batteryText, createWearableDevice, mergeWearableDevices } from '../entry/src/main/ets/model/WearableContracts.ts';
test('W8 four charging states are independent of percentage and low power',()=>{
  assert.match(batteryText(yucBattery(100,0,1)),/未充电/);assert.match(batteryText(yucBattery(50,2,1)),/充电中/);
  assert.match(batteryText(yucBattery(100,3,1)),/已充满/);assert.match(batteryText(yucBattery(100,-1,1)),/状态未知/);
  assert.equal(yucBattery(100,-1,1).chargingState,'unknown');assert.match(batteryText(yucBattery(10,2,1)),/低电量/);
});
test('W9 unreliable full indication remains unknown',()=>{assert.equal(vepBatteryCharge(3),'unknown');assert.equal(vepBatteryCharge(1),'charging');assert.equal(vepBatteryCharge(2),'not_charging');});
test('mixed adapter RSSI ordering preserves ties through repeated updates and puts unknown last',()=>{
  const make=(provider,name,rssi)=>createWearableDevice(provider,name,name,'',rssi,true);
  let rows=mergeWearableDevices([],[make('Yuc','W8',-50),make('Urion','U19',-50),make('Vep','W9',-20),make('Urion','U19S',0)]);
  assert.deepEqual(rows.map(row=>row.name),['W9','W8','U19','U19S']);
  rows=mergeWearableDevices(rows,[make('Yuc','W8',-50)]);assert.deepEqual(rows.map(row=>row.name),['W9','W8','U19','U19S']);
  rows=mergeWearableDevices(rows,[make('Urion','U19S',-10)]);assert.deepEqual(rows.map(row=>row.name),['U19S','W9','W8','U19']);
});
