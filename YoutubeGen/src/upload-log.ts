import fs from 'fs';
import path from 'path';
import { CONFIG } from './config';
import type { UploadRecord, UploadStatus } from './types';

const LOG_PATH = path.join(CONFIG.outputDir, 'upload-log.json');

function readLog(): UploadRecord[] {
  if (!fs.existsSync(LOG_PATH)) return [];
  try {
    const raw = fs.readFileSync(LOG_PATH, 'utf8');
    return JSON.parse(raw) as UploadRecord[];
  } catch {
    return [];
  }
}

function writeLog(records: UploadRecord[]): void {
  fs.mkdirSync(path.dirname(LOG_PATH), { recursive: true });
  fs.writeFileSync(LOG_PATH, JSON.stringify(records, null, 2), 'utf8');
}

export function logUpload(record: UploadRecord): void {
  const records = readLog();
  const existing = records.findIndex((r) => r.outputName === record.outputName);
  if (existing >= 0) {
    records[existing] = record;
  } else {
    records.push(record);
  }
  writeLog(records);
}

export function getUploadByName(outputName: string): UploadRecord | undefined {
  return readLog().find((r) => r.outputName === outputName);
}

export function updateUploadStatus(
  outputName: string,
  status: UploadStatus,
  updates?: Partial<UploadRecord>,
): void {
  const records = readLog();
  const record = records.find((r) => r.outputName === outputName);
  if (!record) {
    throw new Error(`Upload record not found: ${outputName}`);
  }
  record.status = status;
  if (updates) Object.assign(record, updates);
  writeLog(records);
}

export function listPendingUploads(): UploadRecord[] {
  return readLog().filter((r) => r.status === 'pending');
}

export function listAllUploads(): UploadRecord[] {
  return readLog();
}
