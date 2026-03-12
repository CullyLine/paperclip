#!/usr/bin/env node
// Builds DialoguePro.rbxmx and uploads it to Roblox Creator Store
// as a Model via the Open Cloud Assets API.
//
// Usage:
//   set ROBLOX_OPEN_CLOUD_KEY=<your-key>
//   node upload-model.cjs
//
// Optional env:
//   ROBLOX_ASSET_ID  — if set, updates an existing asset instead of creating new

const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const https = require("https");

const DIR = __dirname;
const MODEL_PATH = path.join(DIR, "DialoguePro.rbxmx");
const ROBLOX_USER_ID = "8602450";

const DISPLAY_NAME = "DialoguePro \u2014 NPC Dialogue System";
const DESCRIPTION = [
  "Production-ready branching NPC dialogue system for RPGs, horror, adventure, and more.",
  "",
  "FREE COMPANION PLUGIN: Dialogue Designer \u2014 visual node editor in Studio. Drag, connect, and build dialogue trees with no code. One-click export.",
  "",
  "FEATURES:",
  "\u2022 Unlimited branching with conditions (gold, level, quest flags, any state)",
  "\u2022 Simple text format \u2014 writers author dialogue with zero Lua knowledge",
  "\u2022 Variable interpolation: {playerName}, {gold} in dialogue text",
  "\u2022 5 themes (Dark, Fantasy, Sci-Fi, Bubblegum, Horror) + full customization",
  "\u2022 Auto-viewport NPC portraits \u2014 renders 3D model automatically",
  "\u2022 Auto-advance nodes for cutscene sequences",
  "\u2022 Typewriter with [pause] and [speed] for dramatic pacing",
  "\u2022 [set] and [call] actions \u2014 dialogue drives game logic directly",
  "\u2022 Keyboard, gamepad, and touch input",
  "\u2022 ProximityPrompt integration",
  "",
  "INCLUDED:",
  "\u2022 5 fully commented ModuleScripts",
  "\u2022 Beginner example script",
  "\u2022 Complete documentation",
  "\u2022 Lifetime updates",
  "",
  'Try the full demo with "Try in Studio" before buying!',
].join("\n");

function httpsRequest(options, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      const chunks = [];
      res.on("data", (c) => chunks.push(c));
      res.on("end", () => {
        const raw = Buffer.concat(chunks).toString();
        try {
          resolve({ status: res.statusCode, headers: res.headers, body: JSON.parse(raw) });
        } catch {
          resolve({ status: res.statusCode, headers: res.headers, body: raw });
        }
      });
    });
    req.on("error", reject);
    if (body) req.write(body);
    req.end();
  });
}

function buildMultipartBody(apiKey, fileBuffer) {
  const boundary = "----RobloxUpload" + Date.now();
  const requestJson = JSON.stringify({
    assetType: "Model",
    displayName: DISPLAY_NAME,
    description: DESCRIPTION,
    creationContext: {
      creator: { userId: ROBLOX_USER_ID },
    },
  });

  const parts = [];

  parts.push(
    `--${boundary}\r\n` +
    `Content-Disposition: form-data; name="request"\r\n` +
    `Content-Type: application/json\r\n\r\n` +
    requestJson + "\r\n"
  );

  parts.push(
    `--${boundary}\r\n` +
    `Content-Disposition: form-data; name="fileContent"; filename="DialoguePro.rbxmx"\r\n` +
    `Content-Type: application/xml\r\n\r\n`
  );

  const head = Buffer.from(parts[0] + parts[1], "utf8");
  const tail = Buffer.from(`\r\n--${boundary}--\r\n`, "utf8");
  const body = Buffer.concat([head, fileBuffer, tail]);

  return { boundary, body };
}

function buildUpdateMultipartBody(fileBuffer) {
  const boundary = "----RobloxUpload" + Date.now();
  const requestJson = JSON.stringify({
    assetType: "Model",
    displayName: DISPLAY_NAME,
    description: DESCRIPTION,
  });

  const parts = [];

  parts.push(
    `--${boundary}\r\n` +
    `Content-Disposition: form-data; name="request"\r\n` +
    `Content-Type: application/json\r\n\r\n` +
    requestJson + "\r\n"
  );

  parts.push(
    `--${boundary}\r\n` +
    `Content-Disposition: form-data; name="fileContent"; filename="DialoguePro.rbxmx"\r\n` +
    `Content-Type: application/xml\r\n\r\n`
  );

  const head = Buffer.from(parts[0] + parts[1], "utf8");
  const tail = Buffer.from(`\r\n--${boundary}--\r\n`, "utf8");
  const body = Buffer.concat([head, fileBuffer, tail]);

  return { boundary, body };
}

