import urllib.request, json, sys

API = "http://127.0.0.1:3100"
TOKEN = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZjdmN2NkYWEtM2VhYi00YmViLWI4NWMtYjdmM2U2ZTU0NTRlIiwiaWF0IjoxNzc0MTAzMzU0LCJleHAiOjE3NzQyNzYxNTQsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.CakdK-j_8CYCRiXT4jLlYScvDgWF0I7I0b64u1k7I7I"
RUN_ID = "f7f7cdaa-3eab-4beb-b85c-b7f3e6e5454e"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"

def api_get(path):
    req = urllib.request.Request(API + path, headers={"Authorization": TOKEN})
    return json.loads(urllib.request.urlopen(req).read().decode())

def api_post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(API + path, data=data, method="POST",
        headers={"Content-Type": "application/json", "Authorization": TOKEN, "X-Paperclip-Run-Id": RUN_ID})
    return json.loads(urllib.request.urlopen(req).read().decode())

def api_patch(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(API + path, data=data, method="PATCH",
        headers={"Content-Type": "application/json", "Authorization": TOKEN, "X-Paperclip-Run-Id": RUN_ID})
    return json.loads(urllib.request.urlopen(req).read().decode())

cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

if cmd == "status":
    # Get open issues with details
    import urllib.parse
    params = urllib.parse.urlencode({"status": "todo,in_progress,blocked,in_review", "limit": "50"})
    issues = api_get(f"/api/companies/{COMPANY}/issues?{params}")
    items = issues.get("issues", issues) if isinstance(issues, dict) else issues
    for i in items:
        print(f"\n=== {i['identifier']} [{i['status']}] ===")
        print(f"Title: {i['title']}")
        print(f"Assignee: {i.get('assigneeAgentId', 'none')}")
        print(f"Description: {(i.get('description') or '')[:500]}")

elif cmd == "comments":
    issue_id = sys.argv[2]
    comments = api_get(f"/api/issues/{issue_id}/comments")
    for c in comments:
        agent = c.get("agentId", "user")
        print(f"\n--- Comment by {agent[:8] if agent else 'user'} at {c.get('createdAt','')} ---")
        print(c["body"][:500])

elif cmd == "issue":
    issue_id = sys.argv[2]
    issue = api_get(f"/api/issues/{issue_id}")
    print(json.dumps(issue, indent=2))

elif cmd == "create":
    body = json.loads(sys.argv[2])
    result = api_post(f"/api/companies/{COMPANY}/issues", body)
    print(json.dumps(result, indent=2))

elif cmd == "update":
    issue_id = sys.argv[2]
    body = json.loads(sys.argv[3])
    result = api_patch(f"/api/issues/{issue_id}", body)
    print(json.dumps(result, indent=2))

elif cmd == "projects":
    projects = api_get(f"/api/companies/{COMPANY}/projects")
    for p in projects:
        print(f"{p['id']} - {p['name']}")
