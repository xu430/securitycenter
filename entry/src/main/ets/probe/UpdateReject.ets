import fs from '@ohos.file.fs';
import { VERIFY_REJECT_CODE } from './ProbeTypes';

const FILE_NAME: string = 'update-reject.json';
const TEXT: string = '{"code":17700011}';

export function canonicalRejectCode(code: number): number {
  if (isSignatureReject(code)) {
    return VERIFY_REJECT_CODE;
  }
  return -1;
}

export function codeFromParameter(value: Object | undefined): number {
  if (typeof value === 'number') {
    return canonicalRejectCode(value);
  }
  if (typeof value === 'string') {
    return canonicalRejectCode(digits(value));
  }
  return -1;
}

export function parseRejectCode(text: string): number {
  if (typeof text !== 'string' || text.length === 0 || text.length > 200) {
    return -1;
  }
  try {
    let parsed = JSON.parse(text) as RejectBody;
    if (!parsed || typeof parsed !== 'object' || parsed instanceof Array) {
      return -1;
    }
    if (typeof parsed.code !== 'number') {
      return -1;
    }
    return canonicalRejectCode(parsed.code);
  } catch (err) {
    return -1;
  }
}

export function loadRejectCode(filesDir: string): number {
  if (typeof filesDir !== 'string' || filesDir.length === 0) {
    return -1;
  }
  try {
    let opened = fs.openSync(filesDir + '/' + FILE_NAME, fs.OpenMode.READ_ONLY);
    try {
      let stat = fs.statSync(opened.fd);
      if (stat.size <= 0 || stat.size > 200) {
        fs.closeSync(opened);
        return -1;
      }
      let buffer = new ArrayBuffer(stat.size);
      fs.readSync(opened.fd, buffer);
      fs.closeSync(opened);
      return parseRejectCode(bytesToText(new Uint8Array(buffer)));
    } catch (err) {
      try {
        fs.closeSync(opened);
      } catch (closeErr) {
        return -1;
      }
      return -1;
    }
  } catch (err) {
    return -1;
  }
}

export function storeRejectCode(filesDir: string, code: number): boolean {
  if (filesDir.length === 0 || canonicalRejectCode(code) !== VERIFY_REJECT_CODE) {
    return false;
  }
  let buffer = new ArrayBuffer(TEXT.length);
  let view = new Uint8Array(buffer);
  for (let i = 0; i < TEXT.length; i++) {
    view[i] = TEXT.charCodeAt(i);
  }
  try {
    let opened = fs.openSync(filesDir + '/' + FILE_NAME,
      fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(opened.fd, buffer);
      fs.closeSync(opened);
      return true;
    } catch (err) {
      try {
        fs.closeSync(opened);
      } catch (closeErr) {
        return false;
      }
      return false;
    }
  } catch (err) {
    return false;
  }
}

export function clearRejectFile(filesDir: string): void {
  if (filesDir.length === 0) {
    return;
  }
  try {
    fs.unlinkSync(filesDir + '/' + FILE_NAME);
  } catch (err) {
    return;
  }
}

class RejectBody {
  code: number = 0;
}

function isSignatureReject(code: number): boolean {
  if (code === VERIFY_REJECT_CODE || code === 9568257 || code === 9568264) {
    return true;
  }
  if (code === 17700073) {
    return true;
  }
  if (code === 9568320) {
    return false;
  }
  return code >= 9568318 && code <= 9568331;
}

function digits(text: string): number {
  if (text.length === 0 || text.length > 9) {
    return -1;
  }
  let n = 0;
  for (let i = 0; i < text.length; i++) {
    let ch = text.charAt(i);
    if (ch < '0' || ch > '9') {
      return -1;
    }
    n = n * 10 + text.charCodeAt(i) - '0'.charCodeAt(0);
  }
  return n;
}

function bytesToText(bytes: Uint8Array): string {
  let text = '';
  for (let i = 0; i < bytes.length; i++) {
    text += String.fromCharCode(bytes[i]);
  }
  return text;
}
