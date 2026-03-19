#!/usr/bin/env node

/**
 * Splice CLI — search, claim, and download sounds from Splice.
 *
 * ETHICAL SAFEGUARD: This tool enforces the proper licensing flow:
 *   1. Preview  — listen to scrambled MP3 previews (free, no credits)
 *   2. Claim    — officially license the sound (spends subscription credits)
 *   3. Download — retrieve the full-quality WAV (only after claiming)
 *
 * Full-quality downloads are BLOCKED until the sound is claimed/licensed.
 * This ensures compliance with Splice's terms of service.
 *
 * Auth uses browser token capture via Auth0.
 * Tokens are cached locally in ~/.splice-cli/tokens.json.
 */

import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import http from "node:http";
import https from "node:https";
import crypto from "node:crypto";
import { URL, URLSearchParams as URLSearchParamsNode } from "node:url";
import readline from "node:readline";
import { execFile } from "node:child_process";

// ─── Auth0 / Splice constants ────────────────────────────────────────────────

const AUTH0_DOMAIN = "https://auth.splice.com";
const CLIENT_ID = "J5JVCGkJmtoM5eiI8LGkPuma93exQV8H";
const AUDIENCE = "https://splice.com";
const SCOPES = "openid profile email offline_access";

const GRAPHQL_URL = "https://surfaces-graphql.splice.com/graphql";
const API_BASE = "https://api.splice.com";

// ─── Tag lookup tables (fetched from Splice's GraphQL API) ──────────────────

const GENRE_TAGS = {
  "house":"17a74e87-ed5b-4d27-ab49-0753aa28302d","hip-hop":"5b78c4d9-4555-464f-bce2-5961c74b6446",
  "cinematic":"ff050da9-c9f2-4de6-8977-b392c10c8b73","techno":"dfd79b66-34f9-42be-a50c-916546c72c50",
  "trap":"db48570c-6e15-4f8b-8fdb-c63b2d26cc66","edm":"b5758088-7050-4e63-8ad6-988ee02377a9",
  "pop":"f136a231-7037-4c27-95f8-dd528b50e824","tech-house":"0da93a8a-7feb-4f5d-915c-536e5047ee8e",
  "rnb":"3d8b3172-e93a-4fe0-aa3b-4d8c22026b23","r&b":"3d8b3172-e93a-4fe0-aa3b-4d8c22026b23",
  "deep-house":"eb57ae5f-5a2b-4bcf-8057-f39069272ec8","soul":"bc2d49b8-790c-4778-9a2b-539e4d7d618a",
  "downtempo":"cc3a1638-627c-4c3f-a8d7-2b0fd5fecfd0","drum-and-bass":"e52fea78-eebd-4b18-a1e5-b413b69d3fae",
  "dnb":"e52fea78-eebd-4b18-a1e5-b413b69d3fae","dubstep":"d8735d76-b47d-478b-871a-0c991393813e",
  "progressive-house":"3d025bed-3073-49fc-abbb-e7b156a3ab7d","ambient":"0e27bf48-9a13-4885-b6c5-28661cf68427",
  "experimental":"7bf8dc7b-f6ad-429a-9d94-a5b972dff13e","trance":"43def0c8-f66e-4cb1-9824-d4f43432df2d",
  "game-audio":"f442edf9-91e9-4709-b74b-b26fbf2a91d0","future-bass":"22515620-6d9d-4e22-8c43-af257e01a53f",
  "lo-fi-hip-hop":"d6949986-73ad-478d-8fb6-5bb91df4196d","lofi":"d6949986-73ad-478d-8fb6-5bb91df4196d",
  "trap-edm":"38d2a2cf-3e19-4b97-8e2e-a3052b5e1781","synthwave":"b64fcb45-cf69-4668-aa90-33440207f2ec",
  "uk-garage":"0358a7d5-887a-486e-a70a-65c38cbf028d","bass-music":"e2d7f135-23ef-484e-974c-c063443de332",
  "funk":"2a40ea0f-a1b7-49b4-bf58-8cf25bfe1109","disco":"cb547c00-3a18-4d8b-81e6-cdd6501500b7",
  "indie":"18503383-8e54-458c-be3b-ff70c73adcfa","melodic-techno":"7e20fe90-1cb4-47dc-8bcd-632025f953c3",
  "electro":"cf2cb5d6-e1da-48fb-88ec-6ec5e3dcc8dd","rock":"6d1bb1ee-2599-411e-9e5a-a8368ae23bf2",
  "boom-bap":"76369676-7df0-461e-966e-00e9122208d2","jazz":"97d8fb98-a941-47f9-aa28-4a6c783a8b02",
  "bass-house":"4ad3dc13-3a3b-4377-9966-c00e9d2691e9","hard-techno":"2a154812-bfdf-411f-b036-d4cfbbcbbd9c",
  "afrobeats":"15d46aa1-8180-47f6-8a32-5b18e5efa8e7","psy-trance":"787c9495-bcec-4377-a11d-661e29f941b1",
  "synth-pop":"f5fcc285-16b4-4ba0-ac86-705ec607a78a","chillout":"9cb36244-b4d2-43fc-bb36-ab5a030cb73f",
  "indie-rock":"25a795c8-3a2b-427f-9f4e-30c20bb39f1a","indie-pop":"20a4a580-8211-4a39-95b7-6fa45c9e080c",
};

const INSTRUMENT_TAGS = {
  "drums":"62e4d5d5-4063-4fe0-a8ca-6a11619e8ed5","synth":"d5b91338-6269-4dde-9448-e1dbc3cf1ac5",
  "percussion":"8db1fa7d-2ac6-4fae-9f97-fdb13690135b","vocals":"8d201ce4-4a78-4684-8afd-467fa2ea109c",
  "kicks":"f17504bb-33f0-4611-a4ac-4e86274f109f","hats":"3e3e0aa3-963f-4830-a74b-f62dafcf9249",
  "snares":"08769d8d-b9b9-489b-bf4b-72a58ca37caf","keys":"cf642cbd-c86f-4f10-b2c1-79192912b9df",
  "guitar":"bdda9fa9-e4eb-4ec5-9593-7885f9c8ddba","claps":"d060adaa-8b23-4665-a4fe-15c0696b2e43",
  "strings":"37601a83-36a3-4213-8d90-6f1a8dc81d9f","cymbals":"31227970-a920-4288-ad33-da0cd6f0cc6a",
  "piano":"0a0daeea-8acf-4741-b662-69e38841b52c","brass":"6ee76ea2-73c8-4788-9a27-9460281dfdbe",
  "woodwinds":"6ee76ea2-73c8-4788-9a27-9460281dfdbe","electric-guitar":"8398c145-0612-4bee-991d-60e81fcdba95",
  "808":"19433857-acfb-40e5-b086-18e459483023","live-sounds":"11ed9204-37c0-43b8-9be7-e541d7fd9379",
};

