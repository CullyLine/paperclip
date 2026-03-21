import { Client, GatewayIntentBits, EmbedBuilder, ActionRowBuilder, ButtonBuilder, ButtonStyle, ModalBuilder, TextInputBuilder, TextInputStyle, StringSelectMenuBuilder, Events } from "discord.js";
import WebSocket from "ws";
import { readFileSync, writeFileSync, existsSync, unlinkSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

// Kill any previous bot instance via PID file
const PID_FILE = resolve(__dirname, ".bot.pid");
if (existsSync(PID_FILE)) {
  try {
    const oldPid = parseInt(readFileSync(PID_FILE, "utf8").trim(), 10);
    if (oldPid && oldPid !== process.pid) {
      process.kill(oldPid);
      console.log(`[startup] Killed previous bot instance (PID ${oldPid})`);
    }
  } catch {}
}
writeFileSync(PID_FILE, String(process.pid));
process.on("exit", () => { try { unlinkSync(PID_FILE); } catch {} });

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

function loadEnv() {
  const envPath = resolve(__dirname, ".env");
  if (!existsSync(envPath)) return;
  const lines = readFileSync(envPath, "utf-8").split("\n");
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eqIdx = trimmed.indexOf("=");
    if (eqIdx < 0) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const value = trimmed.slice(eqIdx + 1).trim();
    if (!process.env[key]) process.env[key] = value;
  }
}

loadEnv();

const DISCORD_BOT_TOKEN = process.env.DISCORD_BOT_TOKEN;
const ISSUE_CHANNEL_ID = process.env.DISCORD_ISSUE_CHANNEL_ID;
const APPROVALS_CHANNEL_ID = process.env.DISCORD_APPROVALS_CHANNEL_ID;
const ADMIN_CHANNEL_ID = process.env.DISCORD_ADMIN_CHANNEL_ID;
const API_URL = process.env.PAPERCLIP_API_URL || "http://localhost:3100";
const COMPANY_ID = process.env.PAPERCLIP_COMPANY_ID;

if (!DISCORD_BOT_TOKEN) { console.error("DISCORD_BOT_TOKEN is required"); process.exit(1); }
if (!ISSUE_CHANNEL_ID) { console.error("DISCORD_ISSUE_CHANNEL_ID is required"); process.exit(1); }
if (!APPROVALS_CHANNEL_ID) { console.error("DISCORD_APPROVALS_CHANNEL_ID is required"); process.exit(1); }
if (!ADMIN_CHANNEL_ID) { console.error("DISCORD_ADMIN_CHANNEL_ID is required"); process.exit(1); }
if (!COMPANY_ID) { console.error("PAPERCLIP_COMPANY_ID is required"); process.exit(1); }

// ---------------------------------------------------------------------------
// Caches
// ---------------------------------------------------------------------------

let agentCache = new Map();
let projectCache = new Map();
let lastCacheRefresh = 0;
const CACHE_TTL = 10 * 60 * 1000;

async function apiFetch(path) {
  const res = await fetch(`${API_URL}/api${path}`);
  if (!res.ok) throw new Error(`API ${res.status}: ${path}`);
  return res.json();
}

async function refreshCaches() {
  if (Date.now() - lastCacheRefresh < CACHE_TTL) return;
  try {
    const agents = await apiFetch(`/companies/${COMPANY_ID}/agents`);
    agentCache = new Map(agents.map(a => [a.id, a]));

    const projects = await apiFetch(`/companies/${COMPANY_ID}/projects`);
    projectCache = new Map(projects.map(p => [p.id, p]));

    lastCacheRefresh = Date.now();
    console.log(`[cache] Refreshed: ${agentCache.size} agents, ${projectCache.size} projects`);
  } catch (err) {
    console.error("[cache] Failed to refresh:", err.message);
  }
}

function actorName(actorType, actorId) {
  if (actorType === "agent") {
    const agent = agentCache.get(actorId);
    return agent ? agent.name : `Agent ${actorId.slice(0, 8)}`;
  }
  if (actorType === "user") return "Board";
  return actorType || "System";
}

// ---------------------------------------------------------------------------
// Discord client
// ---------------------------------------------------------------------------

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
  ],
});

