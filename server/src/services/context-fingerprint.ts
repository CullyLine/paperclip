import * as crypto from "node:crypto";
import * as fs from "node:fs/promises";
import * as path from "node:path";
import { eq } from "drizzle-orm";
import type { Db } from "@paperclipai/db";
import { agents } from "@paperclipai/db";

export interface ContextFingerprint {
  hash: string;
  components: Record<string, string>;
}

export interface FingerprintComparison {
  current: string;
  booted: string | null;
  stale: boolean;
  changedComponents: string[];
}

function hashString(s: string): string {
  return crypto.createHash("sha256").update(s, "utf8").digest("hex").slice(0, 16);
}

async function readFileSafe(filePath: string): Promise<string | null> {
  try {
    const resolved = path.isAbsolute(filePath)
      ? filePath
      : path.resolve(process.cwd(), filePath);
    return await fs.readFile(resolved, "utf8");
  } catch {
    return null;
  }
}

function asString(v: unknown, fallback = ""): string {
  return typeof v === "string" ? v : fallback;
}

function stableJsonHash(obj: unknown): string {
  return hashString(JSON.stringify(obj, Object.keys(obj as Record<string, unknown>).sort()));
}

/**
 * Compute a context fingerprint for an agent based on everything that defines
 * its operating context: prompts, skills, config, instructions.
 */
async function computeFingerprint(
  agent: typeof agents.$inferSelect,
): Promise<ContextFingerprint> {
  const config = (agent.adapterConfig ?? {}) as Record<string, unknown>;
  const components: Record<string, string> = {};

  const promptTemplate = asString(config.promptTemplate);
  if (promptTemplate) {
    components.promptTemplate = hashString(promptTemplate);
  }

  const bootstrapPromptTemplate = asString(config.bootstrapPromptTemplate);
  if (bootstrapPromptTemplate) {
    components.bootstrapPromptTemplate = hashString(bootstrapPromptTemplate);
  }

  const instructionsFilePath = asString(config.instructionsFilePath);
  if (instructionsFilePath) {
    const content = await readFileSafe(instructionsFilePath);
    if (content) {
      components.instructionsFile = hashString(content);
    }
  }

  const configSubset: Record<string, unknown> = {};
  for (const key of ["model", "adapter_type", "command", "mode", "extraArgs"]) {
    if (config[key] !== undefined) configSubset[key] = config[key];
  }
  if (Object.keys(configSubset).length > 0) {
    components.adapterConfig = stableJsonHash(configSubset);
  }

  components.adapterType = hashString(agent.adapterType);
  components.role = hashString(agent.role);
  if (agent.title) components.title = hashString(agent.title);

  const skillPaths = [
    path.resolve(process.cwd(), "skills", "paperclip", "SKILL.md"),
    path.resolve(process.cwd(), "skills", "paperclip", "references", "api-reference.md"),
  ];
  for (const sp of skillPaths) {
    const content = await readFileSafe(sp);
    if (content) {
      const relative = path.relative(process.cwd(), sp);
      components[`skill:${relative}`] = hashString(content);
    }
  }

  const combinedHash = hashString(
    Object.entries(components)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([k, v]) => `${k}=${v}`)
      .join("\n"),
  );

  return { hash: combinedHash, components };
}

export function contextFingerprintService(db: Db) {
  async function getFingerprint(agentId: string): Promise<ContextFingerprint | null> {
    const rows = await db
      .select()
      .from(agents)
      .where(eq(agents.id, agentId));
    const agent = rows[0] ?? null;
    if (!agent) return null;
    return computeFingerprint(agent);
  }

  async function compareFingerprint(agentId: string): Promise<FingerprintComparison | null> {
    const rows = await db
      .select()
      .from(agents)
      .where(eq(agents.id, agentId));
    const agent = rows[0] ?? null;
    if (!agent) return null;

    const current = await computeFingerprint(agent);
    const booted = agent.lastBootedContextFingerprint;
    const stale = booted !== null && booted !== current.hash;

    const changedComponents: string[] = [];
    if (stale && booted) {
      for (const [key] of Object.entries(current.components)) {
        changedComponents.push(key);
      }
    }

    return {
      current: current.hash,
      booted,
      stale,
      changedComponents: stale ? changedComponents : [],
    };
  }

  async function stampFingerprint(agentId: string): Promise<string | null> {
    const fp = await getFingerprint(agentId);
    if (!fp) return null;
    await db
      .update(agents)
      .set({
        lastBootedContextFingerprint: fp.hash,
        rebootPending: false,
        updatedAt: new Date(),
      })
      .where(eq(agents.id, agentId));
    return fp.hash;
  }

  async function markRebootPending(agentId: string): Promise<void> {
    await db
      .update(agents)
      .set({ rebootPending: true, updatedAt: new Date() })
      .where(eq(agents.id, agentId));
  }

  async function clearRebootPending(agentId: string): Promise<void> {
    await db
      .update(agents)
      .set({ rebootPending: false, updatedAt: new Date() })
      .where(eq(agents.id, agentId));
  }

  return {
    getFingerprint,
    compareFingerprint,
    stampFingerprint,
    markRebootPending,
    clearRebootPending,
    computeFingerprint,
  };
}