const ATTRIBUTE_TAGS = {
  "fx":"107d2914-6ad5-4de3-a60b-9be20b24b4e1","bass":"842a2218-1221-4f96-9413-608c83d054f1",
  "grooves":"183d25aa-82f9-4d36-9308-cf5ded0e510b","chords":"618d028c-83ae-498e-8fab-04e71a975142",
  "leads":"88cfc92e-899b-47dc-a855-0ec7ba8add11","pads":"79b2c789-4686-4f23-a20a-a347e7505125",
  "melody":"e61a976d-fa99-4279-94e2-dfaba37b195b","textures":"039ef920-a9e9-4b36-892b-40f9a3afaa40",
  "foley":"1fbfc140-47e8-4f81-a7dc-2d54dbd276e9","impacts":"1dc77bca-6ec8-4ee7-8c2e-b251e619cc52",
  "atmospheres":"d8f51565-e94a-47db-9a36-1ebabbb13588","noise":"fd384fd2-6138-4152-9867-7c84688a01e5",
  "fills":"e76b8272-2717-46ad-83cc-6789075f8371","plucks":"ab5d0f5e-f584-4d28-958b-a2090f657389",
  "glitch":"a4772688-099f-483b-abae-1e51d2cbd2b5","found-sounds":"6b1070c6-e438-4dbf-a5c6-766bb67d68c0",
  "songstarters":"a5188c43-9c53-45d9-b5dd-9c33cb28358b","phrases":"d01a7496-11b5-45a0-a2d9-5930a4295dac",
  "tops":"5bd3ffd9-0c2b-44f2-b6d0-02e4c45311f2",
  "wet":"4a3ee9c8-2289-4a70-b61c-48d722c8ebbc","dry":"efe680e7-43b7-42d1-a942-f58d02656a3f",
  "lo-fi":"9d006327-19d2-4f47-a338-e9645d27433e","acoustic":"60845712-1235-4d2d-a3ce-f68a4ca625df",
  "electric":"6fbcf27e-8fc9-48ee-811a-71c2abd81132","organic":"5476bbfd-c9c9-4033-9919-c59886e243fc",
  "metallic":"5efdeabd-0e1e-4600-98f2-164e7bef51a8","layered":"a7f4d673-9938-4643-a214-54ef944e67fa",
  "sub":"2d608c6f-202f-4ac7-8e26-e1cf36941108",
  "female":"27eb920a-144d-4497-9242-edc8c035b8bf","male":"cc7f6a71-6706-4ae0-b4f9-c611539f9afa",
  "open":"db9e5327-4de0-4622-8b68-1e164b686821","closed":"ab0b91f5-9934-4624-88ba-1977bacc0b71",
};

function resolveTagId(name) {
  const key = name.toLowerCase().replace(/\s+/g, "-");
  return GENRE_TAGS[key] || INSTRUMENT_TAGS[key] || ATTRIBUTE_TAGS[key] || null;
}

function listAvailableTags() {
  console.log("\n  Genres:      " + Object.keys(GENRE_TAGS).filter(k => !["r&b","dnb","lofi"].includes(k)).join(", "));
  console.log("\n  Instruments: " + Object.keys(INSTRUMENT_TAGS).filter(k => k !== "woodwinds").join(", "));
  console.log("\n  Attributes:  " + Object.keys(ATTRIBUTE_TAGS).join(", "));
  console.log();
}

const TOKEN_DIR = path.join(os.homedir(), ".splice-cli");
const TOKEN_FILE = path.join(TOKEN_DIR, "tokens.json");

// ─── HTTP helpers ────────────────────────────────────────────────────────────

function httpRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const reqOptions = {
      hostname: parsed.hostname,
      port: parsed.port || 443,
      path: parsed.pathname + parsed.search,
      method: options.method || "GET",
      headers: options.headers || {},
    };

    const req = https.request(reqOptions, (res) => {
      const chunks = [];
      res.on("data", (chunk) => chunks.push(chunk));
      res.on("end", () => {
        const body = Buffer.concat(chunks).toString("utf-8");
        resolve({ status: res.statusCode, headers: res.headers, body });
      });
    });

    req.on("error", reject);

    if (options.body) {
      req.write(options.body);
    }
    req.end();
  });
}

async function jsonPost(url, data, headers = {}) {
  const body = typeof data === "string" ? data : JSON.stringify(data);
  const res = await httpRequest(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(body).toString(),
      ...headers,
    },
    body,
  });
  return { status: res.status, data: JSON.parse(res.body) };
}

async function jsonGet(url, headers = {}) {
  const res = await httpRequest(url, { headers });
  return { status: res.status, data: JSON.parse(res.body) };
}

// ─── Token management ────────────────────────────────────────────────────────

function loadTokens() {
  try {
    return JSON.parse(fs.readFileSync(TOKEN_FILE, "utf-8"));
  } catch {
    return null;
  }
}

function saveTokens(tokens) {
  fs.mkdirSync(TOKEN_DIR, { recursive: true });
  fs.writeFileSync(TOKEN_FILE, JSON.stringify(tokens, null, 2));
}

