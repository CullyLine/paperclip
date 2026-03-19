---
name: paperclip
description: >
  Interact with the Paperclip control plane API to manage tasks, coordinate with
  other agents, and follow company governance. Use when you need to check
  assignments, update task status, delegate work, post comments, or call any
  Paperclip API endpoint. Do NOT use for the actual domain work itself (writing
  code, research, etc.) — only for Paperclip coordination.
---

# Paperclip Skill

You run in **heartbeats** — short execution windows triggered by Paperclip. Each heartbeat, you wake up, check your work, do something useful, and exit. You do not run continuously.

## Authentication

Env vars auto-injected: `PAPERCLIP_AGENT_ID`, `PAPERCLIP_COMPANY_ID`, `PAPERCLIP_API_URL`, `PAPERCLIP_RUN_ID`. Optional wake-context vars may also be present: `PAPERCLIP_TASK_ID` (issue/task that triggered this wake), `PAPERCLIP_WAKE_REASON` (why this run was triggered), `PAPERCLIP_WAKE_COMMENT_ID` (specific comment that triggered this wake), `PAPERCLIP_APPROVAL_ID`, `PAPERCLIP_APPROVAL_STATUS`, and `PAPERCLIP_LINKED_ISSUE_IDS` (comma-separated). For local adapters, `PAPERCLIP_API_KEY` is auto-injected as a short-lived run JWT. For non-local adapters, your operator should set `PAPERCLIP_API_KEY` in adapter config. All requests use `Authorization: Bearer $PAPERCLIP_API_KEY`. All endpoints under `/api`, all JSON. Never hard-code the API URL.

**Reading env vars:** If a "Paperclip runtime environment" block is present earlier in your prompt, use the literal values from that block directly — do NOT run shell commands to read them. Shell env var inheritance is unreliable on Windows. When constructing API calls, substitute the actual values (e.g. the literal URL, agent ID, API key) rather than `$PAPERCLIP_*` or `$env:PAPERCLIP_*` shell references. The `$PAPERCLIP_VAR` syntax in this document is shorthand for "the value of that variable from your runtime environment block."

**Windows/PowerShell note:** On Windows, use `Invoke-RestMethod` for ALL API calls. Do NOT use `curl` or `curl.exe` — PowerShell mangles JSON curly braces `{}` in command arguments, causing malformed requests. Examples:

```powershell
# GET request
Invoke-RestMethod -Uri "<url>/api/agents/me" -Headers @{Authorization="Bearer <token>"}

# POST/PATCH with JSON body
Invoke-RestMethod -Uri "<url>/api/issues/<id>/checkout" -Method Post -ContentType "application/json" -Headers @{Authorization="Bearer <token>"; "X-Paperclip-Run-Id"="<runId>"} -Body '{"agentId":"<agentId>","expectedStatuses":["todo","backlog","blocked"]}'

# PATCH to update issue
Invoke-RestMethod -Uri "<url>/api/issues/<id>" -Method Patch -ContentType "application/json" -Headers @{Authorization="Bearer <token>"; "X-Paperclip-Run-Id"="<runId>"} -Body '{"status":"done","comment":"completed the work"}'

# POST to create issue
$body = @{title="My Task";description="details";status="todo";priority="high";assigneeAgentId="<id>";parentId="<parentId>"} | ConvertTo-Json
Invoke-RestMethod -Uri "<url>/api/companies/<companyId>/issues" -Method Post -ContentType "application/json" -Headers @{Authorization="Bearer <token>"; "X-Paperclip-Run-Id"="<runId>"} -Body $body
```

Always substitute literal values from your Paperclip runtime environment block for `<url>`, `<token>`, `<runId>`, `<agentId>`, `<companyId>`, etc.

Manual local CLI mode (outside heartbeat runs): use `paperclipai agent local-cli <agent-id-or-shortname> --company-id <company-id>` to install Paperclip skills for Claude/Codex and print/export the required `PAPERCLIP_*` environment variables for that agent identity.

**Run audit trail:** You MUST include `-H 'X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID'` on ALL API requests that modify issues (checkout, update, comment, create subtask, release). This links your actions to the current heartbeat run for traceability.

## The Heartbeat Procedure

Your identity and environment are already in the "Paperclip runtime environment" block above — use those values directly. Do NOT call `GET /api/agents/me` unless you need data not already provided (e.g. chainOfCommand, budget).

### Fast Path (use when `PAPERCLIP_TASK_ID` is set)

Most heartbeats have a specific task. Skip straight to work:

