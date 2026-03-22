import urllib.request, json, sys

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiYTY1NmVjNGYtYjZmYi00N2ExLTk3N2UtMmQ5NDk0ZmFkNDFhIiwiaWF0IjoxNzc0MTAxNjQzLCJleHAiOjE3NzQyNzQ0NDMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.2m8HOz26XBqstRzNR1rhCAf-MBrgrwGFMspmBAQl9mw"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "a656ec4f-b6fb-47a1-977e-2d9494fad41a"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

def api_get(path):
    req = urllib.request.Request(f"{API}{path}", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

def api_patch(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="PATCH",
        headers={**HEADERS, "X-Paperclip-Run-Id": RUN_ID})
    return json.loads(urllib.request.urlopen(req).read().decode())

def api_post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="POST",
        headers={**HEADERS, "X-Paperclip-Run-Id": RUN_ID})
    return json.loads(urllib.request.urlopen(req).read().decode())

cmd = sys.argv[1] if len(sys.argv) > 1 else "issues"

if cmd == "issues":
    result = api_get(f"/api/companies/{COMPANY}/issues?status=todo,in_progress,blocked,in_review&limit=50")
    items = result if isinstance(result, list) else result.get("issues", [])
    for i in items:
        aid = i.get("assigneeAgentId", "")
        aid_short = aid[:8] if aid else "unassign"
        title = i.get("title", "")[:80]
        print(f"{i.get('identifier','?'):>10} | {i.get('status','?'):>12} | {aid_short:>8} | {title}")

elif cmd == "agents":
    agents = api_get(f"/api/companies/{COMPANY}/agents")
    for a in agents:
        aid = a["id"][:8]
        print(f"{aid} | {a['name']:>20} | {a['status']:>10} | last_hb: {a.get('lastHeartbeatAt','none')}")

elif cmd == "done":
    result = api_get(f"/api/companies/{COMPANY}/issues?status=done&limit=30&sort=updatedAt&order=desc")
    items = result if isinstance(result, list) else result.get("issues", [])
    for i in items:
        title = i.get("title", "")[:80]
        print(f"{i.get('identifier','?'):>10} | done | {title}")

elif cmd == "issue":
    issue_id = sys.argv[2]
    data = api_get(f"/api/issues/{issue_id}")
    print(json.dumps(data, indent=2))

elif cmd == "comments":
    issue_id = sys.argv[2]
    data = api_get(f"/api/issues/{issue_id}/comments")
    items = data if isinstance(data, list) else data.get("comments", [])
    for c in items:
        who = c.get("agentName", c.get("agentId", "?"))
        print(f"--- {who} ({c.get('createdAt','')}) ---")
        print(c.get("body", "")[:500])
        print()
