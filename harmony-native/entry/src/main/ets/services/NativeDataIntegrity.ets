import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
export async function sha256Bytes(bytes: Uint8Array): Promise<string> {
  const digest = cryptoFramework.createMd('SHA256');
  await digest.update({ data: bytes });
  const result = await digest.digest();
  return Array.from(result.data).map((byte: number) => byte.toString(16).padStart(2, '0')).join('');
}
export async function sha256Text(text: string): Promise<string> {
  return sha256Bytes(new util.TextEncoder().encodeInto(text));
}
export async function recordUuid(content: string): Promise<string> {
  const digest = await sha256Text(content);
  const hex = digest.slice(0, 12) + '5' + digest.slice(13, 16) +
    ((parseInt(digest[16], 16) & 3) | 8).toString(16) + digest.slice(17, 32);
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}