let issueChannel = null;
let approvalsChannel = null;
let adminChannel = null;

client.once(Events.ClientReady, async (c) => {
  console.log(`[discord] Logged in as ${c.user.tag}`);
  try {
    issueChannel = await client.channels.fetch(ISSUE_CHANNEL_ID);
    console.log(`[discord] Issue channel: #${issueChannel.name}`);
  } catch (err) {
    console.error(`[discord] Could not access issue channel ${ISSUE_CHANNEL_ID}: ${err.message}`);
    console.error("[discord] Make sure the bot has been invited to your server and can see that channel.");
  }
  try {
    approvalsChannel = await client.channels.fetch(APPROVALS_CHANNEL_ID);
    console.log(`[discord] Approvals channel: #${approvalsChannel.name}`);
  } catch (err) {
    console.error(`[discord] Could not access approvals channel ${APPROVALS_CHANNEL_ID}: ${err.message}`);
    console.error("[discord] Make sure the bot has been invited to your server and can see that channel.");
  }
  try {
    adminChannel = await client.channels.fetch(ADMIN_CHANNEL_ID);
    console.log(`[discord] Admin channel: #${adminChannel.name}`);
    await sendAdminPanel();
    const sgOnBoot = await getCeoSelfGovData();
    if (sgOnBoot?.expiresAt && new Date(sgOnBoot.expiresAt).getTime() > Date.now()) {
      console.log("[sg] Self-governing already active on boot — starting watcher");
      startSgWatcher();
    }
  } catch (err) {
    console.error(`[discord] Could not access admin channel ${ADMIN_CHANNEL_ID}: ${err.message}`);
    console.error("[discord] Make sure the bot has been invited to your server and can see that channel.");
  }
});

// ---------------------------------------------------------------------------
// Event handlers
// ---------------------------------------------------------------------------

const PRIORITY_COLORS = {
  critical: 0xef4444,
  high: 0xf97316,
  medium: 0xeab308,
  low: 0x6b7280,
};

async function handleIssueCreated(payload) {
  if (!issueChannel) return;
  const { actorType, actorId, entityId, details } = payload;
  const creator = actorName(actorType, actorId);
  const title = details?.title || "Untitled";
  const identifier = details?.identifier || entityId.slice(0, 8);

  let issue = null;
  try {
    issue = await apiFetch(`/issues/${entityId}`);
  } catch { /* use details only */ }

  const description = issue?.description
    ? issue.description.length > 4000 ? issue.description.slice(0, 4000) + "…" : issue.description
    : null;

  const project = issue?.projectId ? projectCache.get(issue.projectId) : null;
  const priority = issue?.priority || "medium";
  const assignee = issue?.assigneeAgentId ? actorName("agent", issue.assigneeAgentId) : null;

  const embed = new EmbedBuilder()
    .setColor(PRIORITY_COLORS[priority] || 0x6b7280)
    .setTitle(`${identifier} — ${title}`)
    .setDescription(description || "*No description*")
    .addFields(
      { name: "Created by", value: creator, inline: true },
      { name: "Priority", value: priority, inline: true },
    )
    .setTimestamp();

  if (project) embed.addFields({ name: "Project", value: project.name, inline: true });
  if (assignee) embed.addFields({ name: "Assigned to", value: assignee, inline: true });

  await issueChannel.send({ embeds: [embed] });
}

async function handleIssueComment(payload) {
  if (!issueChannel) return;
  const { actorType, actorId, entityId, details } = payload;
  const commenter = actorName(actorType, actorId);
  const issueTitle = details?.issueTitle || "Unknown issue";
  const identifier = details?.identifier || entityId.slice(0, 8);
  const bodySnippet = details?.bodySnippet || "";

  let fullBody = bodySnippet;
  if (details?.commentId) {
    try {
      const comment = await apiFetch(`/issues/${entityId}/comments/${details.commentId}`);
      fullBody = comment.body || bodySnippet;
    } catch { /* use snippet */ }
  }

  const displayBody = fullBody.length > 4000 ? fullBody.slice(0, 4000) + "…" : fullBody;

  const embed = new EmbedBuilder()
    .setColor(0x3b82f6)
    .setTitle(`💬 Comment on ${identifier} — ${issueTitle}`)
    .setDescription(displayBody || "*Empty comment*")
    .addFields({ name: "By", value: commenter, inline: true })
    .setTimestamp();

  await issueChannel.send({ embeds: [embed] });
}

