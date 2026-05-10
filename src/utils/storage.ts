import { Capacitor } from '@capacitor/core';
import { Preferences } from '@capacitor/preferences';

const isNative = Capacitor.isNativePlatform();

export async function storageGet(key: string): Promise<string | null> {
  if (!isNative) return localStorage.getItem(key);
  const { value } = await Preferences.get({ key });
  return value;
}

export async function storageSet(key: string, value: string): Promise<void> {
  if (!isNative) { localStorage.setItem(key, value); return; }
  await Preferences.set({ key, value });
}

export async function storageRemove(key: string): Promise<void> {
  if (!isNative) { localStorage.removeItem(key); return; }
  await Preferences.remove({ key });
}
