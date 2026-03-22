import urllib.request, json

BASE = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZDczNTlkYzctMWZlOC00OTBlLWJlZjgtYzQ5MWNkZjRmNTlkIiwiaWF0IjoxNzc0MTAwMjU5LCJleHAiOjE3NzQyNzMwNTksImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.KTM5pmO3cDF2yXUS7T43OVTGbDG2oJjGR5lRylAqRJs"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "d7359dc7-1fe8-490e-bef8-c491cdf4f59d"
PROJECT = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT = "6802628e-70f5-4106-a13e-2342ef950399"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

def get(path):
    req = urllib.request.Request(f"{BASE}{path}", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

def post(path, data):
    body = json.dumps(data).encode()
    req = urllib.request.Request(f"{BASE}{path}", data=body, method="POST", headers={**HEADERS, "X-Paperclip-Run-Id": RUN_ID})
    return json.loads(urllib.request.urlopen(req).read().decode())

def patch(path, data):
    body = json.dumps(data).encode()
    req = urllib.request.Request(f"{BASE}{path}", data=body, method="PATCH", headers={**HEADERS, "X-Paperclip-Run-Id": RUN_ID})
    return json.loads(urllib.request.urlopen(req).read().decode())

import sys
cmd = sys.argv[1] if len(sys.argv) > 1 else "ids"

if cmd == "ids":
    resp = get(f"/api/companies/{COMPANY}/issues?status=todo,in_progress,blocked,in_review&limit=50")
    items = resp if isinstance(resp, list) else resp.get("issues", [])
    for i in items:
        aid = i.get("assigneeAgentId", "none") or "none"
        print(f"ID={i['id']}  IDENT={i.get('identifier','?')}  STATUS={i.get('status','?')}  ASSIGNEE={aid[:8]}  TITLE={i.get('title','?')}")

elif cmd == "create":
    title = sys.argv[2]
    assignee = sys.argv[3]
    priority = sys.argv[4] if len(sys.argv) > 4 else "high"
    desc = sys.argv[5] if len(sys.argv) > 5 else ""
    data = {
        "title": title,
        "assigneeAgentId": assignee,
        "parentId": PARENT,
        "projectId": PROJECT,
        "status": "todo",
        "priority": priority,
        "description": desc,
    }
    resp = post(f"/api/companies/{COMPANY}/issues", data)
    print(f"Created: {resp.get('identifier', '?')} - {resp.get('title', '?')}")

elif cmd == "comment":
    iid = sys.argv[2]
    body = sys.argv[3]
    resp = patch(f"/api/issues/{iid}", {"comment": body})
    print(f"Commented on {resp.get('identifier','?')}")

elif cmd == "close":
    iid = sys.argv[2]
    body = sys.argv[3] if len(sys.argv) > 3 else "Done."
    resp = patch(f"/api/issues/{iid}", {"status": "done", "comment": body})
    print(f"Closed {resp.get('identifier','?')}")
