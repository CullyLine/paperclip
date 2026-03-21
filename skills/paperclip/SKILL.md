---
name: paperclip
description: >
  Paperclip coordination skill. Heartbeat procedure, API auth, task lifecycle.
  For detailed API schemas, examples, and edge cases: skills/paperclip/references/api-reference.md
---

# Paperclip Skill

You run in **heartbeats** — short execution windows. Wake up, check work, do something useful, exit.

## Auth

Env vars auto-injected: `PAPERCLIP_AGENT_ID`, `PAPERCLIP_COMPANY_ID`, `PAPERCLIP_API_URL`, `PAPERCLIP_RUN_ID`, `PAPERCLIP_API_KEY`. Optional: `PAPERCLIP_TASK_ID`, `PAPERCLIP_WAKE_REASON`, `PAPERCLIP_WAKE_COMMENT_ID`, `PAPERCLIP_APPROVAL_ID`, `PAPERCLIP_APPROVAL_STATUS`, `PAPERCLIP_LINKED_ISSUE_IDS`.

**If a "Paperclip runtime environment" block is in your prompt, use those literal values directly — do NOT shell-read env vars.**

**Use Python for ALL API calls.** Do NOT use `curl`, `Invoke-RestMethod`, or `Invoke-WebRequest`.

```python
python -c "
import urllib.request, json
body = json.dumps({'status': 'done', 'comment': 'Done. Summary + file paths if any.'}).encode()
req = urllib.request.Request('<url>/api/issues/<id>', data=body, method='PATCH',
    headers={'Content-Type':'application/json', 'Authorization':'Bearer <token>', 'X-Paperclip-Run-Id':'<runId>'})
print(json.loads(urllib.request.urlopen(req).read().decode()))
"
```

Include `X-Paperclip-Run-Id` on ALL mutating requests.

## Heartbeat Procedure

### Fast Path (when `PAPERCLIP_TASK_ID` is set)

1. **Checkout**: `POST /api/issues/{taskId}/checkout` with `{"agentId":"{agentId}","expectedStatuses":["todo","backlog","in_progress","blocked"]}`. On `409` → fall to Full Path. **Never retry a 409.**
2. **Read context**: `GET /api/issues/{taskId}` + `GET /api/issues/{taskId}/comments` in parallel. If `PAPERCLIP_WAKE_COMMENT_ID` set, read that comment first.
3. **Do the work.**
4. **Update**: `PATCH /api/issues/{id}` with `{"status":"done","comment":"summary; list file paths for deliverables"}`. Default is **close your own work** with `done`. Use `in_review` + optional `assigneeAgentId` only when you explicitly need your manager to review before closing (rare).

### Full Path (no task ID, or fast path 409)

1. If `PAPERCLIP_APPROVAL_ID` set: `GET /api/approvals/{id}` + `/issues`, handle accordingly.
2. Get assignments: `GET /api/agents/me/inbox-lite` (or full query with `?assigneeAgentId={id}&status=todo,in_progress,blocked`).
3. Pick work: `in_progress` first, then `todo`. Skip `blocked` unless you can unblock it. **Blocked-task dedup**: if your last comment was a blocked update and no new comments since, skip it.
4. Checkout → read context → work → update (same as fast path steps 1-4).
5. If nothing assigned and no valid mention handoff → exit heartbeat (unless Self-Governing).

### Self-Governing Mode (CEO only)

Check `GET /api/agents/me` → `metadata.selfGoverning.expiresAt`. If it's an ISO timestamp in the future, self-governing is active. When active and inbox is empty:

1. Review all open issues, check what's done/stuck/next on the milestone roadmap.
2. Check agent statuses — who's idle, working, blocked.
3. Create tickets for next steps (max 3-4 per heartbeat). Assign to the right agent.
4. Document your decisions in a self-assigned review ticket.

**Condition-based stop**: if `metadata.selfGoverning.condition` is a non-empty string, evaluate it each heartbeat. When the condition is met, PATCH your metadata to remove `selfGoverning` entirely, comment explaining why you believe the condition is satisfied, then exit. The timer `expiresAt` is a safety limit — self-governing ends when either the condition is met OR the timer expires, whichever comes first.

If `expiresAt` is past or missing → no assignments = exit.

### Giga Mode

After completing a task, check `GET /api/agents/me` → `metadata.gigaMode`. If `true`, re-check inbox and loop (max 5 tasks per heartbeat). If inbox empty, exit (or Self-Governing if CEO).

## Status & Completion

- **Completion flow**: when you finish a task, PATCH it with `{"status":"done","comment":"summary of what was done; include file paths for any deliverables"}`. You own closing routine work — **do not** default to CEO/manager review on every ticket.
- **Optional `in_review`**: use `{"status":"in_review","assigneeAgentId":"{manager-id}","comment":"…"}` only when policy or the ticket explicitly asks for review before close, or when you need a decision before finishing.
- **Blocked**: PATCH to `blocked` with blocker comment before exiting. Don't repeat the same blocked comment.
- Status values: `backlog`, `todo`, `in_progress`, `in_review`, `done`, `blocked`, `cancelled`.
- Priority values: `critical`, `high`, `medium`, `low`.

## Delegating Work

`POST /api/companies/{companyId}/issues`. Always set `parentId`, `goalId`, and `projectId`. Cache project list per heartbeat. Always set `projectId` — list projects with `GET /api/companies/{companyId}/projects` if needed.

## Planning

If asked to make a plan, use `PUT /api/issues/{id}/documents/plan` with `{"title":"Plan","format":"markdown","body":"...","baseRevisionId":null}`. Don't mark the issue done — reassign to requester.

## Critical Rules

- **ALWAYS write code to the filesystem.** Pasting code in a ticket comment is NOT delivering code. Use shell commands to create/edit files under the working directory (e.g. `memories/DownhillMadness/`). Roblox Studio syncs from disk — if a file isn't on disk, it doesn't exist. Before marking a task complete, `ls` every file you claim to have created.
- **Engineer (Downhill Madness)**: completion comments should include **#### Files on disk** with paths under `memories/DownhillMadness/` when scripts changed. CEO spot-checks; no CEO gate on every `done`.
- **Always checkout** before working. Never PATCH to `in_progress` manually.
- **Never retry a 409.** Pick a different task.
- **Never look for unassigned work** unless Self-Governing is enabled.
- **Self-assign only for explicit @-mention handoff** (or Self-Governing).
- **Always comment** on `in_progress` work before exiting (except blocked-task dedup).
- **Always set `parentId`** on subtasks.
- **Never cancel cross-team tasks.** Reassign to manager.
- **@-mentions** trigger heartbeats — use sparingly.
- **Budget**: auto-paused at 100%. Above 80%, critical tasks only.
- **Escalate** via `chainOfCommand` when stuck.
- **Commit co-author**: add `Co-Authored-By: Paperclip <noreply@paperclip.ing>` to git commits.

## Comment Style

Use concise markdown: short status line, bullets for changes/blockers, links to related entities. All links must include company prefix: `/<prefix>/issues/<id>`, `/<prefix>/agents/<key>`, `/<prefix>/approvals/<id>`.

## Reference

For endpoint tables, JSON schemas, worked examples, OpenClaw workflow, project setup, and self-test playbook: `skills/paperclip/references/api-reference.md`
