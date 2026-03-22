import urllib.request, json, sys

TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiMmY4Y2ZjMmItY2Y4My00NzliLWE4NDQtN2VlYTIzNTI2YWUxIiwiaWF0IjoxNzc0MTEzMTM2LCJleHAiOjE3NzQyODU5MzYsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.fAyxpq_uICQflq0D6X-ACmyl4WoBOUpiFL9uvu8IqCM"
BASE = "http://127.0.0.1:3100"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "2f8cfc2b-cf83-479b-a844-7eea23526ae1"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

def api_get(path):
    req = urllib.request.Request(f"{BASE}{path}", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

def api_post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{BASE}{path}", data=data, method="POST",
        headers={**HEADERS, "X-Paperclip-Run-Id": RUN_ID})
    return json.loads(urllib.request.urlopen(req).read().decode())

def api_patch(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{BASE}{path}", data=data, method="PATCH",
        headers={**HEADERS, "X-Paperclip-Run-Id": RUN_ID})
    return json.loads(urllib.request.urlopen(req).read().decode())

cmd = sys.argv[1] if len(sys.argv) > 1 else "issues"

if cmd == "issues":
    resp = api_get(f"/api/companies/{COMPANY}/issues?status=todo,in_progress,blocked,in_review&limit=50")
    items = resp if isinstance(resp, list) else resp.get("items", [])
    for i in items:
        ag = (i.get("assigneeAgentId") or "unassigned")[:8]
        t = i["title"][:90]
        print(f"{i['identifier']} [{i['status']}] [{i['priority']}] -> {ag} | {t}")
    print(f"\nTotal: {len(items)} open issues")

elif cmd == "agents":
    resp = api_get(f"/api/companies/{COMPANY}/agents")
    for a in resp:
        print(f"{a['id'][:8]} | {a['name']} ({a['role']}) | status={a['status']} | last_hb={a.get('lastHeartbeatAt','n/a')}")

elif cmd == "issue":
    issue_id = sys.argv[2]
    resp = api_get(f"/api/issues/{issue_id}")
    print(json.dumps(resp, indent=2))

elif cmd == "comments":
    issue_id = sys.argv[2]
    resp = api_get(f"/api/issues/{issue_id}/comments")
    for c in resp:
        who = c.get("agentName", c.get("agentId", "?"))
        print(f"--- {who} ({c.get('createdAt','?')}) ---")
        print(c.get("body", "")[:500])
        print()

elif cmd == "done":
    resp = api_get(f"/api/companies/{COMPANY}/issues?status=done&limit=30&sort=updatedAt:desc")
    items = resp if isinstance(resp, list) else resp.get("items", [])
    for i in items:
        ag = (i.get("assigneeAgentId") or "unassigned")[:8]
        t = i["title"][:90]
        print(f"{i['identifier']} [{i['status']}] [{i['priority']}] -> {ag} | {t}")
    print(f"\nTotal: {len(items)} done issues shown")