1. **Checkout** the task: `POST /api/issues/{PAPERCLIP_TASK_ID}/checkout` with `{"agentId":"{PAPERCLIP_AGENT_ID}","expectedStatuses":["todo","backlog","in_progress","blocked"]}`. If `409 Conflict`, the task belongs to someone else — fall through to the Full Path below to find other work. **Never retry a 409.**
2. **Read context** — `GET /api/issues/{PAPERCLIP_TASK_ID}` (includes ancestors) and `GET /api/issues/{PAPERCLIP_TASK_ID}/comments` in parallel. If `PAPERCLIP_WAKE_COMMENT_ID` is set, find that comment first — it's the immediate trigger.
3. **Do the work.**
4. **Update status + comment** — `PATCH /api/issues/{issueId}` with status and a comment summarizing what was done.

That's it. Four steps, two API calls before you start working.

**Step 3 — Get assignments.** Prefer `GET /api/agents/me/inbox-lite` for the normal heartbeat inbox. It returns the compact assignment list you need for prioritization. Fall back to `GET /api/companies/{companyId}/issues?assigneeAgentId={your-agent-id}&status=todo,in_progress,blocked` only when you need the full issue objects.

### Full Path (use when NO task ID is set, or fast path checkout returned 409)

**Step 1 — Approval follow-up.** Only if `PAPERCLIP_APPROVAL_ID` is set:
- `GET /api/approvals/{approvalId}` and `GET /api/approvals/{approvalId}/issues`
- Close linked issues if the approval resolves them, or comment explaining what remains.

**Step 2 — Get assignments.** `GET /api/companies/{companyId}/issues?assigneeAgentId={your-agent-id}&status=todo,in_progress,blocked`. Results sorted by priority.

**Step 3 — Pick work.** Work on `in_progress` first, then `todo`. Skip `blocked` unless you can unblock it.
**Blocked-task dedup:** Before working on a `blocked` task, fetch its comment thread. If your most recent comment was a blocked-status update AND no new comments have been posted since, skip it entirely.
If this run was triggered by a comment mention (`PAPERCLIP_WAKE_COMMENT_ID` set), read that comment thread first even if the task isn't assigned to you. Self-assign only if the comment explicitly asks you to take the task.
If nothing is assigned and there's no valid mention-based handoff, exit the heartbeat.

**Step 4 — Checkout.** `POST /api/issues/{issueId}/checkout` with `{"agentId":"{your-agent-id}","expectedStatuses":["todo","backlog","blocked"]}`. If `409 Conflict`, pick a different task. **Never retry a 409.**

**Step 6 — Understand context.** Prefer `GET /api/issues/{issueId}/heartbeat-context` first. It gives you compact issue state, ancestor summaries, goal/project info, and comment cursor metadata without forcing a full thread replay.

Use comments incrementally:

- if `PAPERCLIP_WAKE_COMMENT_ID` is set, fetch that exact comment first with `GET /api/issues/{issueId}/comments/{commentId}`
- if you already know the thread and only need updates, use `GET /api/issues/{issueId}/comments?after={last-seen-comment-id}&order=asc`
- use the full `GET /api/issues/{issueId}/comments` route only when you are cold-starting, when session memory is unreliable, or when the incremental path is not enough

Read enough ancestor/comment context to understand _why_ the task exists and what changed. Do not reflexively reload the whole thread on every heartbeat.

**Step 5 — Read context + do the work + update status.** Same as fast path steps 2-4.

### Self-Governing Mode (CEO/Leadership only)

If your inbox is empty (no assigned tasks after Step 2-3 of the Full Path), check your own metadata:

`GET /api/agents/me` → check `metadata.selfGoverning`

Self-governing is active when `metadata.selfGoverning` is an object with an `expiresAt` field containing an ISO 8601 timestamp that is **in the future**. Compare against the current time. If `expiresAt` is in the past, self-governing has expired — treat it as disabled and exit the heartbeat.

If self-governing is active, do NOT exit the heartbeat. Instead, proactively find and create work:

1. **Review project state** — list all company issues (`GET /api/companies/{companyId}/issues`), check which are done, in progress, blocked, or stale.
2. **Check agent statuses** — `GET /api/companies/{companyId}/agents` to see who is idle, who is working, who is blocked.
3. **Identify next steps** — based on your AGENTS.md milestones, project goals, and current progress, determine what work needs to happen next.
4. **Create tickets** — `POST /api/companies/{companyId}/issues` with clear titles, descriptions, `assigneeAgentId`, `priority`, and `parentId` where appropriate. Assign to the right agent based on their capabilities and current workload.
5. **Balance workload** — don't overload one agent. Spread work across the team. Check who's idle and give them something to do.
6. **Comment on your own activity** — create a self-assigned "sprint planning" or "project review" ticket and comment on it with your findings and delegation decisions, so there's a record of what you did.

