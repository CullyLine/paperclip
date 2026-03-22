import urllib.request, json, sys

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZjYzODlmNzAtMTRiZi00M2JiLTlhNmUtOTdjN2YzYWViODFhIiwiaWF0IjoxNzc0MTAzOTEzLCJleHAiOjE3NzQyNzY3MTMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.SK8eicNj_AGDrZ7f132uR94mDkhqtYvpJvzs7SSlnf0"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "f6389f70-14bf-43bb-9a6e-97c7f3aeb81a"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

def api_get(path):
    req = urllib.request.Request(f"{API}{path}", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

def api_post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="POST",
        headers={**HEADERS, "X-Paperclip-Run-Id": RUN_ID})
    return json.loads(urllib.request.urlopen(req).read().decode())

def api_patch(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="PATCH",
        headers={**HEADERS, "X-Paperclip-Run-Id": RUN_ID})
    return json.loads(urllib.request.urlopen(req).read().decode())

cmd = sys.argv[1] if len(sys.argv) > 1 else "issues"

if cmd == "issues":
    resp = api_get(f"/api/companies/{COMPANY}/issues?status=todo,in_progress,blocked,in_review&limit=100")
    items = resp if isinstance(resp, list) else resp.get("issues", [])
    for i in items:
        aid = (i.get("assigneeAgentId") or "unassigned")[:8]
        print(f"{i['identifier']:10} | {i['status']:12} | {aid:>10} | {i['title'][:90]}")
    print(f"\nTotal: {len(items)}")

elif cmd == "agents":
    resp = api_get(f"/api/companies/{COMPANY}/agents")
    for a in resp:
        giga = a.get("metadata", {}).get("gigaMode", "n/a")
        print(f"{a['id'][:8]:8} | {a['name']:25} | {a['role']:15} | {a['status']:10} | giga={giga}")

elif cmd == "issue":
    iid = sys.argv[2]
    resp = api_get(f"/api/issues/{iid}")
    print(json.dumps(resp, indent=2))

elif cmd == "comments":
    iid = sys.argv[2]
    resp = api_get(f"/api/issues/{iid}/comments")
    for c in resp:
        agent = c.get("agentName", c.get("agentId", "?"))
        print(f"--- {agent} ({c.get('createdAt','')[:16]}) ---")
        print(c.get("body", "")[:500])
        print()

elif cmd == "done":
    resp2 = api_get(f"/api/companies/{COMPANY}/issues?status=done&limit=100&parentId={sys.argv[2]}")
    items = resp2 if isinstance(resp2, list) else resp2.get("issues", [])
    for i in items:
        print(f"{i['identifier']:10} | {i['title'][:90]}")
    print(f"\nTotal done: {len(items)}")
