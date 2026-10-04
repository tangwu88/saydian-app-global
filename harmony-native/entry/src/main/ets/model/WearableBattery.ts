import type { BatteryState } from './WearableContracts';
export function yucBattery(level: number, state: number, now: number): BatteryState {
  const available = Number.isInteger(level) && level >= 0 && level <= 100;
  const charge = state === 0 || state === 1 ? 'not_charging' : state === 2 ? 'charging' : state === 3 ? 'full' : 'unknown';
  return { available: available, hasPercentage: available, level: available ? level : 0, levelGrade: 0,
    charging: charge === 'charging', chargingState: charge, lowBattery: state === 1 || (available && level <= 15), updatedAt: now };
}
export function vepBatteryCharge(mode: number): 'unknown' | 'not_charging' | 'charging' {
  // W9's older SDK full flag is not trustworthy enough to assert "full".
  return mode === 0 || mode === 2 ? 'not_charging' : mode === 1 ? 'charging' : 'unknown';
}
