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

const OWNER_DISCORD_ID = "165611171016081408";

async function getCurrentGoal() {
  await refreshCaches();
  const agents = [...agentCache.values()].filter(a => a.status !== "terminated");
  for (const a of agents) {
    const goal = a.metadata?.runGoal;
    if (typeof goal === "string" && goal.trim().length > 0) return goal.trim();
  }
  return null;
}

async function setGoalForAllAgents(goalText, triggeredBy) {
  lastCacheRefresh = 0;
  await refreshCaches();
  const agents = [...agentCache.values()].filter(a => a.status !== "terminated");
  let count = 0;
  for (const agent of agents) {
    try {
      await fetch(`${API_URL}/api/agents/${agent.id}/run`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ runGoal: goalText }),
      });
      count++;
    } catch (err) {
      console.error(`[goal] Failed to set goal for ${agent.name}:`, err.message);
    }
  }
  lastCacheRefresh = 0;
  console.log(`[goal] Set "${goalText}" on ${count} agent(s), by ${triggeredBy}`);
  return count;
}

async function clearGoalForAllAgents(triggeredBy) {
  lastCacheRefresh = 0;
  await refreshCaches();
  const agents = [...agentCache.values()].filter(a => a.status !== "terminated");
  let count = 0;
  for (const agent of agents) {
    try {
      const meta = agent.metadata || {};
      delete meta.runGoal;
      await fetch(`${API_URL}/api/agents/${agent.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ metadata: meta }),
      });
      count++;
    } catch (err) {
      console.error(`[goal] Failed to clear goal for ${agent.name}:`, err.message);
    }
  }
  lastCacheRefresh = 0;
  console.log(`[goal] Cleared goal on ${count} agent(s), by ${triggeredBy}`);
  return count;
}

let adminPanelMessage = null;

async function sendAdminPanel() {
  if (!adminChannel) return;
  const { agents, running, paused, idle } = await getAgentStatuses();
  const allPaused = agents.every(a => a.status === "paused");
  const currentGoal = await getCurrentGoal();

  const embed = new EmbedBuilder()
    .setColor(allPaused ? 0xef4444 : 0x22c55e)
    .setTitle("🎛️ Paperclip Control Panel")
    .setDescription(buildStatusLines(agents) || "*No agents*")
    .addFields(
      { name: "Running", value: `${running.length}`, inline: true },
      { name: "Idle", value: `${idle.length}`, inline: true },
      { name: "Paused", value: `${paused.length}`, inline: true },
    )
    .setFooter({ text: "SLEEP · REBOOT · STATUS · GOAL <text>" })
    .setTimestamp();

  const agentRow = new ActionRowBuilder().addComponents(
    new ButtonBuilder()
      .setCustomId("admin:sleep_all")
      .setLabel("😴 Sleep All")
      .setStyle(ButtonStyle.Danger),
    new ButtonBuilder()
      .setCustomId("admin:reboot_all")
      .setLabel("🔄 Reboot All")
      .setStyle(ButtonStyle.Success),
    new ButtonBuilder()
      .setCustomId("admin:refresh")
      .setLabel("📊 Refresh")
      .setStyle(ButtonStyle.Secondary),
  );

  const helpEmbed = new EmbedBuilder()
    .setColor(0x3b82f6)
    .setTitle("📖 Quick Reference")
    .setDescription(
      "**Buttons**\n" +
      "😴 **Sleep All** — Pause every agent\n" +
      "🔄 **Reboot All** — Resume + reboot all agents with fresh context\n" +
      "📊 **Refresh** — Update statuses\n" +
      "🎯 **Set / Clear Goal** — Set the goal all agents work toward\n\n" +
      "**Text Commands**\n" +
      "`SLEEP` / `STOP` — Sleep all agents\n" +
      "`REBOOT` / `START` — Reboot all agents\n" +
      "`STATUS` — Refresh the panel\n" +
      "`GOAL Fix all bugs and polish the game` — Set goal for all agents\n" +
      "`CLEARGOAL` — Clear the current goal"
    );

  const embeds = [helpEmbed, embed];
  const components = [agentRow];

  // Goal panel
  const goalEmbed = new EmbedBuilder()
    .setColor(currentGoal ? 0x8b5cf6 : 0x6b7280)
    .setTitle("🎯 Team Goal");

  if (currentGoal) {
    goalEmbed.setDescription(currentGoal);
  } else {
    goalEmbed.setDescription("*No goal set*\n\nUse the button below or type:\n`GOAL Fix all bugs and polish the game`");
  }

  const goalRow = new ActionRowBuilder().addComponents(
    new ButtonBuilder()
      .setCustomId("goal:set_modal")
      .setLabel("🎯 Set Goal")
      .setStyle(ButtonStyle.Primary),
    new ButtonBuilder()
      .setCustomId("goal:clear")
      .setLabel("✖ Clear Goal")
      .setStyle(ButtonStyle.Secondary)
      .setDisabled(!currentGoal),
  );

  embeds.push(goalEmbed);
  components.push(goalRow);

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

async function sleepAllAgents(triggeredBy) {
  const count = await pauseAllAgents(triggeredBy);
  return count;
}

async function rebootAllAgents(triggeredBy) {
  lastCacheRefresh = 0;
  await refreshCaches();
  const agents = [...agentCache.values()].filter(a => a.status !== "terminated");
  let count = 0;
  for (const agent of agents) {
    try {
      if (agent.status === "paused") {
        await fetch(`${API_URL}/api/agents/${agent.id}/resume`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
        });
      }
      await fetch(`${API_URL}/api/agents/${agent.id}/reboot`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
      });
      count++;
    } catch (err) {
      console.error(`[admin] Failed to reboot ${agent.name}:`, err.message);
    }
  }
  lastCacheRefresh = 0;
  console.log(`[admin] Rebooted ${count} agent(s), by ${triggeredBy}`);
  return count;
}

// Text commands in admin channel
client.on(Events.MessageCreate, async (message) => {
  if (message.author.bot) return;
  if (message.channelId !== ADMIN_CHANNEL_ID) return;

  const text = message.content.trim();
  const cmd = text.toUpperCase();

  if (cmd === "SLEEP" || cmd === "STOP") {
    const count = await sleepAllAgents(message.author.tag);
    await message.reply(`😴 Sleeping — paused ${count} agent(s).`);
    await sendAdminPanel();
  } else if (cmd === "REBOOT" || cmd === "START") {
    const count = await rebootAllAgents(message.author.tag);
    await message.reply(`🔄 Rebooting ${count} agent(s) with fresh context.`);
    await sendAdminPanel();
  } else if (cmd === "STATUS") {
    await sendAdminPanel();
  } else if (cmd.startsWith("GOAL ")) {
    const goalText = text.slice(5).trim();
    if (!goalText) {
      await message.reply("Usage: `GOAL <description>`\nExample: `GOAL Fix all bugs and polish the game`");
      return;
    }
    const count = await setGoalForAllAgents(goalText, message.author.tag);
    await message.reply(`🎯 Goal set for **${count} agent(s)**:\n> ${goalText}`);
    await sendAdminPanel();
  } else if (cmd === "CLEARGOAL" || cmd === "CLEAR GOAL") {
    const count = await clearGoalForAllAgents(message.author.tag);
    await message.reply(`✖ Goal cleared for **${count} agent(s)**.`);
    await sendAdminPanel();
  }
});

// Admin + Goal button interactions
client.on(Events.InteractionCreate, async (interaction) => {
  // Modal submission (goal form)
  if (interaction.isModalSubmit() && interaction.customId === "goal:modal_submit") {
    const goalText = interaction.fields.getTextInputValue("goal_text")?.trim();
    await interaction.deferUpdate();
    if (!goalText) {
      await interaction.followUp({ content: "Goal text cannot be empty.", ephemeral: true });
      return;
    }
    const count = await setGoalForAllAgents(goalText, interaction.user.tag);
    await interaction.followUp({ content: `🎯 Goal set for **${count} agent(s)**:\n> ${goalText}`, ephemeral: true });
    await sendAdminPanel();
    return;
  }

  if (!interaction.isButton()) return;

  const id = interaction.customId;

  // Goal buttons
  if (id === "goal:set_modal") {
    const modal = new ModalBuilder()
      .setCustomId("goal:modal_submit")
      .setTitle("Set Team Goal");

    const goalInput = new TextInputBuilder()
      .setCustomId("goal_text")
      .setLabel("What should all agents work toward?")
      .setStyle(TextInputStyle.Paragraph)
      .setPlaceholder("e.g. Fix all bugs and polish the game for launch")
      .setRequired(true)
      .setMaxLength(1000);

    modal.addComponents(
      new ActionRowBuilder().addComponents(goalInput),
    );

    await interaction.showModal(modal);
    return;
  }

  if (id === "goal:clear") {
    await interaction.deferUpdate();
    const count = await clearGoalForAllAgents(interaction.user.tag);
    await interaction.followUp({ content: `✖ Goal cleared for **${count} agent(s)**.`, ephemeral: true });
    await sendAdminPanel();
    return;
  }

  // Admin agent buttons
  if (!id.startsWith("admin:")) return;
  const action = id.split(":")[1];
  await interaction.deferUpdate();

  if (action === "sleep_all") {
    const count = await sleepAllAgents(interaction.user.tag);
    await interaction.followUp({ content: `😴 Sleeping — paused ${count} agent(s).`, ephemeral: true });
    await sendAdminPanel();
  } else if (action === "reboot_all") {
    const count = await rebootAllAgents(interaction.user.tag);
    await interaction.followUp({ content: `🔄 Rebooting ${count} agent(s) with fresh context.`, ephemeral: true });
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
