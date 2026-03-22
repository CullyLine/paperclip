import urllib.request, json, sys

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiYWU2YjdjOGUtZDUwZS00MmIzLTgyZjQtNDQ3Mjk3ZDBkYTNkIiwiaWF0IjoxNzc0MTEwNzczLCJleHAiOjE3NzQyODM1NzMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.3qB9sFfRJGo0Zt43F12ZYyE24XLz5KHl1vVIHvEICk0"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "ae6b7c8e-d50e-42b3-82f4-447297d0da3d"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

def api_get(path):
    req = urllib.request.Request(f"{API}{path}", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

def api_post(path, body):
    req = urllib.request.Request(f"{API}{path}", data=json.dumps(body).encode(), method="POST",
        headers={**HEADERS, "X-Paperclip-Run-Id": RUN_ID})
    return json.loads(urllib.request.urlopen(req).read().decode())

def api_patch(path, body):
    req = urllib.request.Request(f"{API}{path}", data=json.dumps(body).encode(), method="PATCH",
        headers={**HEADERS, "X-Paperclip-Run-Id": RUN_ID})
    return json.loads(urllib.request.urlopen(req).read().decode())

cmd = sys.argv[1] if len(sys.argv) > 1 else "issues"

if cmd == "issues":
    data = api_get(f"/api/companies/{COMPANY}/issues?status=todo,in_progress,blocked,in_review&limit=100")
    issues = data if isinstance(data, list) else data.get("issues", [])
    for i in issues:
        aid = (i.get("assigneeAgentId") or "none")[:8]
        print(f'{i["identifier"]} | {i["status"]:12} | {aid} | {i["title"][:100]}')

elif cmd == "agents":
    data = api_get(f"/api/companies/{COMPANY}/agents")
    for a in data:
        giga = a.get("metadata", {}).get("gigaMode", False)
        print(f'{a["id"]} | {a["name"]:20} | role={a["role"]:10} | status={a["status"]:10} | giga={giga}')

elif cmd == "done":
    data = api_get(f"/api/companies/{COMPANY}/issues?status=done&limit=50&sortBy=updatedAt&sortOrder=desc")
    issues = data if isinstance(data, list) else data.get("issues", [])
    for i in issues[:30]:
        aid = (i.get("assigneeAgentId") or "none")[:8]
        print(f'{i["identifier"]} | {i["status"]:6} | {aid} | {i["title"][:100]}')

elif cmd == "detail":
    iid = sys.argv[2]
    data = api_get(f"/api/issues/{iid}")
    print(json.dumps(data, indent=2))

elif cmd == "search":
    q = sys.argv[2]
    data = api_get(f"/api/companies/{COMPANY}/issues?status=todo,in_progress,blocked,in_review,done&limit=200")
    issues = data if isinstance(data, list) else data.get("issues", [])
    for i in issues:
        if q.lower() in i["identifier"].lower() or q.lower() in i["title"].lower():
            print(f'{i["id"]} | {i["identifier"]} | {i["status"]} | {i["title"][:80]}')

elif cmd == "comments":
    iid = sys.argv[2]
    data = api_get(f"/api/issues/{iid}/comments")
    for c in data:
        author = c.get("authorAgentId", c.get("authorUserId", "?"))
        if author and len(author) > 8:
            author = author[:8]
        print(f'--- {author} @ {c.get("createdAt","")} ---')
        print(c.get("body", "")[:500])
        print()
