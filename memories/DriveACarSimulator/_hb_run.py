import urllib.request, json, sys

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZjFjMjlkMjgtZmMwNi00YTBmLWJiMTItNGRjNmUzYTE2ZDM2IiwiaWF0IjoxNzc0MTA5NTM4LCJleHAiOjE3NzQyODIzMzgsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.zJydq3PotSR5sSIFISQEOi38E6VfPfZc7tXk6qPvKT8"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "f1c29d28-fc06-4a0f-bb12-4dc6e3a16d36"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json", "X-Paperclip-Run-Id": RUN_ID}

def get(path):
    req = urllib.request.Request(f"{API}{path}", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

def post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="POST", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

def patch(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="PATCH", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

cmd = sys.argv[1] if len(sys.argv) > 1 else "issues"

if cmd == "issues":
    issues = get(f"/api/companies/{COMPANY}/issues?limit=200")
    for i in issues:
        aid = (i.get("assigneeAgentId") or "none")[:8]
        iid = i["id"][:8]
        title = i.get("title", "")[:100]
        status = i.get("status", "?")
        print(f"{status:12s} {aid:10s} {iid} {title}")
    print(f"---Total: {len(issues)}")

elif cmd == "agents":
    agents = get(f"/api/companies/{COMPANY}/agents")
    for a in agents:
        print(f"{a['status']:12s} {a['role']:20s} {a['id'][:8]} {a['name']}")

elif cmd == "projects":
    projects = get(f"/api/companies/{COMPANY}/projects")
    for p in projects:
        print(f"{p['id']} {p.get('name','')}")

elif cmd == "goals":
    goals = get(f"/api/companies/{COMPANY}/goals")
    for g in goals:
        print(f"{g['id'][:8]} {g.get('title','')[:80]}")

elif cmd == "open":
    issues = get(f"/api/companies/{COMPANY}/issues?limit=200")
    for i in issues:
        if i.get("status") not in ("done", "cancelled"):
            aid = (i.get("assigneeAgentId") or "none")[:8]
            iid = i["id"][:8]
            title = i.get("title", "")[:100]
            status = i.get("status", "?")
            print(f"{status:12s} {aid:10s} {iid} {title}")

elif cmd == "create":
    body = json.loads(sys.argv[2])
    result = post(f"/api/companies/{COMPANY}/issues", body)
    print(json.dumps(result, indent=2))

elif cmd == "patch":
    issue_id = sys.argv[2]
    body = json.loads(sys.argv[3])
    result = patch(f"/api/issues/{issue_id}", body)
    print(json.dumps(result, indent=2))

elif cmd == "get":
    issue_id = sys.argv[2]
    result = get(f"/api/issues/{issue_id}")
    print(json.dumps(result, indent=2))

elif cmd == "comments":
    issue_id = sys.argv[2]
    result = get(f"/api/issues/{issue_id}/comments")
    print(json.dumps(result, indent=2))

elif cmd == "checkout":
    issue_id = sys.argv[2]
    agent_id = "3fb10555-e10d-4f07-bf53-ce650210ce0a"
    result = post(f"/api/issues/{issue_id}/checkout", {"agentId": agent_id, "expectedStatuses": ["todo","backlog","in_progress","blocked"]})
    print(json.dumps(result, indent=2))
