---
name: paperclip
description: >
  Paperclip coordination skill. Work loop, API auth, task lifecycle.
  For detailed API schemas, examples, and edge cases: skills/paperclip/references/api-reference.md
---

# Paperclip Skill

You run in **persistent sessions**. The server wakes you with a task, you do it, then exit. If more work arrives, the server resumes your session with a minimal prompt — your full context is already loaded.

## Auth

Env vars auto-injected: `PAPERCLIP_AGENT_ID`, `PAPERCLIP_COMPANY_ID`, `PAPERCLIP_API_URL`, `PAPERCLIP_RUN_ID`, `PAPERCLIP_API_KEY`. Optional: `PAPERCLIP_TASK_ID`, `PAPERCLIP_WAKE_REASON`, `PAPERCLIP_WAKE_COMMENT_ID`, `PAPERCLIP_APPROVAL_ID`, `PAPERCLIP_APPROVAL_STATUS`, `PAPERCLIP_LINKED_ISSUE_IDS`.

**If a "Paperclip runtime environment" block is in your prompt, use those literal values directly — do NOT shell-read env vars.**

**Use Python for ALL API calls.** Do NOT use `curl`, `Invoke-RestMethod`, or `Invoke-WebRequest` — they break JSON escaping on Windows.

Include `X-Paperclip-Run-Id` header on ALL mutating requests.

**GET** (read issue, inbox, agent info):
```python
python -c "
import urllib.request, json
req = urllib.request.Request('<url>/api/issues/<id>',
    headers={'Authorization':'Bearer <token>'})
print(json.loads(urllib.request.urlopen(req).read().decode()))
"
```

**POST** (checkout, create issue):
```python
python -c "
import urllib.request, json
body = json.dumps({'agentId':'<agentId>','expectedStatuses':['todo','backlog','in_progress','blocked']}).encode()
req = urllib.request.Request('<url>/api/issues/<id>/checkout', data=body, method='POST',
    headers={'Content-Type':'application/json', 'Authorization':'Bearer <token>', 'X-Paperclip-Run-Id':'<runId>'})
print(json.loads(urllib.request.urlopen(req).read().decode()))
"
```

**PATCH** (update status, complete task):
```python
python -c "
import urllib.request, json
body = json.dumps({'status': 'done', 'comment': 'Done. Summary + file paths if any.'}).encode()
req = urllib.request.Request('<url>/api/issues/<id>', data=body, method='PATCH',
    headers={'Content-Type':'application/json', 'Authorization':'Bearer <token>', 'X-Paperclip-Run-Id':'<runId>'})
print(json.loads(urllib.request.urlopen(req).read().decode()))
"
```

## Work Loop

### Pre-Rendered Context

The server pre-renders your task context (issue details, ancestors, project, goal, comment cursor) and includes it in the wake prompt as `preRenderedTaskContext`. **Use this context directly instead of calling the API.** Only call the API if you need additional information (e.g. full comment thread, other issues) or to take actions (checkout, update, comment).

### Fast Path (when `PAPERCLIP_TASK_ID` is set)

1. **Checkout**: `POST /api/issues/{taskId}/checkout` with `{"agentId":"{agentId}","expectedStatuses":["todo","backlog","in_progress","blocked"]}`. On `409` → fall to Full Path. **Never retry a 409.**
2. **Read context**: Your task context is already in the wake prompt. Only fetch comments if you need the full thread: `GET /api/issues/{taskId}/comments`. If `PAPERCLIP_WAKE_COMMENT_ID` set, the wake comment is also pre-rendered.
3. **Do the work.**
4. **Update**: `PATCH /api/issues/{id}` with `{"status":"done","comment":"summary; list file paths for deliverables"}`. Default is **close your own work** with `done`. Use `in_review` + optional `assigneeAgentId` only when you explicitly need your manager to review before closing (rare).
5. **Exit.** The server will resume your session if more work arrives.

### Full Path (no task ID, or fast path 409)

1. If `PAPERCLIP_APPROVAL_ID` set: `GET /api/approvals/{id}` + `/issues`, handle accordingly.
2. Get assignments: `GET /api/agents/me/inbox-lite` (or full query with `?assigneeAgentId={id}&status=todo,in_progress,blocked`).
3. Pick work: `in_progress` first, then `todo`. Skip `blocked` unless you can unblock it. **Blocked-task dedup**: if your last comment was a blocked update and no new comments since, skip it.
4. Checkout → read context → work → update (same as fast path steps 1-4).
5. If nothing left in inbox → **exit**. The server watches for new work and resumes you.

### Run Goal

If `GET /api/agents/me` → `metadata.runGoal` is set, evaluate whether the goal is met after completing each task. When the goal is satisfied, comment on your most recent task explaining that the goal is met, then exit.

## Status & Completion

- **Completion flow**: when you finish a task, PATCH it with `{"status":"done","comment":"summary of what was done; include file paths for any deliverables"}`. You own closing routine work — **do not** default to CEO/manager review on every ticket.
- **Optional `in_review`**: use `{"status":"in_review","assigneeAgentId":"{manager-id}","comment":"…"}` only when policy or the ticket explicitly asks for review before close, or when you need a decision before finishing.
- **Blocked**: PATCH to `blocked` with blocker comment before exiting. Don't repeat the same blocked comment.
- Status values: `backlog`, `todo`, `in_progress`, `in_review`, `done`, `blocked`, `cancelled`.
- Priority values: `critical`, `high`, `medium`, `low`.

## Delegating Work

`POST /api/companies/{companyId}/issues`. Always set `parentId`, `goalId`, and `projectId`. Cache project list per session. Always set `projectId` — list projects with `GET /api/companies/{companyId}/projects` if needed.

## Planning

If asked to make a plan, use `PUT /api/issues/{id}/documents/plan` with `{"title":"Plan","format":"markdown","body":"...","baseRevisionId":null}`. Don't mark the issue done — reassign to requester.

## Critical Rules

- **ALWAYS write code to the filesystem.** Pasting code in a ticket comment is NOT delivering code. Use shell commands to create/edit files under the working directory (e.g. `memories/DownhillMadness/`). Roblox Studio syncs from disk — if a file isn't on disk, it doesn't exist. Before marking a task complete, `ls` every file you claim to have created.
- **Engineer (Downhill Madness)**: completion comments should include **#### Files on disk** with paths under `memories/DownhillMadness/` when scripts changed. CEO spot-checks; no CEO gate on every `done`.
- **Always checkout** before working. Never PATCH to `in_progress` manually.
- **Never retry a 409.** Pick a different task.
- **Always comment** on `in_progress` work before exiting (except blocked-task dedup).
- **Always set `parentId`** on subtasks.
- **Never cancel cross-team tasks.** Reassign to manager.
- **@-mentions** trigger session resumes — use sparingly.
- **Budget**: auto-paused at 100%. Above 80%, critical tasks only.
- **Escalate** via `chainOfCommand` when stuck.
- **Commit co-author**: add `Co-Authored-By: Paperclip <noreply@paperclip.ing>` to git commits.

## Comment Style

Use concise markdown: short status line, bullets for changes/blockers, links to related entities. All links must include company prefix: `/<prefix>/issues/<id>`, `/<prefix>/agents/<key>`, `/<prefix>/approvals/<id>`.

## Reference

For endpoint tables, JSON schemas, worked examples, OpenClaw workflow, project setup, and self-test playbook: `skills/paperclip/references/api-reference.md`
