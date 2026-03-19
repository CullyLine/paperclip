# Paperclip Discord Bridge

Standalone bot that bridges Paperclip live events to Discord channels.

## Features

- **Issue Feed** — posts to a channel whenever an issue is created or commented on
- **Approvals** — posts approval requests with Approve / Deny buttons that call the Paperclip API directly

## Setup

### 1. Create a Discord Bot

1. Go to https://discord.com/developers/applications
2. Create a new application → Bot tab → copy the token
3. Enable **Server Members Intent** (optional) and **Message Content Intent** (optional)
4. Invite the bot to your server with the OAuth2 URL generator (scopes: `bot`, permissions: `Send Messages`, `Embed Links`, `Use External Emojis`)

### 2. Create Discord Channels

Create two text channels in your server:
- `#issue-feed` — for issue creation and comment notifications
- `#board-approvals` — for approval requests with interactive buttons

Right-click each channel → **Copy Channel ID** (enable Developer Mode in Discord settings if needed).

### 3. Configure

```sh
cp .env.example .env
```

Fill in:
- `DISCORD_BOT_TOKEN` — from step 1
- `DISCORD_ISSUE_CHANNEL_ID` — from step 2
- `DISCORD_APPROVALS_CHANNEL_ID` — from step 2
- `PAPERCLIP_API_URL` — defaults to `http://localhost:3100`
- `PAPERCLIP_COMPANY_ID` — your company UUID (find via `curl http://localhost:3100/api/companies`)

### 4. Install & Run

```sh
cd discord-bridge
npm install
npm start
```

The bot connects to the Paperclip live events WebSocket and starts listening immediately.

## How It Works

```
Paperclip API  ──WebSocket──>  Discord Bridge  ──Discord API──>  Discord Channels
                                     │
                              Button clicks
                                     │
Paperclip API  <──REST POST──  Discord Bridge  <──Interaction──  Discord Users
```

- Issues and comments stream from the WebSocket `activity.logged` events
- Approval buttons call `POST /api/approvals/:id/approve` or `/reject` directly
- In `local_trusted` mode (default dev), no API auth is needed
- Agent and project names are cached and refreshed every 10 minutes
