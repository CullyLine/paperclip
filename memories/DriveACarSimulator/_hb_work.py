import urllib.request, json, sys

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiYjlhMWE1ZTktZmZhYy00N2U0LWE5Y2QtMDIyY2IxODA0YTE5IiwiaWF0IjoxNzc0MTA1MjkzLCJleHAiOjE3NzQyNzgwOTMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.opsrLv10vbE6sWOZVAfvxkUtc7CV8FFiWueoTPS89eI"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "b9a1a5e9-ffac-47e4-a9cd-022cb1804a19"
HEADERS = {"Content-Type": "application/json", "Authorization": f"Bearer {TOKEN}", "X-Paperclip-Run-Id": RUN_ID}

def get(path):
    req = urllib.request.Request(f"{API}{path}", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

def post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="POST", headers=HEADERS)
    try:
        return json.loads(urllib.request.urlopen(req).read().decode())
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode()}")
        return None

def patch(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="PATCH", headers=HEADERS)
    try:
        return json.loads(urllib.request.urlopen(req).read().decode())
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode()}")
        return None

def put(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="PUT", headers=HEADERS)
    try:
        return json.loads(urllib.request.urlopen(req).read().decode())
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode()}")
        return None

cmd = sys.argv[1] if len(sys.argv) > 1 else "issues"

if cmd == "issues":
    issues = get(f"/api/companies/{COMPANY}/issues?status=todo,in_progress,in_review,blocked&limit=50")
    for i in issues:
        aid = (i.get("assigneeAgentId") or "")[:8]
        print(f'{i["id"][:8]}  {i.get("status","?"): <12} {i.get("priority","?"): <8} assignee={aid}  {i.get("title","")}')
    print(f"\nTotal: {len(issues)}")

elif cmd == "agents":
    agents = get(f"/api/companies/{COMPANY}/agents")
    for a in agents:
        print(f'{a["id"][:8]}  {a.get("status","?"): <10} {a.get("role","?"): <20} {a.get("name","")}')

elif cmd == "projects":
    projects = get(f"/api/companies/{COMPANY}/projects")
    for p in projects:
        print(f'{p["id"]}  {p.get("name","")}')

elif cmd == "goals":
    goals = get(f"/api/companies/{COMPANY}/goals")
    for g in goals:
        print(f'{g["id"][:8]}  {g.get("title","")}')

elif cmd == "recent":
    issues = get(f"/api/companies/{COMPANY}/issues?status=done&limit=20")
    for i in issues:
        aid = (i.get("assigneeAgentId") or "")[:8]
        print(f'{i["id"][:8]}  {i.get("status","?"): <12} assignee={aid}  {i.get("title","")}')

elif cmd == "create":
    body = json.loads(sys.argv[2])
    result = post(f"/api/companies/{COMPANY}/issues", body)
    if result:
        print(f'Created: {result["id"]}  {result.get("title","")}')

elif cmd == "comment":
    issue_id = sys.argv[2]
    comment_body = sys.argv[3]
    result = patch(f"/api/issues/{issue_id}", {"comment": comment_body})
    if result:
        print("Commented OK")

elif cmd == "done":
    issue_id = sys.argv[2]
    comment_body = sys.argv[3]
    result = patch(f"/api/issues/{issue_id}", {"status": "done", "comment": comment_body})
    if result:
        print("Marked done")

elif cmd == "issue":
    issue_id = sys.argv[2]
    data = get(f"/api/issues/{issue_id}")
    print(json.dumps(data, indent=2))

elif cmd == "comments":
    issue_id = sys.argv[2]
    data = get(f"/api/issues/{issue_id}/comments")
    for c in data:
        print(f'{c.get("authorAgentId","board")[:8] if c.get("authorAgentId") else "board"}  {c.get("body","")[:200]}')
        print("---")
