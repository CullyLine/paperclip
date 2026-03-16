import { google } from 'googleapis';
import http from 'http';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { CONFIG } from './config';

const SCOPES = [
  'https://www.googleapis.com/auth/youtube.upload',
  'https://www.googleapis.com/auth/youtube',
  'https://www.googleapis.com/auth/youtube.force-ssl',
];
const REDIRECT_PORT = 8976;
const REDIRECT_URI = `http://localhost:${REDIRECT_PORT}`;

const TOKEN_DIR = path.join(
  process.env.HOME || process.env.USERPROFILE || '~',
  '.youtubegen',
);
const TOKEN_PATH = path.join(TOKEN_DIR, 'tokens.json');

const ALGORITHM = 'aes-256-gcm';
const KEY_LENGTH = 32;
const IV_LENGTH = 16;
const TAG_LENGTH = 16;

function getEncryptionKey(): Buffer {
  const raw = CONFIG.youtube.tokenKey;
  if (!raw) {
    throw new Error(
      'YOUTUBE_TOKEN_KEY env var is required for token encryption. ' +
        'Generate one with: node -e "console.log(require(\'crypto\').randomBytes(32).toString(\'hex\'))"',
    );
  }
  return crypto.scryptSync(raw, 'youtubegen-salt', KEY_LENGTH);
}

function encrypt(data: string): string {
  const key = getEncryptionKey();
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
  const encrypted = Buffer.concat([
    cipher.update(data, 'utf8'),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();
  const payload = Buffer.concat([iv, tag, encrypted]);
  return payload.toString('base64');
}

function decrypt(encoded: string): string {
  const key = getEncryptionKey();
  const payload = Buffer.from(encoded, 'base64');
  const iv = payload.subarray(0, IV_LENGTH);
  const tag = payload.subarray(IV_LENGTH, IV_LENGTH + TAG_LENGTH);
  const encrypted = payload.subarray(IV_LENGTH + TAG_LENGTH);
  const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
  decipher.setAuthTag(tag);
  const decrypted = Buffer.concat([
    decipher.update(encrypted),
    decipher.final(),
  ]);
  return decrypted.toString('utf8');
}

interface StoredTokens {
  refresh_token: string;
}

function saveTokens(refreshToken: string): void {
  fs.mkdirSync(TOKEN_DIR, { recursive: true });
  const data: StoredTokens = { refresh_token: refreshToken };
  const encrypted = encrypt(JSON.stringify(data));
  fs.writeFileSync(TOKEN_PATH, encrypted, 'utf8');
  console.log(`  Tokens saved to ${TOKEN_PATH}`);
}

function loadTokens(): StoredTokens | null {
  if (!fs.existsSync(TOKEN_PATH)) return null;
  try {
    const encrypted = fs.readFileSync(TOKEN_PATH, 'utf8');
    const json = decrypt(encrypted);
    return JSON.parse(json) as StoredTokens;
  } catch {
    console.error(
      'Failed to decrypt tokens. The token file may be corrupted or YOUTUBE_TOKEN_KEY changed.',
    );
    return null;
  }
}

function createOAuth2Client() {
  const { clientId, clientSecret } = CONFIG.youtube;
  if (!clientId || !clientSecret) {
    throw new Error(
      'GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET env vars are required. ' +
        'Create OAuth credentials at https://console.cloud.google.com/apis/credentials',
    );
  }
  return new google.auth.OAuth2(clientId, clientSecret, REDIRECT_URI);
}

/**
 * Run the interactive OAuth2 consent flow.
 * Opens a local server, launches the browser, and waits for the callback.
 */
export async function runAuthFlow(): Promise<void> {
  const oauth2 = createOAuth2Client();

  const authUrl = oauth2.generateAuthUrl({
    access_type: 'offline',
    scope: SCOPES,
    prompt: 'consent',
  });

  const code = await new Promise<string>((resolve, reject) => {
    const server = http.createServer((req, res) => {
      const url = new URL(req.url || '/', REDIRECT_URI);
      const authCode = url.searchParams.get('code');
      const error = url.searchParams.get('error');

      if (error) {
        res.writeHead(400, { 'Content-Type': 'text/html' });
        res.end(
          '<h1>Authorization denied</h1><p>You can close this window.</p>',
        );
        server.close();
        reject(new Error(`OAuth error: ${error}`));
        return;
      }

      if (authCode) {
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(
          '<h1>Authorization successful!</h1><p>You can close this window and return to the terminal.</p>',
        );
        server.close();
        resolve(authCode);
        return;
      }

      res.writeHead(404);
      res.end();
    });

    server.listen(REDIRECT_PORT, () => {
      console.log(`\n  OAuth callback server listening on port ${REDIRECT_PORT}`);
      console.log(`\n  Open this URL in your browser to authorize:\n`);
      console.log(`  ${authUrl}\n`);

      // Try to open the browser automatically
      const openCmd =
        process.platform === 'win32'
          ? 'start'
          : process.platform === 'darwin'
            ? 'open'
            : 'xdg-open';

      import('child_process').then(({ exec }) => {
        exec(`${openCmd} "${authUrl}"`);
      });
    });

    server.on('error', reject);

    setTimeout(() => {
      server.close();
      reject(new Error('OAuth flow timed out after 5 minutes'));
    }, 5 * 60 * 1000);
  });

  console.log('  Exchanging authorization code for tokens...');
  const { tokens } = await oauth2.getToken(code);

  if (!tokens.refresh_token) {
    throw new Error(
      'No refresh token received. This can happen if the app was previously authorized. ' +
        'Revoke access at https://myaccount.google.com/permissions and try again.',
    );
  }

  saveTokens(tokens.refresh_token);
  console.log('\n  YouTube authentication complete!');
  console.log(
    '  Note: Unverified OAuth apps can only upload private videos.',
  );
}

/**
 * Get an authenticated OAuth2 client with a valid access token.
 * Auto-refreshes using the stored refresh token.
 */
export async function getAuthenticatedClient() {
  const stored = loadTokens();
  if (!stored) {
    throw new Error(
      'Not authenticated. Run the "auth" command first:\n' +
        '  npx tsx src/index.ts auth',
    );
  }

  const oauth2 = createOAuth2Client();
  oauth2.setCredentials({ refresh_token: stored.refresh_token });

  try {
    await oauth2.getAccessToken();
  } catch (err: any) {
    if (
      err.message?.includes('invalid_grant') ||
      err.message?.includes('Token has been expired or revoked')
    ) {
      throw new Error(
        'Refresh token has been revoked or expired. Re-run the "auth" command to re-authorize:\n' +
          '  npx tsx src/index.ts auth',
      );
    }
    throw err;
  }

  return oauth2;
}