async function handleApprovalCreated(payload) {
  if (!approvalsChannel) return;
  const { actorType, actorId, entityId, details } = payload;
  const requester = actorName(actorType, actorId);

  let approval = null;
  try {
    approval = await apiFetch(`/approvals/${entityId}`);
  } catch (err) {
    console.error("[approval] Failed to fetch:", err.message);
    return;
  }

  const typeLabels = {
    hire_agent: "Hire Agent",
    approve_ceo_strategy: "CEO Strategy",
    budget_override_required: "Budget Override",
  };

  const approvalType = typeLabels[approval.type] || approval.type;
  const approvalPayload = approval.payload || {};

  let description = `**Type:** ${approvalType}\n**Requested by:** ${requester}`;

  if (approvalPayload.name) description += `\n**Agent name:** ${approvalPayload.name}`;
  if (approvalPayload.role) description += `\n**Role:** ${approvalPayload.role}`;
  if (approvalPayload.title) description += `\n**Title:** ${approvalPayload.title}`;
  if (approvalPayload.reason) description += `\n\n${approvalPayload.reason}`;

  let linkedIssues = [];
  try {
    linkedIssues = await apiFetch(`/approvals/${entityId}/issues`);
  } catch { /* ignore */ }

  if (linkedIssues.length > 0) {
    const issueList = linkedIssues.map(i => `• ${i.identifier || i.id.slice(0, 8)} — ${i.title}`).join("\n");
    description += `\n\n**Linked issues:**\n${issueList}`;
  }

  const embed = new EmbedBuilder()
    .setColor(0xf59e0b)
    .setTitle(`🔔 Approval Required — ${approvalType}`)
    .setDescription(description)
    .setFooter({ text: `Approval ID: ${entityId}` })
    .setTimestamp();

  const row = new ActionRowBuilder().addComponents(
    new ButtonBuilder()
      .setCustomId(`approve:${entityId}`)
      .setLabel("Approve")
      .setStyle(ButtonStyle.Success),
    new ButtonBuilder()
      .setCustomId(`reject:${entityId}`)
      .setLabel("Deny")
      .setStyle(ButtonStyle.Danger),
  );

  await approvalsChannel.send({ embeds: [embed], components: [row] });
}

// ---------------------------------------------------------------------------
// Button interactions (approve / deny)
// ---------------------------------------------------------------------------