async function pollOperation(apiKey, operationPath) {
  const maxAttempts = 20;
  const delayMs = 3000;

  for (let i = 0; i < maxAttempts; i++) {
    await new Promise((r) => setTimeout(r, delayMs));

    const opPath = operationPath.startsWith("/") ? operationPath : `/${operationPath}`;
    const res = await httpsRequest({
      hostname: "apis.roblox.com",
      path: `/assets/v1${opPath}`,
      method: "GET",
      headers: { "x-api-key": apiKey },
    });

    if (res.status !== 200) {
      console.log(`  Poll attempt ${i + 1}: HTTP ${res.status}`);
      continue;
    }

    if (res.body.done) {
      return res.body;
    }

    console.log(`  Poll attempt ${i + 1}: not yet complete...`);
  }

  throw new Error("Operation did not complete within polling window");
}

async function main() {
  const apiKey = process.env.ROBLOX_OPEN_CLOUD_KEY;
  if (!apiKey) {
    console.error("ERROR: ROBLOX_OPEN_CLOUD_KEY environment variable is not set.\n");
    console.error("Set it before running:");
    console.error("  PowerShell:  $env:ROBLOX_OPEN_CLOUD_KEY = 'your-key-here'");
    console.error("  Bash:        export ROBLOX_OPEN_CLOUD_KEY='your-key-here'");
    process.exit(1);
  }

  const existingAssetId = process.env.ROBLOX_ASSET_ID;

  // Step 1: Build the model
  console.log("Step 1: Building DialoguePro.rbxmx...");
  execSync("node build-model.cjs", { cwd: DIR, stdio: "inherit" });

  if (!fs.existsSync(MODEL_PATH)) {
    console.error(`ERROR: Build did not produce ${MODEL_PATH}`);
    process.exit(1);
  }

  const fileBuffer = fs.readFileSync(MODEL_PATH);
  const sizeKB = (fileBuffer.length / 1024).toFixed(1);
  console.log(`\nModel file: ${sizeKB} KB`);

  if (existingAssetId) {
    // Step 2: Update existing asset
    console.log(`\nStep 2: Updating existing asset ${existingAssetId}...`);
    const { boundary, body } = buildUpdateMultipartBody(fileBuffer);

    const res = await httpsRequest({
      hostname: "apis.roblox.com",
      path: `/assets/v1/assets/${existingAssetId}`,
      method: "PATCH",
      headers: {
        "x-api-key": apiKey,
        "Content-Type": `multipart/form-data; boundary=${boundary}`,
        "Content-Length": body.length,
      },
    }, body);

    if (res.status !== 200) {
      console.error(`\nERROR: Roblox API returned HTTP ${res.status}`);
      console.error(JSON.stringify(res.body, null, 2));
      process.exit(1);
    }

    console.log("\nUpdate submitted. Polling for completion...");
    const op = res.body;

    if (op.done) {
      console.log("\nAsset updated successfully!");
      if (op.response) {
        const assetId = op.response.assetId;
        console.log(`  Asset ID: ${assetId}`);
        console.log(`  URL: https://create.roblox.com/store/asset/${assetId}`);
      }
    } else if (op.path) {
      const result = await pollOperation(apiKey, op.path);
      console.log("\nAsset updated successfully!");
      if (result.response) {
        const assetId = result.response.assetId;
        console.log(`  Asset ID: ${assetId}`);
        console.log(`  URL: https://create.roblox.com/store/asset/${assetId}`);
      }
    }
  } else {
    // Step 2: Create new asset
    console.log("\nStep 2: Uploading to Roblox Creator Store...");
    const { boundary, body } = buildMultipartBody(apiKey, fileBuffer);

    const res = await httpsRequest({
      hostname: "apis.roblox.com",
      path: "/assets/v1/assets",
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "Content-Type": `multipart/form-data; boundary=${boundary}`,
        "Content-Length": body.length,
      },
    }, body);

    if (res.status !== 200 && res.status !== 201) {
      console.error(`\nERROR: Roblox API returned HTTP ${res.status}`);
      console.error(JSON.stringify(res.body, null, 2));
      process.exit(1);
    }

    console.log("\nUpload submitted. Polling for completion...");
    const op = res.body;

    if (op.done) {
      console.log("\nAsset created successfully!");
      if (op.response) {
        const assetId = op.response.assetId;
        console.log(`  Asset ID: ${assetId}`);
        console.log(`  URL: https://create.roblox.com/store/asset/${assetId}`);
        console.log(`\nTo update this asset in the future, set:`);
        console.log(`  $env:ROBLOX_ASSET_ID = "${assetId}"`);
      }
    } else if (op.path) {
      const result = await pollOperation(apiKey, op.path);
      console.log("\nAsset created successfully!");
      if (result.response) {
        const assetId = result.response.assetId;
        console.log(`  Asset ID: ${assetId}`);
        console.log(`  URL: https://create.roblox.com/store/asset/${assetId}`);
        console.log(`\nTo update this asset in the future, set:`);
        console.log(`  $env:ROBLOX_ASSET_ID = "${assetId}"`);
      }
    } else {
      console.log("\nResponse:", JSON.stringify(op, null, 2));
    }
  }
}

main().catch((err) => {
  console.error("Fatal error:", err.message);
  process.exit(1);
});