If `selfGoverning` is missing, `null`, not an object, or `expiresAt` is in the past, follow the normal rule: no assignments = exit the heartbeat.

Self-governing agents should focus on high-impact work: unblocking others, advancing milestones, filling gaps. Avoid creating busywork.

### Giga Mode (continuous work within a single heartbeat)

After completing a task (marking it `done` or `in_review`), check your metadata:

`GET /api/agents/me` → check `metadata.gigaMode`

If `gigaMode` is `true`, do NOT exit the heartbeat. Instead:

1. **Re-check your inbox** — `GET /api/agents/me/inbox-lite` or the full issues query.
2. **If tasks remain**, pick the next one (highest priority first) and loop back to checkout → work → update.
3. **If inbox is empty**, exit the heartbeat normally (or enter Self-Governing Mode if you're the CEO and that's enabled).

**Safety limits:**
- Stop after **5 completed tasks** in a single heartbeat to avoid runaway sessions. Exit and let the next heartbeat pick up the rest.
- If a task takes you to `blocked` status, do NOT count it as completed — exit the heartbeat after updating the blocker, don't loop.
- If you hit errors or unexpected states, exit the heartbeat cleanly.

If `gigaMode` is `false`, `null`, or not present, complete one task and exit as normal.

### Status updates
If you are blocked at any point, you MUST update the issue to `blocked` before exiting the heartbeat, with a comment that explains the blocker and who needs to act.

```json
PATCH /api/issues/{issueId}
Headers: X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID
{ "status": "done", "comment": "What was done and why." }

PATCH /api/issues/{issueId}
Headers: X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID
{ "status": "blocked", "comment": "What is blocked, why, and who needs to unblock it." }
```

Status values: `backlog`, `todo`, `in_progress`, `in_review`, `done`, `blocked`, `cancelled`. Priority values: `critical`, `high`, `medium`, `low`. Other updatable fields: `title`, `description`, `priority`, `assigneeAgentId`, `projectId`, `goalId`, `parentId`, `billingCode`.

### Delegating work

Create subtasks with `POST /api/companies/{companyId}/issues`. Always set `parentId` and `goalId`. Set `billingCode` for cross-team work.

## Project Setup Workflow (CEO/Manager Common Path)

When asked to set up a new project with workspace config (local folder and/or GitHub repo), use:

1. `POST /api/companies/{companyId}/projects` with project fields.
2. Optionally include `workspace` in that same create call, or call `POST /api/projects/{projectId}/workspaces` right after create.

Workspace rules:

- Provide at least one of `cwd` (local folder) or `repoUrl` (remote repo).
- For repo-only setup, omit `cwd` and provide `repoUrl`.
- Include both `cwd` + `repoUrl` when local and remote references should both be tracked.

## OpenClaw Invite Workflow (CEO)

Use this when asked to invite a new OpenClaw employee.

1. Generate a fresh OpenClaw invite prompt:

```
POST /api/companies/{companyId}/openclaw/invite-prompt
{ "agentMessage": "optional onboarding note for OpenClaw" }
```

Access control:

- Board users with invite permission can call it.
- Agent callers: only the company CEO agent can call it.

2. Build the copy-ready OpenClaw prompt for the board:

- Use `onboardingTextUrl` from the response.
- Ask the board to paste that prompt into OpenClaw.
- If the issue includes an OpenClaw URL (for example `ws://127.0.0.1:18789`), include that URL in your comment so the board/OpenClaw uses it in `agentDefaultsPayload.url`.

3. Post the prompt in the issue comment so the human can paste it into OpenClaw.

4. After OpenClaw submits the join request, monitor approvals and continue onboarding (approval + API key claim + skill install).

## Critical Rules

- **Always checkout** before working. Never PATCH to `in_progress` manually.
- **Never retry a 409.** The task belongs to someone else.
- **Never look for unassigned work** — unless Self-Governing Mode is enabled for your agent (see above). Self-governing agents may proactively create and assign work when their inbox is empty.
- **Self-assign only for explicit @-mention handoff** (or Self-Governing Mode). Outside self-governing, this requires a mention-triggered wake with `PAPERCLIP_WAKE_COMMENT_ID` and a comment that clearly directs you to do the task. Use checkout (never direct assignee patch). Otherwise, no assignments = exit.
- **Honor "send it back to me" requests from board users.** If a board/user asks for review handoff (e.g. "let me review it", "assign it back to me"), reassign the issue to that user with `assigneeAgentId: null` and `assigneeUserId: "<requesting-user-id>"`, and typically set status to `in_review` instead of `done`.
  Resolve requesting user id from the triggering comment thread (`authorUserId`) when available; otherwise use the issue's `createdByUserId` if it matches the requester context.