client.on(Events.InteractionCreate, async (interaction) => {
  if (!interaction.isButton()) return;

  const [action, approvalId] = interaction.customId.split(":");
  if (!action || !approvalId) return;
  if (action !== "approve" && action !== "reject") return;

  await interaction.deferUpdate();

  const endpoint = action === "approve" ? "approve" : "reject";
  const label = action === "approve" ? "Approved" : "Denied";
  const color = action === "approve" ? 0x22c55e : 0xef4444;

  try {
    const res = await fetch(`${API_URL}/api/approvals/${approvalId}/${endpoint}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ decisionNote: `${label} via Discord by ${interaction.user.tag}` }),
    });

    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.error || `HTTP ${res.status}`);
    }

    const embed = EmbedBuilder.from(interaction.message.embeds[0])
      .setColor(color)
      .setTitle(`${action === "approve" ? "✅" : "❌"} ${label}`)
      .addFields({ name: "Decision by", value: interaction.user.tag, inline: true });

    const disabledRow = new ActionRowBuilder().addComponents(
      new ButtonBuilder()
        .setCustomId("approve:done")
        .setLabel("Approve")
        .setStyle(ButtonStyle.Success)
        .setDisabled(true),
      new ButtonBuilder()
        .setCustomId("reject:done")
        .setLabel("Deny")
        .setStyle(ButtonStyle.Danger)
        .setDisabled(true),
    );

    await interaction.editReply({ embeds: [embed], components: [disabledRow] });
    console.log(`[approval] ${approvalId} ${label} by ${interaction.user.tag}`);
  } catch (err) {
    console.error(`[approval] Failed to ${action}:`, err.message);
    try {
      await interaction.followUp({ content: `Failed to ${action}: ${err.message}`, ephemeral: true });
    } catch { /* give up */ }
  }
});

// ---------------------------------------------------------------------------
// Admin channel — control panel + text commands
// ---------------------------------------------------------------------------

async function getAgentStatuses() {
  await refreshCaches();
  const agents = [...agentCache.values()].filter(a => a.status !== "terminated");
  const running = agents.filter(a => a.status === "running" || a.status === "active");
  const paused = agents.filter(a => a.status === "paused");
  const idle = agents.filter(a => a.status === "idle");
  return { agents, running, paused, idle };
}

function buildStatusLines(agents) {
  const icons = { running: "🟢", active: "🟢", idle: "🟡", paused: "🔴" };
  return agents.map(a => `${icons[a.status] || "⚪"} **${a.name}** — ${a.status}`).join("\n");
}

const CEO_ID = "3fb10555-e10d-4f07-bf53-ce650210ce0a";
const OWNER_DISCORD_ID = "165611171016081408";
let sgWatchInterval = null;
let lastKnownSgActive = false;

async function getCeoSelfGovData() {
  try {
    const ceo = await apiFetch(`/agents/${CEO_ID}`);
    return ceo?.metadata?.selfGoverning ?? null;
  } catch { return null; }
}

function formatRemaining(expiresAt) {
  const ms = Math.max(0, new Date(expiresAt).getTime() - Date.now());
  if (ms <= 0) return "Expired";
  const h = Math.floor(ms / 3600000);
  const m = Math.floor((ms % 3600000) / 60000);
  const s = Math.floor((ms % 60000) / 1000);
  return `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
}

let adminPanelMessage = null;

async function sendAdminPanel() {
  if (!adminChannel) return;
  const { agents, running, paused, idle } = await getAgentStatuses();
  const allPaused = agents.every(a => a.status === "paused");
  const sg = await getCeoSelfGovData();
  const sgActive = sg?.expiresAt && new Date(sg.expiresAt).getTime() > Date.now();

  const embed = new EmbedBuilder()
    .setColor(allPaused ? 0xef4444 : 0x22c55e)
    .setTitle("🎛️ Paperclip Control Panel")
    .setDescription(buildStatusLines(agents) || "*No agents*")
    .addFields(
      { name: "Running", value: `${running.length}`, inline: true },
      { name: "Idle", value: `${idle.length}`, inline: true },
      { name: "Paused", value: `${paused.length}`, inline: true },
    )
    .setFooter({ text: "STOP · START · WAKE · STATUS · GOVERN <hours> <goal>" })
    .setTimestamp();

  const agentRow = new ActionRowBuilder().addComponents(
    new ButtonBuilder()
      .setCustomId("admin:pause_all")
      .setLabel("⏸ Pause All")
      .setStyle(ButtonStyle.Danger),
    new ButtonBuilder()
      .setCustomId("admin:resume_all")
      .setLabel("▶ Resume All")
      .setStyle(ButtonStyle.Success),
    new ButtonBuilder()
      .setCustomId("admin:wake_ceo")
      .setLabel("⚡ Wake CEO")
      .setStyle(ButtonStyle.Primary),
    new ButtonBuilder()
      .setCustomId("admin:refresh")
      .setLabel("🔄 Refresh")
      .setStyle(ButtonStyle.Secondary),
  );

  const helpEmbed = new EmbedBuilder()
    .setColor(0x3b82f6)
    .setTitle("📖 Quick Reference")
    .setDescription(
      "**Buttons**\n" +
      "⏸ **Pause All** — Pause every active agent\n" +
      "▶ **Resume All** — Resume all paused agents\n" +
      "⚡ **Wake CEO** — Trigger the CEO's next heartbeat now\n" +
      "🔄 **Refresh** — Update statuses & timer\n" +
      "👑 **Start/Stop Self-Governing** — CEO works autonomously\n\n" +
      "**Text Commands**\n" +
      "`STOP` — Pause all agents\n" +
      "`START` — Resume all agents\n" +
      "`WAKE` — Trigger CEO heartbeat\n" +
      "`STATUS` — Refresh the panel\n" +
      "`GOVERN 6 Complete M2` — Self-govern for 6h with a goal\n" +
      "`STOPGOV` — Stop self-governing mode"
    );

  const embeds = [helpEmbed, embed];
  const components = [agentRow];

  // Self-Governing panel
  const sgEmbed = new EmbedBuilder()
    .setColor(sgActive ? 0x10b981 : 0x6b7280)
    .setTitle("👑 Self-Governing Mode");

  if (sgActive) {
    let desc = `**Status:** Active\n**Time remaining:** ${formatRemaining(sg.expiresAt)}`;
    if (sg.condition) desc += `\n**Goal:** ${sg.condition}`;
    sgEmbed.setDescription(desc);
  } else {
    sgEmbed.setDescription("**Status:** Inactive\n\nUse the buttons below or type:\n`GOVERN 6 Complete M2 milestone`");
  }

  const sgRow = new ActionRowBuilder();
  if (sgActive) {
    sgRow.addComponents(
      new ButtonBuilder()
        .setCustomId("sg:stop")
        .setLabel("⏹ Stop Self-Governing")
        .setStyle(ButtonStyle.Danger),
    );
  } else {
    sgRow.addComponents(
      new ButtonBuilder()
        .setCustomId("sg:start_modal")
        .setLabel("👑 Start Self-Governing")
        .setStyle(ButtonStyle.Success),
    );
  }

  embeds.push(sgEmbed);
  components.push(sgRow);

  const payload = { embeds, components };

  if (adminPanelMessage) {
    try {
      await adminPanelMessage.edit(payload);
      return;
    } catch {
      adminPanelMessage = null;
    }
  }

  adminPanelMessage = await adminChannel.send(payload);
}

async function getOpenWorkCount() {
  try {
    const issues = await apiFetch(
      `/companies/${COMPANY_ID}/issues?status=todo,in_progress,in_review,blocked`
    );
    return Array.isArray(issues) ? issues.length : 0;
  } catch { return -1; }
}

let windDownInterval = null;

function startWindDown(reason) {
  if (windDownInterval) return;
  console.log("[sg] Goal met — watching for agents to finish remaining work before pausing");

  windDownInterval = setInterval(async () => {
    const openWork = await getOpenWorkCount();
    if (openWork < 0) return;

    if (openWork === 0) {
      clearInterval(windDownInterval);
      windDownInterval = null;

      const count = await pauseAllAgents("Self-Governing wind-down");
      if (adminChannel) {
        await adminChannel.send(
          `<@${OWNER_DISCORD_ID}> 👑 **Self-Governing Mode ended** — ${reason}\n` +
          `All work complete — **${count} agent(s) paused** automatically.`
        );
        await sendAdminPanel();
      }
      console.log(`[sg] All work done, paused ${count} agents`);
    } else {
      console.log(`[sg] Wind-down: ${openWork} open issue(s) remaining, waiting...`);
    }
  }, 30_000);
}

function startSgWatcher() {
  if (sgWatchInterval) return;
  lastKnownSgActive = true;
  sgWatchInterval = setInterval(async () => {
    const sg = await getCeoSelfGovData();
    const isActive = sg?.expiresAt && new Date(sg.expiresAt).getTime() > Date.now();

    if (lastKnownSgActive && !isActive) {
      lastKnownSgActive = false;
      clearInterval(sgWatchInterval);
      sgWatchInterval = null;

      const expired = sg?.expiresAt && new Date(sg.expiresAt).getTime() <= Date.now();
      const reason = expired ? "Timer expired" : "Goal condition met";

      if (adminChannel) {
        await adminChannel.send(
          `<@${OWNER_DISCORD_ID}> 👑 **Self-Governing Mode ended** — ${reason}\n` +
          `Checking for remaining work before pausing agents...`
        );
        await sendAdminPanel();
      }

      startWindDown(reason);
    }
  }, 30_000);
}

function stopSgWatcher() {
  if (sgWatchInterval) {
    clearInterval(sgWatchInterval);
    sgWatchInterval = null;
  }
  if (windDownInterval) {
    clearInterval(windDownInterval);
    windDownInterval = null;
  }
  lastKnownSgActive = false;
}

async function pauseAllAgents(triggeredBy) {
  lastCacheRefresh = 0;
  await refreshCaches();
  const agents = [...agentCache.values()].filter(a => a.status !== "terminated" && a.status !== "paused");
  let count = 0;
  for (const agent of agents) {
    try {
      await fetch(`${API_URL}/api/agents/${agent.id}/pause`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ reason: `Paused via Discord by ${triggeredBy}` }),
      });
      count++;
    } catch (err) {
      console.error(`[admin] Failed to pause ${agent.name}:`, err.message);
    }
  }
  lastCacheRefresh = 0;
  return count;
}