async function refreshAccessToken(refreshToken) {
  const body = new URLSearchParams({
    grant_type: "refresh_token",
    client_id: CLIENT_ID,
    refresh_token: refreshToken,
  }).toString();

  const res = await httpRequest(`${AUTH0_DOMAIN}/oauth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  const data = JSON.parse(res.body);
  if (res.status !== 200) {
    throw new Error(`Token refresh failed: ${data.error_description || data.error || res.status}`);
  }
  return data;
}

async function getAccessToken() {
  const tokens = loadTokens();
  if (!tokens) return null;

  const now = Date.now();
  if (tokens.expires_at && now < tokens.expires_at - 60_000) {
    return tokens.access_token;
  }

  if (tokens.refresh_token) {
    console.log("  Refreshing access token...");
    try {
      const refreshed = await refreshAccessToken(tokens.refresh_token);
      const updated = {
        access_token: refreshed.access_token,
        refresh_token: refreshed.refresh_token || tokens.refresh_token,
        expires_at: Date.now() + (refreshed.expires_in || 86400) * 1000,
      };
      saveTokens(updated);
      return updated.access_token;
    } catch (err) {
      console.error("  Token refresh failed:", err.message);
      return null;
    }
  }

  return null;
}

// ─── Browser Token Capture Login ─────────────────────────────────────────────

const TOKEN_EXTRACT_SCRIPT = `
(function() {
  for (let i = 0; i < localStorage.length; i++) {
    const key = localStorage.key(i);
    if (key.startsWith('@@auth0spajs@@')) {
      try {
        const data = JSON.parse(localStorage.getItem(key));
        const body = data.body;
        if (body && body.access_token) {
          return JSON.stringify({
            access_token: body.access_token,
            refresh_token: body.refresh_token || null,
            expires_in: body.expires_in || 86400
          });
        }
      } catch {}
    }
  }
  return null;
})();
`.trim().replace(/\n/g, " ");

async function browserTokenLogin() {
  console.log(`
  ┌──────────────────────────────────────────────────────────────┐
  │              Splice CLI — Token Capture Login                │
  ├──────────────────────────────────────────────────────────────┤
  │                                                              │
  │  1. Go to https://splice.com and log in normally             │
  │                                                              │
  │  2. Once logged in, open DevTools:                           │
  │     - Press F12 (or Ctrl+Shift+I)                            │
  │     - Click the "Console" tab                                │
  │                                                              │
  │  3. Paste this command and press Enter:                      │
  │                                                              │
  │     copy(JSON.stringify(Object.fromEntries(                  │
  │       Object.entries(localStorage).filter(                   │
  │         ([k]) => k.startsWith('@@auth0')                     │
  │       ).map(([k,v]) => [k, JSON.parse(v)])                  │
  │     )));                                                     │
  │                                                              │
  │  4. Paste the result below (it's in your clipboard)          │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘
`);

  try {
    const open = (await import("open")).default;
    await open("https://splice.com/sounds");
  } catch {}

  const raw = await prompt("  Paste token data here: ");

  if (!raw) {
    console.error("  No data provided.\n");
    process.exit(1);
  }

  try {
    const parsed = JSON.parse(raw);

    // Could be the full auth0 cache or a direct token object
    let accessToken = null;
    let refreshToken = null;
    let expiresIn = 86400;

    if (parsed.access_token) {
      accessToken = parsed.access_token;
      refreshToken = parsed.refresh_token;
      expiresIn = parsed.expires_in || 86400;
    } else {
      // Auth0 cache format: { "@@auth0spajs@@::...": { body: { access_token, ... } } }
      for (const key of Object.keys(parsed)) {
        const entry = parsed[key];
        if (entry?.body?.access_token) {
          accessToken = entry.body.access_token;
          refreshToken = entry.body.refresh_token;
          expiresIn = entry.body.expires_in || 86400;
          break;
        }
      }
    }

    if (!accessToken) {
      console.error("  Could not find access_token in the provided data.\n");
      console.error("  Try the simpler method: in the browser console, run:");
      console.error('    JSON.parse(localStorage.getItem(Object.keys(localStorage).find(k => k.startsWith("@@auth0")))).body.access_token');
      console.error("  Then use: splice-cli login --token <paste_token_here>\n");
      process.exit(1);
    }

    const tokens = {
      access_token: accessToken,
      refresh_token: refreshToken,
      expires_at: Date.now() + expiresIn * 1000,
    };
    saveTokens(tokens);
    console.log("  Authenticated successfully!\n");

    // Verify by fetching user info
    try {
      const { data } = await jsonGet(`${AUTH0_DOMAIN}/userinfo`, {
        Authorization: `Bearer ${accessToken}`,
      });
      if (data.email) console.log(`  Logged in as: ${data.email}\n`);
    } catch {}

    return accessToken;
  } catch (err) {
    console.error(`  Failed to parse token data: ${err.message}\n`);
    console.error("  Make sure you copied the full output from the browser console.\n");
    process.exit(1);
  }
}

async function directTokenLogin(token) {
  const tokens = {
    access_token: token,
    refresh_token: null,
    expires_at: Date.now() + 86400 * 1000,
  };
  saveTokens(tokens);
  console.log("\n  Token saved!\n");

  try {
    const { data } = await jsonGet(`${AUTH0_DOMAIN}/userinfo`, {
      Authorization: `Bearer ${token}`,
    });
    if (data.email) console.log(`  Logged in as: ${data.email}\n`);
    else console.log("  Token saved but could not verify identity.\n");
  } catch {
    console.log("  Token saved (could not verify — it may still work for API calls).\n");
  }

  return token;
}

// ─── Splice GraphQL API ─────────────────────────────────────────────────────

const SEARCH_QUERY = `query SamplesSearch(
  $query: String,
  $limit: Int = 20,
  $page: Int = 1,
  $sort: AssetSortType = relevance,
  $order: SortOrder = DESC,
  $tags: [ID!],
  $tags_exclude: [ID!],
  $key: String,
  $chord_type: String,
  $min_bpm: Int,
  $max_bpm: Int,
  $asset_category_slug: AssetCategorySlug,
  $parent_asset_uuid: GUID,
  $legacy: Boolean = true
) {
  assetsSearch(
    filter: {
      legacy: $legacy,
      published: true,
      asset_type_slug: sample,
      asset_category_slug: $asset_category_slug,
      query: $query,
      tag_ids: $tags,
      tag_ids_exclude: $tags_exclude,
      key: $key,
      chord_type: $chord_type,
      min_bpm: $min_bpm,
      max_bpm: $max_bpm
    }
    children: { parent_asset_uuid: $parent_asset_uuid }
    pagination: { page: $page, limit: $limit }
    sort: { sort: $sort, order: $order }
    legacy: { parent_asset_type: pack, use: $legacy }
  ) {
    items {
      ... on SampleAsset {
        uuid
        name
        bpm
        duration
        key
        chord_type
        asset_category_slug
      }
      ... on IAsset {
        uuid
        name
        licensed
        files {
          name
          path
          asset_file_type_slug
          url
        }
      }
      ... on IAssetChild {
        parents(filter: { asset_type_slug: pack }) {
          items {
            ... on PackAsset {
              uuid
              name
              permalink_slug
            }
          }
        }
      }
    }
    response_metadata { records }
    pagination_metadata { currentPage totalPages }
  }
}`;

const PURCHASE_MUTATION = `mutation PurchaseAssets($uuids: [GUID!]!, $legacy: Boolean = true) {
  purchaseAssets(uuids: $uuids, legacy: $legacy) {
    assetUuid
    purchased
    asset {
      ... on IAsset {
        uuid
        licensed
        asset_type_slug
        asset_type { label }
        __typename
      }
    }
  }
}`;

const SIMILAR_QUERY = `query SimilarSounds($uuid: GUID!) {
  similarSounds(uuid: $uuid) {
    uuid
    name
    bpm
    duration
    key
    chord_type
    asset_category_slug
    licensed
    files { name path asset_file_type_slug url }
    parents(filter: { asset_type_slug: pack }) {
      items { ... on PackAsset { uuid name permalink_slug } }
    }
  }
}`;

async function findSimilarSounds(uuid) {
  const headers = {};
  const token = await getAccessToken();
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await jsonPost(GRAPHQL_URL, {
    operationName: "SimilarSounds",
    query: SIMILAR_QUERY,
    variables: { uuid },
  }, headers);

  if (res.data.errors) {
    console.error("  GraphQL error:", res.data.errors[0].message);
    return [];
  }

  return res.data.data.similarSounds || [];
}

async function searchSounds(query, options = {}) {
  const variables = {
    query: query || "",
    limit: parseInt(options.limit) || 20,
    page: parseInt(options.page) || 1,
    sort: options.sort || "relevance",
    order: "DESC",
    tags: [],
    tags_exclude: [],
  };

  if (options.key) variables.key = options.key.toUpperCase().replace("♯", "#").replace("♭", "b");
  if (options.chord) variables.chord_type = options.chord;
  if (options.type) variables.asset_category_slug = options.type;

  // BPM: support exact (--bpm 128) or range (--bpm-min / --bpm-max)
  if (options.bpm) {
    const bpm = parseInt(options.bpm);
    variables.min_bpm = bpm;
    variables.max_bpm = bpm;
  } else {
    if (options["bpm-min"]) variables.min_bpm = parseInt(options["bpm-min"]);
    if (options["bpm-max"]) variables.max_bpm = parseInt(options["bpm-max"]);
  }

  // Resolve tag filters: --genre, --instrument, --tag (general)
  const tagNames = [];
  if (options.genre) tagNames.push(...options.genre.split(","));
  if (options.instrument) tagNames.push(...options.instrument.split(","));
  if (options.tag) tagNames.push(...options.tag.split(","));

  for (const name of tagNames) {
    const id = resolveTagId(name.trim());
    if (id) {
      variables.tags.push(id);
    } else {
      console.log(`  Warning: unknown tag "${name.trim()}". Use 'tags' command to see available tags.`);
    }
  }

  // Exclude tags
  if (options.exclude) {
    for (const name of options.exclude.split(",")) {
      const id = resolveTagId(name.trim());
      if (id) variables.tags_exclude.push(id);
    }
  }

  // Pack filter
  if (options.parentAssetUuid) {
    variables.parent_asset_uuid = options.parentAssetUuid;
  }

  const headers = {};
  const token = await getAccessToken();
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await jsonPost(GRAPHQL_URL, {
    operationName: "SamplesSearch",
    query: SEARCH_QUERY,
    variables,
  }, headers);

  if (res.data.errors) {
    console.error("  GraphQL error:", res.data.errors[0].message);
    return { items: [], response_metadata: { records: 0 }, pagination_metadata: { currentPage: 1, totalPages: 0 } };
  }

  return res.data.data.assetsSearch;
}

async function claimSounds(uuids) {
  const token = await getAccessToken();
  if (!token) {
    console.error("  Not authenticated. Run: splice-cli login");
    process.exit(1);
  }

  const { status, data } = await jsonPost(GRAPHQL_URL, {
    operationName: "PurchaseAssets",
    query: PURCHASE_MUTATION,
    variables: { uuids, legacy: true },
  }, {
    Authorization: `Bearer ${token}`,
  });

  if (data.errors) {
    console.error("  Claim failed:", data.errors[0].message);
    return null;
  }

  return data.data.purchaseAssets;
}

// ─── License verification (ETHICAL SAFEGUARD) ───────────────────────────────

const USER_QUERY = `query UserService {
  user {
    id
    uuid
    email
    username
    name
    extendedAttributes {
      credits
      sounds_plan
      sounds_state
    }
  }
}`;

async function getUserInfo(token) {
  const res = await jsonPost(GRAPHQL_URL, {
    operationName: "UserService",
    query: USER_QUERY,
    variables: {},
  }, { Authorization: `Bearer ${token}` });

  return res.data?.data?.user || null;
}

const LICENSE_CHECK_QUERY = `query CheckLicense($uuid: GUID!) {
  asset(uuid: $uuid, legacy: { type: sample }) {
    ... on IAsset {
      uuid
      name
      licensed
    }
  }
}`;

async function checkIfLicensed(uuid, token) {
  const res = await jsonPost(GRAPHQL_URL, {
    operationName: "CheckLicense",
    query: LICENSE_CHECK_QUERY,
    variables: { uuid },
  }, {
    Authorization: `Bearer ${token}`,
  });

  const asset = res.data?.data?.asset;
  return { licensed: asset?.licensed === true, name: asset?.name || uuid };
}

async function getDownloadUrl(uuid, { skipLicenseCheck = false } = {}) {
  const token = await getAccessToken();
  if (!token) {
    throw new Error("Not authenticated. Run: splice-cli login");
  }

  // ETHICAL SAFEGUARD: verify the sound is claimed before downloading
  if (!skipLicenseCheck) {
    const { licensed, name } = await checkIfLicensed(uuid, token);
    if (!licensed) {
      throw new Error(
        `BLOCKED: "${name}" is not claimed/licensed.\n` +
        `         You must claim it first: splice-cli claim ${uuid}\n` +
        `         Use 'preview' to listen before claiming (no credits spent).`
      );
    }
  }

  const { status, data } = await jsonGet(
    `${API_BASE}/v2/premium/samples/${uuid}`,
    { Authorization: `Bearer ${token}` }
  );

  if (status !== 200) {
    throw new Error(`Download URL request failed (${status}): ${JSON.stringify(data)}`);
  }

  return {
    url: data.sample?.url || data.url,
    path: data.sample?.path || data.path,
    filename: data.sample?.path
      ? data.sample.path.split("/").pop()
      : `${uuid}.wav`,
  };
}

async function downloadFile(url, outputPath) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const reqOptions = {
      hostname: parsed.hostname,
      port: 443,
      path: parsed.pathname + parsed.search,
      method: "GET",
    };

    const req = https.request(reqOptions, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        downloadFile(res.headers.location, outputPath).then(resolve).catch(reject);
        return;
      }

      const dir = path.dirname(outputPath);
      fs.mkdirSync(dir, { recursive: true });

      const fileStream = fs.createWriteStream(outputPath);
      let downloaded = 0;
      const total = parseInt(res.headers["content-length"] || "0");

      res.on("data", (chunk) => {
        downloaded += chunk.length;
        fileStream.write(chunk);
        if (total > 0) {
          const pct = Math.round((downloaded / total) * 100);
          process.stdout.write(`\r  Downloading: ${pct}% (${(downloaded / 1024).toFixed(0)} KB)`);
        }
      });

      res.on("end", () => {
        fileStream.end();
        console.log(`\r  Downloaded: ${outputPath}${"".padEnd(30)}`);
        resolve(outputPath);
      });
    });

    req.on("error", reject);
    req.end();
  });
}

// ─── Scrambled preview decoder (from splicedd) ──────────────────────────────

function decodeScrambledMp3(data) {
  const sizeData = Array.from(data.subarray(2, 10));
  let size = 0;
  for (let i = sizeData.length - 1; i >= 0; i--) {
    size = 256 * size + sizeData[i];
  }

  const encodingData = data.subarray(10, 28);
  const encodeBlkArr = [];
  for (let i = 0; i < encodingData.length; i += 32768) {
    encodeBlkArr.push(String.fromCharCode(...Array.from(encodingData.subarray(i, i + 32768))));
  }
  const encodeBlk = encodeBlkArr.join("");
  const audioData = data.slice(28);

  let passIdx = decodePass(0, audioData, encodeBlk, size) + size;
  decodePass(passIdx, audioData, encodeBlk, passIdx + size);
  return audioData;
}

function decodePass(i, arr, encodeBlk, size) {
  let idx = 0;
  for (; i < size; i++) {
    if (idx > encodeBlk.length - 1) idx = 0;
    if (i < size) arr[i] = arr[i] ^ encodeBlk.charCodeAt(idx);
    idx++;
  }
  return i;
}

async function downloadPreview(previewUrl, outputPath) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(previewUrl);
    const reqOptions = {
      hostname: parsed.hostname,
      port: 443,
      path: parsed.pathname + parsed.search,
      method: "GET",
    };

    const req = https.request(reqOptions, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        downloadPreview(res.headers.location, outputPath).then(resolve).catch(reject);
        return;
      }

      const chunks = [];
      res.on("data", (chunk) => chunks.push(chunk));
      res.on("end", () => {
        const raw = Buffer.concat(chunks);
        const decoded = decodeScrambledMp3(new Uint8Array(raw));
        const dir = path.dirname(outputPath);
        fs.mkdirSync(dir, { recursive: true });
        fs.writeFileSync(outputPath, decoded);
        console.log(`  Preview saved: ${outputPath}`);
        resolve(outputPath);
      });
    });

    req.on("error", reject);
    req.end();
  });
}

// ─── Audio playback ──────────────────────────────────────────────────────────

function playAudioFile(filePath) {
  return new Promise((resolve, reject) => {
    const proc = execFile("ffplay", ["-nodisp", "-autoexit", "-loglevel", "quiet", filePath], (err) => {
      if (err && err.code !== null) reject(err);
      else resolve();
    });
    proc.on("error", (err) => {
      if (err.code === "ENOENT") {
        reject(new Error("ffplay not found. Install FFmpeg to enable audio playback."));
      } else {
        reject(err);
      }
    });
  });
}

async function playPreview(uuid) {
  const sample = await getSampleDetail(uuid);
  if (!sample) throw new Error(`Sample not found: ${uuid}`);

  const previewFile = sample.files?.find((f) => f.asset_file_type_slug === "preview_mp3");
  if (!previewFile?.url) throw new Error(`No preview available for: ${uuid}`);

  const tmpDir = path.join(os.tmpdir(), "splice-cli");
  fs.mkdirSync(tmpDir, { recursive: true });
  const tmpFile = path.join(tmpDir, `${uuid}.mp3`);

  // Download + decode preview
  await new Promise((resolve, reject) => {
    const parsed = new URL(previewFile.url);
    const req = https.request({
      hostname: parsed.hostname, port: 443,
      path: parsed.pathname + parsed.search, method: "GET",
    }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        https.get(res.headers.location, (r2) => {
          const chunks = [];
          r2.on("data", (c) => chunks.push(c));
          r2.on("end", () => {
            const decoded = decodeScrambledMp3(new Uint8Array(Buffer.concat(chunks)));
            fs.writeFileSync(tmpFile, decoded);
            resolve();
          });
        }).on("error", reject);
        return;
      }
      const chunks = [];
      res.on("data", (c) => chunks.push(c));
      res.on("end", () => {
        const decoded = decodeScrambledMp3(new Uint8Array(Buffer.concat(chunks)));
        fs.writeFileSync(tmpFile, decoded);
        resolve();
      });
    });
    req.on("error", reject);
    req.end();
  });

  const shortName = sample.name?.split("/").pop() || uuid;
  console.log(`  Playing: ${shortName}`);
  await playAudioFile(tmpFile);

  try { fs.unlinkSync(tmpFile); } catch {}
  return sample;
}

// ─── CLI helpers ─────────────────────────────────────────────────────────────

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function prompt(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

function formatDuration(ms) {
  if (!ms || ms <= 0) return "";
  const totalMs = Math.round(ms);
  if (totalMs < 1000) return `${totalMs}ms`;
  const s = totalMs / 1000;
  if (s < 60) return `${s.toFixed(1)}s`;
  return `${Math.floor(s / 60)}m${Math.round(s % 60)}s`;
}

function sanitizeFilename(name) {
  return name.replace(/[<>:"/\\|?*]/g, "_").replace(/\s+/g, "_");
}

function printResults(results) {
  const items = results.items || [];
  const meta = results.response_metadata || {};
  const page = results.pagination_metadata || {};

  console.log(`\n  Found ${(meta.records || 0).toLocaleString()} results (page ${page.currentPage || 1}/${page.totalPages || 1})\n`);

  items.forEach((item, i) => {
    const num = String(i + 1).padStart(2);
    const name = item.name || "Unknown";
    const pack = item.parents?.items?.[0]?.name || "Unknown Pack";
    const bpm = item.bpm ? `${item.bpm} BPM` : "";
    const key = item.key ? `${item.key}${item.chord_type === "minor" ? "m" : item.chord_type === "major" ? "" : ""}` : "";
    const dur = item.duration ? formatDuration(item.duration) : "";
    const type = item.asset_category_slug || "";
    const licensed = item.licensed ? " [CLAIMED]" : "";
    const meta = [type, bpm, key, dur].filter(Boolean).join(" | ");

    console.log(`  ${num}. ${name}${licensed}`);
    console.log(`      Pack: ${pack}  ${meta ? `(${meta})` : ""}`);
    console.log(`      UUID: ${item.uuid}`);
    console.log();
  });
}

// ─── Commands ────────────────────────────────────────────────────────────────

async function cmdLogin(args = {}) {
  // Direct token paste: splice-cli login --token eyJ...
  if (args.token) {
    return directTokenLogin(args.token);
  }

  const existing = await getAccessToken();
  if (existing) {
    console.log("\n  Already authenticated. Use 'logout' to sign out first.\n");
    return;
  }

  await browserTokenLogin();
}

async function cmdLogout() {
  try {
    fs.unlinkSync(TOKEN_FILE);
    console.log("\n  Logged out. Tokens removed.\n");
  } catch {
    console.log("\n  Not logged in.\n");
  }
}

async function cmdSearch(args) {
  const query = args._.join(" ");
  if (!query && !args.genre && !args.instrument && !args.tag) {
    console.log(`
  Usage: search <query> [filters]

  Filters:
    --type oneshot|loop          Sample type
    --genre hip-hop              Genre tag (comma-separated for multiple)
    --instrument drums           Instrument tag (comma-separated)
    --tag foley,impacts          Any tag (genre, instrument, or attribute)
    --exclude vocals             Exclude tags
    --key C                      Musical key (C, C#, D, D#, E, F, F#, G, G#, A, A#, B)
    --chord major|minor          Chord type
    --bpm 128                    Exact BPM
    --bpm-min 120 --bpm-max 140  BPM range
    --sort relevance|popularity|recency|random
    --limit 20                   Results per page
    --page 2                     Page number

  Examples:
    search "dark pad" --type loop --genre ambient
    search "kick" --instrument drums --genre trap --type oneshot
    search "" --genre cinematic --tag foley --type oneshot
    search "piano" --key C --chord minor --bpm-min 60 --bpm-max 90

  Use 'tags' to see all available genre/instrument/attribute tags.
`);
    return;
  }

  console.log(`\n  Searching for "${query}"...`);
  const results = await searchSounds(query, {
    type: args.type,
    key: args.key,
    bpm: args.bpm,
    "bpm-min": args["bpm-min"],
    "bpm-max": args["bpm-max"],
    sort: args.sort,
    limit: args.limit,
    page: args.page,
    genre: args.genre,
    instrument: args.instrument,
    tag: args.tag,
    exclude: args.exclude,
    chord: args.chord,
  });

  printResults(results);
  return results;
}

async function cmdClaim(args) {
  const uuids = args._;
  if (uuids.length === 0) {
    console.log("\n  Usage: splice-cli claim <uuid> [uuid2] [uuid3] ...\n");
    console.log("  This spends credits from your Splice subscription.\n");
    return;
  }

  const token = await getAccessToken();
  if (!token) {
    console.log("\n  Not authenticated. Run: splice-cli login\n");
    return;
  }

  // Show credit balance before claiming
  const user = await getUserInfo(token);
  const currentCredits = user?.extendedAttributes?.credits ?? "?";
  const cost = uuids.length;

  console.log(`\n  Claiming ${cost} sound(s)...`);
  console.log(`  Current credits: ${typeof currentCredits === "number" ? currentCredits.toLocaleString() : currentCredits}`);
  console.log(`  Cost:            ${cost} credit(s)`);

  if (typeof currentCredits === "number" && cost > currentCredits) {
    console.log(`\n  Not enough credits! You need ${cost} but only have ${currentCredits}.\n`);
    return;
  }

  console.log(`  After:           ${typeof currentCredits === "number" ? (currentCredits - cost).toLocaleString() : "?"} credits remaining\n`);

  const confirm = await prompt(`  Spend ${cost} credit(s)? (y/n) `);
  if (confirm.toLowerCase() !== "y") {
    console.log("  Cancelled.\n");
    return;
  }

  const result = await claimSounds(uuids);
  if (result) {
    for (const item of result) {
      const status = item.purchased ? "Claimed" : "Already claimed";
      console.log(`  ${status}: ${item.assetUuid}`);
    }

    // Show updated balance
    const updatedUser = await getUserInfo(token);
    const newCredits = updatedUser?.extendedAttributes?.credits;
    if (newCredits != null) {
      console.log(`\n  Remaining credits: ${newCredits.toLocaleString()}`);
    }
    console.log();
  }
}

async function cmdDownload(args) {
  const uuids = args._;
  const outputDir = args.out || args.o || "./splice-downloads";

  if (uuids.length === 0) {
    console.log("\n  Usage: splice-cli download <uuid> [uuid2] ... [--out ./folder]\n");
    console.log("  Downloads full-quality WAV files. Sounds MUST be claimed first.\n");
    console.log("  Workflow: search → preview → claim → download\n");
    return;
  }

  const token = await getAccessToken();
  if (!token) {
    console.log("\n  Not authenticated. Run: splice-cli login\n");
    return;
  }

  console.log(`\n  Downloading ${uuids.length} sound(s) to ${outputDir}...`);
  console.log("  (License check enabled — only claimed sounds will download)\n");

  for (const uuid of uuids) {
    try {
      const dlInfo = await getDownloadUrl(uuid);

      if (!dlInfo.url) {
        console.error(`  No download URL for ${uuid}.`);
        continue;
      }

      const outputPath = path.join(outputDir, sanitizeFilename(dlInfo.filename));
      await downloadFile(dlInfo.url, outputPath);
    } catch (err) {
      console.error(`  ${err.message}\n`);
    }
  }
  console.log();
}

async function cmdPreview(args) {
  const uuids = args._;
  const outputDir = args.out || args.o || "./splice-previews";

  if (uuids.length === 0) {
    console.log("\n  Usage: splice-cli preview <uuid> [uuid2] ... [--out ./folder]\n");
    console.log("  Downloads decoded MP3 previews (no auth needed, no credits spent).\n");
    return;
  }

  console.log(`\n  Downloading ${uuids.length} preview(s) to ${outputDir}...\n`);

  for (const uuid of uuids) {
    try {
      const sample = await getSampleDetail(uuid);
      if (!sample) {
        console.error(`  Sample not found: ${uuid}`);
        continue;
      }

      const previewFile = sample.files?.find((f) => f.asset_file_type_slug === "preview_mp3");
      if (!previewFile?.url) {
        console.error(`  No preview available for: ${uuid}`);
        continue;
      }

      const filename = sanitizeFilename(sample.name || uuid) + ".mp3";
      await downloadPreview(previewFile.url, path.join(outputDir, filename));
    } catch (err) {
      console.error(`  Failed to preview ${uuid}: ${err.message}`);
    }
  }
  console.log();
}

async function cmdStatus() {
  const token = await getAccessToken();
  if (!token) {
    console.log("\n  Not authenticated. Run: splice-cli login\n");
    return;
  }

  console.log("\n  Authenticated with Splice.\n");

  try {
    const user = await getUserInfo(token);
    if (user) {
      console.log(`  Username: ${user.username}`);
      console.log(`  Email:    ${user.email}`);
      console.log(`  Name:     ${user.name}`);
      console.log(`  Credits:  ${user.extendedAttributes?.credits?.toLocaleString() ?? "unknown"}`);
      console.log(`  Plan:     ${user.extendedAttributes?.sounds_state || "unknown"}`);
    }
  } catch {
    console.log("  (Could not fetch user info)");
  }

  const tokens = loadTokens();
  if (tokens?.expires_at) {
    const remaining = tokens.expires_at - Date.now();
    if (remaining > 0) {
      console.log(`  Token:    expires in ${formatDuration(remaining)}`);
    } else {
      console.log("  Token:    expired (will auto-refresh)");
    }
  }
  console.log();
}

async function cmdPlay(args) {
  const uuids = args._;
  if (uuids.length === 0) {
    console.log("\n  Usage: splice-cli play <uuid> [uuid2] ...\n");
    console.log("  Plays preview audio in the terminal using ffplay (from FFmpeg).\n");
    console.log("  No credits spent — this plays the decoded preview MP3.\n");
    return;
  }

  for (const uuid of uuids) {
    try {
      await playPreview(uuid);
    } catch (err) {
      console.error(`  Failed to play ${uuid}: ${err.message}`);
    }
  }
  console.log();
}

const SAMPLE_DETAIL_QUERY = `query SampleDetail($uuid: GUID!) {
  asset(uuid: $uuid, legacy: { type: sample }) {
    ... on SampleAsset {
      uuid name bpm duration key chord_type asset_category_slug
      tags { uuid label }
    }
    ... on IAsset {
      uuid name licensed
      files { name path asset_file_type_slug url }
    }
    ... on IAssetChild {
      parents(filter: { asset_type_slug: pack }) {
        items { ... on PackAsset { uuid name permalink_slug } }
      }
    }
  }
}`;

async function getSampleDetail(uuid) {
  const headers = {};
  const token = await getAccessToken();
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await jsonPost(GRAPHQL_URL, {
    operationName: "SampleDetail",
    query: SAMPLE_DETAIL_QUERY,
    variables: { uuid },
  }, headers);

  return res.data?.data?.asset || null;
}

async function cmdSimilar(args) {
  const uuids = args._;
  if (uuids.length === 0) {
    console.log("\n  Usage: splice-cli similar <uuid>\n");
    console.log("  Finds sounds similar to the given sample.\n");
    return null;
  }

  const uuid = uuids[0];
  console.log(`\n  Finding sounds similar to ${uuid.substring(0, 12)}...`);

  // Try the native similar sounds endpoint first
  const similar = await findSimilarSounds(uuid);
  if (similar.length > 0) {
    console.log(`\n  Found ${similar.length} similar sound(s)\n`);

    similar.forEach((item, i) => {
      const num = String(i + 1).padStart(2);
      const name = item.name || "Unknown";
      const pack = item.parents?.items?.[0]?.name || "Unknown Pack";
      const bpm = item.bpm ? `${item.bpm} BPM` : "";
      const key = item.key ? `${item.key}${item.chord_type === "minor" ? "m" : item.chord_type === "major" ? "" : ""}` : "";
      const dur = item.duration ? formatDuration(item.duration) : "";
      const type = item.asset_category_slug || "";
      const licensed = item.licensed ? " [CLAIMED]" : "";
      const meta = [type, bpm, key, dur].filter(Boolean).join(" | ");

      console.log(`  ${num}. ${name}${licensed}`);
      console.log(`      Pack: ${pack}  ${meta ? `(${meta})` : ""}`);
      console.log(`      UUID: ${item.uuid}`);
      console.log();
    });

    return {
      items: similar,
      response_metadata: { records: similar.length },
      pagination_metadata: { currentPage: 1, totalPages: 1 },
    };
  }

  // Fallback: get the sample's metadata and search for similar attributes
  console.log("  Using attribute-based matching...");
  const detail = await getSampleDetail(uuid);
  if (!detail) {
    console.log("  Could not find sample details.\n");
    return null;
  }

  const searchOpts = {
    type: detail.asset_category_slug,
    limit: args.limit || "15",
  };

  if (detail.key) searchOpts.key = detail.key;
  if (detail.bpm) {
    searchOpts["bpm-min"] = String(Math.max(1, detail.bpm - 10));
    searchOpts["bpm-max"] = String(detail.bpm + 10);
  }

  // Tags from API use `label` field; categorize by matching against our lookup tables
  const sampleTags = detail.tags || [];
  const matchedGenres = [];
  const matchedInstruments = [];
  const matchedAttrs = [];

  for (const tag of sampleTags) {
    const slug = tag.label.toLowerCase().replace(/\s+/g, "-");
    if (GENRE_TAGS[slug]) matchedGenres.push(slug);
    else if (INSTRUMENT_TAGS[slug]) matchedInstruments.push(slug);
    else if (ATTRIBUTE_TAGS[slug]) matchedAttrs.push(slug);
  }

  if (matchedGenres.length > 0) searchOpts.genre = matchedGenres.join(",");
  if (matchedInstruments.length > 0) searchOpts.instrument = matchedInstruments.join(",");

  const shortName = detail.name?.split("/").pop() || uuid;
  const attrs = [];
  if (detail.asset_category_slug) attrs.push(detail.asset_category_slug);
  if (detail.key) attrs.push(`key: ${detail.key}`);
  if (detail.bpm) attrs.push(`~${detail.bpm} BPM`);
  if (matchedGenres.length) attrs.push(matchedGenres.join(", "));
  if (matchedInstruments.length) attrs.push(matchedInstruments.join(", "));
  console.log(`  Source: ${shortName} (${attrs.join(" | ")})`);

  const results = await searchSounds("", searchOpts);
  // Filter out the original sample
  results.items = (results.items || []).filter((item) => item.uuid !== uuid);

  printResults(results);
  return results;
}

async function cmdPack(args) {
  const input = args._;
  if (input.length === 0) {
    console.log("\n  Usage: splice-cli pack <sample-uuid|pack-uuid>\n");
    console.log("  Browse all samples in the same pack as the given sample.\n");
    console.log("  Optional filters: --type, --key, --bpm, --limit, --page\n");
    return null;
  }

  const uuid = input[0];
  let packUuid = uuid;
  let packName = uuid;

  // If it looks like a sample UUID (64-char hex), look up its pack
  if (uuid.length === 64) {
    console.log(`\n  Looking up pack for sample ${uuid.substring(0, 12)}...`);
    const detail = await getSampleDetail(uuid);
    if (!detail) {
      console.log("  Sample not found.\n");
      return null;
    }

    const parentPack = detail.parents?.items?.[0];
    if (!parentPack) {
      console.log("  Could not find parent pack for this sample.\n");
      return null;
    }

    packUuid = parentPack.uuid;
    packName = parentPack.name;
  }

  console.log(`\n  Browsing pack: ${packName}`);

  const results = await searchSounds(args.query || "", {
    parentAssetUuid: packUuid,
    type: args.type,
    key: args.key,
    bpm: args.bpm,
    "bpm-min": args["bpm-min"],
    "bpm-max": args["bpm-max"],
    sort: args.sort || "relevance",
    limit: args.limit || "20",
    page: args.page || "1",
  });

  printResults(results);
  return results;
}

async function cmdGrab(args) {
  const query = args._.join(" ");
  if (!query && !args.genre && !args.instrument && !args.tag) {
    console.log(`
  Usage: grab <query> [search filters]

  Batch workflow: search → select → play → claim → download

  Runs the full pipeline in one step:
    1. Search for sounds matching your query
    2. Pick which ones you want (by number)
    3. Optionally play previews
    4. Claim them (spends credits)
    5. Download full-quality WAVs

  Examples:
    grab "dark pad" --genre ambient --type loop
    grab "trap hi-hat" --bpm 140 --type oneshot
`);
    return;
  }

  const token = await getAccessToken();
  if (!token) {
    console.log("\n  Not authenticated. Run: splice-cli login\n");
    return;
  }

  // Step 1: Search
  console.log(`\n  [1/4] Searching for "${query}"...`);
  const results = await searchSounds(query, {
    type: args.type,
    key: args.key,
    bpm: args.bpm,
    "bpm-min": args["bpm-min"],
    "bpm-max": args["bpm-max"],
    sort: args.sort,
    limit: args.limit || "10",
    page: args.page,
    genre: args.genre,
    instrument: args.instrument,
    tag: args.tag,
    exclude: args.exclude,
  });

  if (!results.items?.length) {
    console.log("  No results found.\n");
    return;
  }

  printResults(results);

  // Step 2: Select
  const selection = await prompt("  Select sounds (e.g. 1,3,5 or 1-5 or 'all'): ");
  if (!selection) return;

  let indices = [];
  if (selection.toLowerCase() === "all") {
    indices = results.items.map((_, i) => i);
  } else {
    for (const part of selection.split(",")) {
      const trimmed = part.trim();
      if (trimmed.includes("-")) {
        const [start, end] = trimmed.split("-").map(Number);
        for (let i = start; i <= end; i++) indices.push(i - 1);
      } else {
        indices.push(parseInt(trimmed) - 1);
      }
    }
  }

  const selected = indices
    .filter((i) => i >= 0 && i < results.items.length)
    .map((i) => results.items[i]);

  if (selected.length === 0) {
    console.log("  No valid selections.\n");
    return;
  }

  console.log(`\n  Selected ${selected.length} sound(s).\n`);

  // Step 2.5: Optional preview playback
  const wantPreview = await prompt("  Play previews before claiming? (y/n) ");
  if (wantPreview.toLowerCase() === "y") {
    for (const item of selected) {
      try {
        await playPreview(item.uuid);
      } catch (err) {
        console.log(`  Could not play ${item.uuid.substring(0, 12)}: ${err.message}`);
      }
    }

    const proceed = await prompt("\n  Continue with claim + download? (y/n) ");
    if (proceed.toLowerCase() !== "y") {
      console.log("  Cancelled.\n");
      return;
    }
  }

  // Step 3: Claim (skip already claimed ones)
  const toClaim = selected.filter((s) => !s.licensed);
  if (toClaim.length > 0) {
    const user = await getUserInfo(token);
    const credits = user?.extendedAttributes?.credits ?? "?";

    console.log(`\n  [2/4] Claiming ${toClaim.length} sound(s)...`);
    console.log(`  Credits: ${typeof credits === "number" ? credits.toLocaleString() : credits}`);
    console.log(`  Cost:    ${toClaim.length} credit(s)\n`);

    if (typeof credits === "number" && toClaim.length > credits) {
      console.log(`  Not enough credits! Need ${toClaim.length}, have ${credits}.\n`);
      return;
    }

    const confirmClaim = await prompt(`  Spend ${toClaim.length} credit(s)? (y/n) `);
    if (confirmClaim.toLowerCase() !== "y") {
      console.log("  Cancelled.\n");
      return;
    }

    const claimResult = await claimSounds(toClaim.map((s) => s.uuid));
    if (!claimResult) {
      console.log("  Claim failed.\n");
      return;
    }

    for (const item of claimResult) {
      console.log(`  ${item.purchased ? "Claimed" : "Already claimed"}: ${item.assetUuid.substring(0, 12)}...`);
    }
  } else {
    console.log("\n  [2/4] All selected sounds already claimed.");
  }

  // Step 4: Download
  const outputDir = args.out || args.o || "./splice-downloads";
  console.log(`\n  [3/4] Downloading ${selected.length} sound(s) to ${outputDir}...`);

  for (const item of selected) {
    try {
      const dlInfo = await getDownloadUrl(item.uuid, { skipLicenseCheck: false });
      if (dlInfo.url) {
        const outputPath = path.join(outputDir, sanitizeFilename(dlInfo.filename));
        await downloadFile(dlInfo.url, outputPath);
      }
    } catch (err) {
      console.error(`  ${err.message}`);
    }
  }

  console.log("\n  [4/4] Done!\n");
}

async function cmdDiscover(args) {
  console.log("\n  Discovering random sounds...");

  const options = {
    sort: "random",
    limit: args.limit || "10",
    type: args.type,
    key: args.key,
    bpm: args.bpm,
    "bpm-min": args["bpm-min"],
    "bpm-max": args["bpm-max"],
    genre: args.genre,
    instrument: args.instrument,
    tag: args.tag,
    exclude: args.exclude,
  };

  const query = args._.join(" ");
  const results = await searchSounds(query, options);
  printResults(results);
  return results;
}

async function cmdInteractive() {
  console.log("\n  ╔════════════════════════════════════════════════════════════╗");
  console.log("  ║              Splice CLI — Mad Scientist Ed.              ║");
  console.log("  ╠════════════════════════════════════════════════════════════╣");
  console.log("  ║  Workflow: search → preview/play → claim → download      ║");
  console.log("  ╠════════════════════════════════════════════════════════════╣");
  console.log("  ║  search <query> [flags]  Search sounds (see 'search')    ║");
  console.log("  ║  play <#|uuid>           Play preview in terminal        ║");
  console.log("  ║  preview <#|uuid>        Save preview MP3 to disk       ║");
  console.log("  ║  similar <#|uuid>        Find similar sounds             ║");
  console.log("  ║  pack <#|uuid>           Browse all sounds in a pack     ║");
  console.log("  ║  claim <#|uuid> ...      License sound (spends credits)  ║");
  console.log("  ║  download <#|uuid>       Get WAV (must claim first!)     ║");
  console.log("  ║  grab <query> [flags]    Batch: search→claim→download    ║");
  console.log("  ║  discover [flags]        Random sound discovery          ║");
  console.log("  ║  tags                    List genre/instrument tags      ║");
  console.log("  ║  status                  Show auth & credit info         ║");
  console.log("  ║  login / logout          Manage authentication           ║");
  console.log("  ║  exit                    Quit                            ║");
  console.log("  ╚════════════════════════════════════════════════════════════╝\n");

  let lastResults = null;

  while (true) {
    const input = await prompt("  splice> ");
    if (!input) continue;

    const parts = input.match(/(?:[^\s"]+|"[^"]*")/g) || [];
    const cmd = parts[0]?.toLowerCase();
    const rest = parts.slice(1).map((s) => s.replace(/^"|"$/g, ""));

    const args = parseArgs(rest);

    try {
      switch (cmd) {
        case "login":
          await cmdLogin(args);
          break;
        case "logout":
          await cmdLogout();
          break;
        case "status":
        case "whoami":
          await cmdStatus();
          break;
        case "search":
        case "s":
          lastResults = await cmdSearch(args);
          break;
        case "claim":
        case "c":
          // Support "claim 1 2 3" using result indices
          if (lastResults && args._.length > 0 && args._[0].length < 4) {
            const resolved = args._.map((idx) => {
              const n = parseInt(idx) - 1;
              if (n >= 0 && n < (lastResults.items?.length || 0)) {
                return lastResults.items[n].uuid;
              }
              return idx;
            });
            args._ = resolved;
          }
          await cmdClaim(args);
          break;
        case "download":
        case "dl":
        case "d":
          if (lastResults && args._.length > 0 && args._[0].length < 4) {
            const resolved = args._.map((idx) => {
              const n = parseInt(idx) - 1;
              if (n >= 0 && n < (lastResults.items?.length || 0)) {
                return lastResults.items[n].uuid;
              }
              return idx;
            });
            args._ = resolved;
          }
          await cmdDownload(args);
          break;
        case "preview":
        case "p":
          if (lastResults && args._.length > 0 && args._[0].length < 4) {
            const resolved = args._.map((idx) => {
              const n = parseInt(idx) - 1;
              if (n >= 0 && n < (lastResults.items?.length || 0)) {
                return lastResults.items[n].uuid;
              }
              return idx;
            });
            args._ = resolved;
          }
          await cmdPreview(args);
          break;
        case "play":
          if (lastResults && args._.length > 0 && args._[0].length < 4) {
            const resolved = args._.map((idx) => {
              const n = parseInt(idx) - 1;
              if (n >= 0 && n < (lastResults.items?.length || 0)) {
                return lastResults.items[n].uuid;
              }
              return idx;
            });
            args._ = resolved;
          }
          await cmdPlay(args);
          break;
        case "similar":
        case "sim":
          if (lastResults && args._.length > 0 && args._[0].length < 4) {
            const n = parseInt(args._[0]) - 1;
            if (n >= 0 && n < (lastResults.items?.length || 0)) {
              args._[0] = lastResults.items[n].uuid;
            }
          }
          lastResults = await cmdSimilar(args);
          break;
        case "pack":
          if (lastResults && args._.length > 0 && args._[0].length < 4) {
            const n = parseInt(args._[0]) - 1;
            if (n >= 0 && n < (lastResults.items?.length || 0)) {
              args._[0] = lastResults.items[n].uuid;
            }
          }
          lastResults = await cmdPack(args);
          break;
        case "grab":
          lastResults = null;
          await cmdGrab(args);
          break;
        case "discover":
        case "random":
          lastResults = await cmdDiscover(args);
          break;
        case "exit":
        case "quit":
        case "q":
          console.log("\n  Bye!\n");
          process.exit(0);
        case "tags":
          listAvailableTags();
          break;
        case "help":
        case "?":
          console.log("\n  Commands: search, play, preview, similar, pack, claim, download, grab, discover, tags, status, login, logout, exit\n");
          break;
        default:
          console.log(`\n  Unknown command: ${cmd}. Type 'help' for commands.\n`);
      }
    } catch (err) {
      console.error(`\n  Error: ${err.message}\n`);
    }
  }
}

// ─── Arg parser ──────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith("--")) {
      const key = argv[i].slice(2);
      const next = argv[i + 1];
      if (next && !next.startsWith("--")) {
        args[key] = next;
        i++;
      } else {
        args[key] = true;
      }
    } else {
      args._.push(argv[i]);
    }
  }
  return args;
}

// ─── Entry point ─────────────────────────────────────────────────────────────

const argv = process.argv.slice(2);

if (argv.length === 0) {
  cmdInteractive();
} else {
  const cmd = argv[0];
  const args = parseArgs(argv.slice(1));

  switch (cmd) {
    case "login":
      cmdLogin(args);
      break;
    case "logout":
      cmdLogout();
      break;
    case "status":
      cmdStatus();
      break;
    case "search":
      cmdSearch(args);
      break;
    case "claim":
      cmdClaim(args);
      break;
    case "download":
      cmdDownload(args);
      break;
    case "preview":
      cmdPreview(args);
      break;
    case "play":
      cmdPlay(args);
      break;
    case "similar":
      cmdSimilar(args);
      break;
    case "pack":
      cmdPack(args);
      break;
    case "grab":
      cmdGrab(args);
      break;
    case "discover":
      cmdDiscover(args);
      break;
    case "tags":
      listAvailableTags();
      break;
    default:
      console.log(`Unknown command: ${cmd}`);
      console.log("Commands: search, play, preview, similar, pack, claim, download, grab, discover, tags, status, login, logout");
  }
}
