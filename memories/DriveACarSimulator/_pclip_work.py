import urllib.request, json, sys

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiYTY1NmVjNGYtYjZmYi00N2ExLTk3N2UtMmQ5NDk0ZmFkNDFhIiwiaWF0IjoxNzc0MTAxNjQzLCJleHAiOjE3NzQyNzQ0NDMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.2m8HOz26XBqstRzNR1rhCAf-MBrgrwGFMspmBAQl9mw"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "a656ec4f-b6fb-47a1-977e-2d9494fad41a"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json", "X-Paperclip-Run-Id": RUN_ID}

def api_get(path):
    req = urllib.request.Request(f"{API}{path}", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

def api_post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="POST", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

def api_patch(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data, method="PATCH", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

cmd = sys.argv[1] if len(sys.argv) > 1 else "agents"

if cmd == "agents":
    agents = api_get(f"/api/companies/{COMPANY}/agents")
    for a in agents:
        sep = " -- "
        print(a["id"] + sep + a["name"] + sep + a["role"])

elif cmd == "create_issue":
    body = json.loads(sys.argv[2])
    result = api_post(f"/api/companies/{COMPANY}/issues", body)
    print(json.dumps(result, indent=2))

elif cmd == "patch_issue":
    issue_id = sys.argv[2]
    body = json.loads(sys.argv[3])
    result = api_patch(f"/api/issues/{issue_id}", body)
    print(json.dumps(result, indent=2))

elif cmd == "checkout":
    issue_id = sys.argv[2]
    agent_id = sys.argv[3]
    body = {"agentId": agent_id, "expectedStatuses": ["todo", "backlog", "in_progress", "blocked"]}
    result = api_post(f"/api/issues/{issue_id}/checkout", body)
    print(json.dumps(result, indent=2))