async function resumeAllAgents(triggeredBy) {
  lastCacheRefresh = 0;
  await refreshCaches();
  const agents = [...agentCache.values()].filter(a => a.status === "paused");
  let count = 0;
  for (const agent of agents) {
    try {
      await fetch(`${API_URL}/api/agents/${agent.id}/resume`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
      });
      count++;
    } catch (err) {
      console.error(`[admin] Failed to resume ${agent.name}:`, err.message);
    }
  }
  lastCacheRefresh = 0;
  return count;
}

async function startSelfGoverning(hours, condition, triggeredBy) {
  try {
    const ceo = await apiFetch(`/agents/${CEO_ID}`);
    const meta = ceo.metadata || {};
    const sgPayload = { expiresAt: new Date(Date.now() + hours * 3600000).toISOString() };
    if (condition?.trim()) sgPayload.condition = condition.trim();
    meta.selfGoverning = sgPayload;

    await fetch(`${API_URL}/api/agents/${CEO_ID}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ metadata: meta }),
    });
    console.log(`[sg] Started: ${hours}h, condition="${condition || "none"}", by ${triggeredBy}`);
    startSgWatcher();
    return sgPayload;
  } catch (err) {
    console.error("[sg] Failed to start:", err.message);
    return null;
  }
}

async function stopSelfGoverning(triggeredBy) {
  try {
    const ceo = await apiFetch(`/agents/${CEO_ID}`);
    const meta = ceo.metadata || {};
    delete meta.selfGoverning;

    await fetch(`${API_URL}/api/agents/${CEO_ID}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ metadata: meta }),
    });
    console.log(`[sg] Stopped by ${triggeredBy}`);
    stopSgWatcher();
    return true;
  } catch (err) {
    console.error("[sg] Failed to stop:", err.message);
    return false;
  }
}

