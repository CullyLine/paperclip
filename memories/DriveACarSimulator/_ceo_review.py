import urllib.request, json, sys

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZjYzODlmNzAtMTRiZi00M2JiLTlhNmUtOTdjN2YzYWViODFhIiwiaWF0IjoxNzc0MTAzOTEzLCJleHAiOjE3NzQyNzY3MTMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.SK8eicNj_AGDrZ7f132uR94mDkhqtYvpJvzs7SSlnf0"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "f6389f70-14bf-43bb-9a6e-97c7f3aeb81a"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

def api_get(path):
    req = urllib.request.Request(f"{API}{path}", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

cmd = sys.argv[1] if len(sys.argv) > 1 else "done"

if cmd == "done":
    parent_id = sys.argv[2] if len(sys.argv) > 2 else "6802628e-70f5-4106-a13e-2342ef950399"
    resp = api_get(f"/api/companies/{COMPANY}/issues?status=done&limit=50&parentId={parent_id}")
    items = resp if isinstance(resp, list) else resp.get("issues", [])
    for i in items:
        ca = (i.get("completedAt") or "")[:16]
        print(f"{i['identifier']:10} | {ca} | {i['title'][:85]}")
    print(f"\nTotal done: {len(items)}")

elif cmd == "comments":
    issue_id = sys.argv[2]
    comments = api_get(f"/api/issues/{issue_id}/comments")
    for c in comments:
        agent = c.get("agentName", c.get("agentId", "?"))
        ts = (c.get("createdAt") or "")[:16]
        body = (c.get("body") or "")[:800]
        print(f"--- {agent} ({ts}) ---")
        print(body)
        print()

elif cmd == "issue":
    issue_id = sys.argv[2]
    resp = api_get(f"/api/issues/{issue_id}")
    print(json.dumps({
        "id": resp["id"],
        "identifier": resp.get("identifier"),
        "title": resp.get("title"),
        "status": resp.get("status"),
        "assignee": (resp.get("assigneeAgentId") or "none")[:8],
        "completedAt": resp.get("completedAt"),
        "description": (resp.get("description") or "")[:500]
    }, indent=2))

elif cmd == "recently_done":
    resp = api_get(f"/api/companies/{COMPANY}/issues?status=done&limit=50&parentId=6802628e-70f5-4106-a13e-2342ef950399")
    items = resp if isinstance(resp, list) else resp.get("issues", [])
    items.sort(key=lambda x: x.get("completedAt") or "", reverse=True)
    for i in items[:10]:
        ca = (i.get("completedAt") or "")[:16]
        aid = (i.get("executionAgentNameKey") or (i.get("assigneeAgentId") or "?")[:8])
        print(f"{i['identifier']:10} | {ca} | {aid:12} | {i['title'][:75]}")
    print(f"\nTotal done: {len(items)}")
