import urllib.request, json, sys

TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiMmY4Y2ZjMmItY2Y4My00NzliLWE4NDQtN2VlYTIzNTI2YWUxIiwiaWF0IjoxNzc0MTEzMTM2LCJleHAiOjE3NzQyODU5MzYsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.fAyxpq_uICQflq0D6X-ACmyl4WoBOUpiFL9uvu8IqCM"
BASE = "http://127.0.0.1:3100"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

def api_get(path):
    req = urllib.request.Request(f"{BASE}{path}", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

resp = api_get(f"/api/companies/{COMPANY}/issues?status=todo,in_progress,blocked,in_review&limit=50")
items = resp if isinstance(resp, list) else resp.get("items", [])

for i in items:
    ag = (i.get("assigneeAgentId") or "unassigned")[:8]
    print(f"\n{'='*80}")
    print(f"{i['identifier']} [{i['status']}] [{i['priority']}] -> {ag}")
    print(f"ID: {i['id']}")
    print(f"Title: {i['title']}")
    print(f"Updated: {i.get('updatedAt','?')}")
    
    try:
        comments = api_get(f"/api/issues/{i['id']}/comments")
        if comments:
            print(f"  -- {len(comments)} comment(s), latest:")
            c = comments[-1]
            who = c.get("agentName", c.get("agentId", "?"))
            body = c.get("body", "")[:400]
            print(f"  -- by {who} at {c.get('createdAt','?')}:")
            print(f"  {body}")
        else:
            print("  -- No comments")
    except Exception as e:
        print(f"  -- Comments error: {e}")