// Text commands in admin channel
client.on(Events.MessageCreate, async (message) => {
  if (message.author.bot) return;
  if (message.channelId !== ADMIN_CHANNEL_ID) return;

  const text = message.content.trim();
  const cmd = text.toUpperCase();

  if (cmd === "STOP") {
    const count = await pauseAllAgents(message.author.tag);
    await message.reply(`⏸ Paused ${count} agent(s).`);
    await sendAdminPanel();
  } else if (cmd === "START") {
    const count = await resumeAllAgents(message.author.tag);
    await message.reply(`▶ Resumed ${count} agent(s).`);
    await sendAdminPanel();
  } else if (cmd === "STATUS") {
    await sendAdminPanel();
  } else if (cmd.startsWith("GOVERN")) {
    // GOVERN <hours> <optional goal text>
    const parts = text.slice(6).trim();
    const match = parts.match(/^(\d+)\s*(.*)?$/);
    if (!match) {
      await message.reply("Usage: `GOVERN <hours> <optional goal>`\nExample: `GOVERN 6 Complete M2 milestone`");
      return;
    }
    const hours = parseInt(match[1], 10);
    const condition = match[2]?.trim() || null;
    const result = await startSelfGoverning(hours, condition, message.author.tag);
    if (result) {
      let reply = `👑 Self-Governing started for **${hours}h** (until ${new Date(result.expiresAt).toLocaleTimeString()})`;
      if (condition) reply += `\n**Goal:** ${condition}`;
      await message.reply(reply);
    } else {
      await message.reply("Failed to start self-governing mode.");
    }
    await sendAdminPanel();
  } else if (cmd === "STOPGOV" || cmd === "STOP GOV" || cmd === "STOP GOVERN") {
    const ok = await stopSelfGoverning(message.author.tag);
    await message.reply(ok ? "⏹ Self-Governing mode stopped." : "Failed to stop self-governing.");
    await sendAdminPanel();
  } else if (cmd === "WAKE" || cmd === "WAKE CEO") {
    try {
      const res = await fetch(`${API_URL}/api/agents/${CEO_ID}/wakeup`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ source: "manual", triggerDetail: `Discord by ${message.author.tag}` }),
      });
      const body = await res.json().catch(() => ({}));
      if (!res.ok) {
        await message.reply(`⚠ Wake failed (${res.status}): ${body.error || "Unknown error"}`);
      } else if (body.status === "skipped") {
        await message.reply("⏭ CEO wake was skipped — likely already running or at max concurrent runs.");
      } else {
        await message.reply("⚡ CEO heartbeat triggered.");
      }
    } catch (err) {
      await message.reply(`Failed to wake CEO: ${err.message}`);
    }
  }
});