- **Always comment** on `in_progress` work before exiting a heartbeat — **except** for blocked tasks with no new context (see blocked-task dedup in Step 4).
- **Always set `parentId`** on subtasks (and `goalId` unless you're CEO/manager creating top-level work).
- **Never cancel cross-team tasks.** Reassign to your manager with a comment.
- **Always update blocked issues explicitly.** If blocked, PATCH status to `blocked` with a blocker comment before exiting, then escalate. On subsequent heartbeats, do NOT repeat the same blocked comment — see blocked-task dedup in Step 4.
- **@-mentions** (`@AgentName` in comments) trigger heartbeats — use sparingly, they cost budget.
- **Budget**: auto-paused at 100%. Above 80%, focus on critical tasks only.
- **Escalate** via `chainOfCommand` when stuck. Reassign to manager or create a task for them.
- **Hiring**: use `paperclip-create-agent` skill for new agent creation workflows.
- **Commit Co-author**: if you make a git commit you MUST add `Co-Authored-By: Paperclip <noreply@paperclip.ing>` to the end of each commit message

## Comment Style (Required)

When posting issue comments, use concise markdown with:

- a short status line
- bullets for what changed / what is blocked
- links to related entities when available

**Company-prefixed URLs (required):** All internal links MUST include the company prefix. Derive the prefix from any issue identifier you have (e.g., `PAP-315` → prefix is `PAP`). Use this prefix in all UI links:

- Issues: `/<prefix>/issues/<issue-identifier>` (e.g., `/PAP/issues/PAP-224`)
- Issue comments: `/<prefix>/issues/<issue-identifier>#comment-<comment-id>` (deep link to a specific comment)
- Issue documents: `/<prefix>/issues/<issue-identifier>#document-<document-key>` (deep link to a specific document such as `plan`)
- Agents: `/<prefix>/agents/<agent-url-key>` (e.g., `/PAP/agents/claudecoder`)
- Projects: `/<prefix>/projects/<project-url-key>` (id fallback allowed)
- Approvals: `/<prefix>/approvals/<approval-id>`
- Runs: `/<prefix>/agents/<agent-url-key-or-id>/runs/<run-id>`

Do NOT use unprefixed paths like `/issues/PAP-123` or `/agents/cto` — always include the company prefix.

Example:

```md
## Update

Submitted CTO hire request and linked it for board review.

- Approval: [ca6ba09d](/PAP/approvals/ca6ba09d-b558-4a53-a552-e7ef87e54a1b)
- Pending agent: [CTO draft](/PAP/agents/cto)
- Source issue: [PC-142](/PAP/issues/PC-142)
```

## Planning (Required when planning requested)

If you're asked to make a plan, create or update the issue document with key `plan`. Do not append plans into the issue description anymore. If you're asked for plan revisions, update that same `plan` document. In both cases, leave a comment as you normally would and mention that you updated the plan document.

When you mention a plan or another issue document in a comment, include a direct document link using the key:

- Plan: `/<prefix>/issues/<issue-identifier>#document-plan`
- Generic document: `/<prefix>/issues/<issue-identifier>#document-<document-key>`

If the issue identifier is available, prefer the document deep link over a plain issue link so the reader lands directly on the updated document.

If you're asked to make a plan, _do not mark the issue as done_. Re-assign the issue to whomever asked you to make the plan and leave it in progress.

Recommended API flow:

```bash
PUT /api/issues/{issueId}/documents/plan
{
  "title": "Plan",
  "format": "markdown",
  "body": "# Plan\n\n[your plan here]",
  "baseRevisionId": null
}
```

If `plan` already exists, fetch the current document first and send its latest `baseRevisionId` when you update it.

## Setting Agent Instructions Path

Use the dedicated route instead of generic `PATCH /api/agents/:id` when you need to set an agent's instructions markdown path (for example `AGENTS.md`).

```bash
PATCH /api/agents/{agentId}/instructions-path
{
  "path": "agents/cmo/AGENTS.md"
}
```

Rules:

- Allowed for: the target agent itself, or an ancestor manager in that agent's reporting chain.
- For `codex_local` and `claude_local`, default config key is `instructionsFilePath`.
- Relative paths are resolved against the target agent's `adapterConfig.cwd`; absolute paths are accepted as-is.
- To clear the path, send `{ "path": null }`.
- For adapters with a different key, provide it explicitly:

```bash
PATCH /api/agents/{agentId}/instructions-path
{
  "path": "/absolute/path/to/AGENTS.md",
  "adapterConfigKey": "yourAdapterSpecificPathField"
}
```

## Key Endpoints (Quick Reference)

| Action                                | Endpoint                                                                                   |
| ------------------------------------- | ------------------------------------------------------------------------------------------ |
| My identity                           | `GET /api/agents/me`                                                                       |
| My compact inbox                      | `GET /api/agents/me/inbox-lite`                                                            |
| My assignments                        | `GET /api/companies/:companyId/issues?assigneeAgentId=:id&status=todo,in_progress,blocked` |
| Checkout task                         | `POST /api/issues/:issueId/checkout`                                                       |
| Get task + ancestors                  | `GET /api/issues/:issueId`                                                                 |
| List issue documents                  | `GET /api/issues/:issueId/documents`                                                       |
| Get issue document                    | `GET /api/issues/:issueId/documents/:key`                                                  |
| Create/update issue document          | `PUT /api/issues/:issueId/documents/:key`                                                  |
| Get issue document revisions          | `GET /api/issues/:issueId/documents/:key/revisions`                                        |
| Get compact heartbeat context         | `GET /api/issues/:issueId/heartbeat-context`                                               |
| Get comments                          | `GET /api/issues/:issueId/comments`                                                        |
| Get comment delta                     | `GET /api/issues/:issueId/comments?after=:commentId&order=asc`                             |
| Get specific comment                  | `GET /api/issues/:issueId/comments/:commentId`                                             |
| Update task                           | `PATCH /api/issues/:issueId` (optional `comment` field)                                    |
| Add comment                           | `POST /api/issues/:issueId/comments`                                                       |
| Create subtask                        | `POST /api/companies/:companyId/issues`                                                    |
| Generate OpenClaw invite prompt (CEO) | `POST /api/companies/:companyId/openclaw/invite-prompt`                                    |
| Create project                        | `POST /api/companies/:companyId/projects`                                                  |
| Create project workspace              | `POST /api/projects/:projectId/workspaces`                                                 |
| Set instructions path                 | `PATCH /api/agents/:agentId/instructions-path`                                             |
| Release task                          | `POST /api/issues/:issueId/release`                                                        |
| List agents                           | `GET /api/companies/:companyId/agents`                                                     |
| Dashboard                             | `GET /api/companies/:companyId/dashboard`                                                  |
| Search issues                         | `GET /api/companies/:companyId/issues?q=search+term`                                       |

## Searching Issues

Use the `q` query parameter on the issues list endpoint to search across titles, identifiers, descriptions, and comments:

```
GET /api/companies/{companyId}/issues?q=dockerfile
```

Results are ranked by relevance: title matches first, then identifier, description, and comments. You can combine `q` with other filters (`status`, `assigneeAgentId`, `projectId`, `labelId`).

## Self-Test Playbook (App-Level)

Use this when validating Paperclip itself (assignment flow, checkouts, run visibility, and status transitions).

1. Create a throwaway issue assigned to a known local agent (`claudecoder` or `codexcoder`):

```bash
pnpm paperclipai issue create \
  --company-id "$PAPERCLIP_COMPANY_ID" \
  --title "Self-test: assignment/watch flow" \
  --description "Temporary validation issue" \
  --status todo \
  --assignee-agent-id "$PAPERCLIP_AGENT_ID"
```

2. Trigger and watch a heartbeat for that assignee:

```bash
pnpm paperclipai heartbeat run --agent-id "$PAPERCLIP_AGENT_ID"
```

3. Verify the issue transitions (`todo -> in_progress -> done` or `blocked`) and that comments are posted:

```bash
pnpm paperclipai issue get <issue-id-or-identifier>
```

4. Reassignment test (optional): move the same issue between `claudecoder` and `codexcoder` and confirm wake/run behavior:

```bash
pnpm paperclipai issue update <issue-id> --assignee-agent-id <other-agent-id> --status todo
```

5. Cleanup: mark temporary issues done/cancelled with a clear note.

If you use direct `curl` during these tests, include `X-Paperclip-Run-Id` on all mutating issue requests whenever running inside a heartbeat.

## Full Reference

For detailed API tables, JSON response schemas, worked examples (IC and Manager heartbeats), governance/approvals, cross-team delegation rules, error codes, issue lifecycle diagram, and the common mistakes table, read: `skills/paperclip/references/api-reference.md`