// Admin + Self-Governing button interactions
client.on(Events.InteractionCreate, async (interaction) => {
  // Modal submission (self-governing goal form)
  if (interaction.isModalSubmit() && interaction.customId === "sg:modal_submit") {
    const hours = parseInt(interaction.fields.getTextInputValue("sg_hours"), 10) || 6;
    const condition = interaction.fields.getTextInputValue("sg_condition")?.trim() || null;
    await interaction.deferUpdate();
    const result = await startSelfGoverning(hours, condition, interaction.user.tag);
    if (result) {
      let reply = `👑 Self-Governing started for **${hours}h**`;
      if (condition) reply += ` — Goal: ${condition}`;
      await interaction.followUp({ content: reply, ephemeral: true });
    } else {
      await interaction.followUp({ content: "Failed to start.", ephemeral: true });
    }
    await sendAdminPanel();
    return;
  }

  if (!interaction.isButton()) return;

  const id = interaction.customId;

  // Self-governing buttons
  if (id === "sg:start_modal") {
    const modal = new ModalBuilder()
      .setCustomId("sg:modal_submit")
      .setTitle("Start Self-Governing Mode");

    const hoursInput = new TextInputBuilder()
      .setCustomId("sg_hours")
      .setLabel("Max hours (safety limit)")
      .setStyle(TextInputStyle.Short)
      .setPlaceholder("6")
      .setValue("6")
      .setRequired(true)
      .setMaxLength(3);

    const conditionInput = new TextInputBuilder()
      .setCustomId("sg_condition")
      .setLabel("Goal / stop condition (optional)")
      .setStyle(TextInputStyle.Paragraph)
      .setPlaceholder("e.g. CEO is highly confident M2 is complete")
      .setRequired(false)
      .setMaxLength(500);

    modal.addComponents(
      new ActionRowBuilder().addComponents(hoursInput),
      new ActionRowBuilder().addComponents(conditionInput),
    );

    await interaction.showModal(modal);
    return;
  }

  if (id === "sg:stop") {
    await interaction.deferUpdate();
    const ok = await stopSelfGoverning(interaction.user.tag);
    await interaction.followUp({
      content: ok ? "⏹ Self-Governing stopped." : "Failed to stop.",
      ephemeral: true,
    });
    await sendAdminPanel();
    return;
  }

  // Admin agent buttons
  if (!id.startsWith("admin:")) return;
  const action = id.split(":")[1];
  await interaction.deferUpdate();

  if (action === "pause_all") {
    const count = await pauseAllAgents(interaction.user.tag);
    await interaction.followUp({ content: `⏸ Paused ${count} agent(s).`, ephemeral: true });
    await sendAdminPanel();
  } else if (action === "resume_all") {
    const count = await resumeAllAgents(interaction.user.tag);
    await interaction.followUp({ content: `▶ Resumed ${count} agent(s).`, ephemeral: true });
    await sendAdminPanel();
  } else if (action === "wake_ceo") {
    try {
      const res = await fetch(`${API_URL}/api/agents/${CEO_ID}/wakeup`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ source: "manual", triggerDetail: `Discord by ${interaction.user.tag}` }),
      });
      const body = await res.json().catch(() => ({}));
      if (!res.ok) {
        await interaction.followUp({ content: `⚠ Wake failed (${res.status}): ${body.error || "Unknown error"}`, ephemeral: true });
      } else if (body.status === "skipped") {
        await interaction.followUp({ content: "⏭ CEO wake was skipped — likely already running or at max concurrent runs.", ephemeral: true });
      } else {
        await interaction.followUp({ content: "⚡ CEO heartbeat triggered.", ephemeral: true });
      }
    } catch (err) {
      await interaction.followUp({ content: `Failed to wake CEO: ${err.message}`, ephemeral: true });
    }
    await sendAdminPanel();
  } else if (action === "refresh") {
    await sendAdminPanel();
  }
});

// ---------------------------------------------------------------------------
// WebSocket connection to Paperclip live events
// ---------------------------------------------------------------------------

const recentEventIds = new Map();
const DEDUP_TTL_MS = 30_000;

function isDuplicate(entityId, action) {
  const key = `${action}:${entityId}`;
  const now = Date.now();
  if (recentEventIds.has(key) && now - recentEventIds.get(key) < DEDUP_TTL_MS) return true;
  recentEventIds.set(key, now);
  if (recentEventIds.size > 500) {
    for (const [k, t] of recentEventIds) {
      if (now - t > DEDUP_TTL_MS) recentEventIds.delete(k);
    }
  }
  return false;
}

let activeWs = null;

function connectWebSocket() {
  if (activeWs) {
    try { activeWs.removeAllListeners(); activeWs.close(); } catch {}
    activeWs = null;
  }

  const wsUrl = API_URL.replace(/^http/, "ws") + `/api/companies/${COMPANY_ID}/events/ws`;
  console.log(`[ws] Connecting to ${wsUrl}`);

  const ws = new WebSocket(wsUrl);
  activeWs = ws;
  let reconnectDelay = 2000;

  ws.on("open", () => {
    console.log("[ws] Connected");
    reconnectDelay = 2000;
  });

  ws.on("message", async (data) => {
    let event;
    try {
      event = JSON.parse(data.toString());
    } catch {
      return;
    }

    if (event.type !== "activity.logged") return;

    const action = event.payload?.action;
    const entityId = event.payload?.entityId;
    if (!action || !entityId) return;

    if (isDuplicate(entityId, action)) return;

    await refreshCaches();

    try {
      switch (action) {
        case "issue.created":
          await handleIssueCreated(event.payload);
          break;
        case "issue.comment_added":
          await handleIssueComment(event.payload);
          break;
        case "approval.created":
          await handleApprovalCreated(event.payload);
          break;
      }
    } catch (err) {
      console.error(`[event] Error handling ${action}:`, err.message);
    }
  });

  ws.on("close", (code, reason) => {
    console.log(`[ws] Disconnected (${code}). Reconnecting in ${reconnectDelay / 1000}s...`);
    activeWs = null;
    setTimeout(connectWebSocket, reconnectDelay);
    reconnectDelay = Math.min(reconnectDelay * 2, 60000);
  });

  ws.on("error", (err) => {
    console.error("[ws] Error:", err.message);
  });
}

// ---------------------------------------------------------------------------
// Startup
// ---------------------------------------------------------------------------

process.on("unhandledRejection", (err) => {
  console.error("[fatal] Unhandled rejection:", err);
});

console.log("Paperclip Discord Bridge starting...");
console.log(`  API: ${API_URL}`);
console.log(`  Company: ${COMPANY_ID}`);
console.log(`  Issue channel: ${ISSUE_CHANNEL_ID}`);
console.log(`  Approvals channel: ${APPROVALS_CHANNEL_ID}`);
console.log(`  Admin channel: ${ADMIN_CHANNEL_ID}`);

await refreshCaches();

client.once(Events.ClientReady, () => {
  connectWebSocket();
});

client.login(DISCORD_BOT_TOKEN);
