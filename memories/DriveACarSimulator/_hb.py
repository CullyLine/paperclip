import urllib.request, json, sys

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiNzRlNTRiYS01NTlhLTQ5ZDktOTMzYi0yOTc4YjExNTdmMDEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiM2E3MWQ2OGEtYTI1MC00NTlmLTg5OTMtYTdkNTJjNWM1ZGRiIiwiaWF0IjoxNzc0MTA0NzQ1LCJleHAiOjE3NzQyNzc1NDUsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.QxLcghA6M1FgICf3vmE4dxXvlTOiSyx0ok01j45zCdE"
RUN_ID = "3a71d68a-a250-459f-8993-a7d52c5c5ddb"
TASK_ID = "21c0c584-f099-4396-bc58-9d6b050ecc88"
COMPANY_ID = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
AGENT_ID = "b74e54ba-559a-49d9-933b-2978b1157f01"

HEADERS = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {TOKEN}",
    "X-Paperclip-Run-Id": RUN_ID,
}

def api_get(path):
    req = urllib.request.Request(f"{API}{path}", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

def api_patch(path, body):
    req = urllib.request.Request(f"{API}{path}", data=json.dumps(body).encode(), method="PATCH", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

def api_post(path, body):
    req = urllib.request.Request(f"{API}{path}", data=json.dumps(body).encode(), method="POST", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

cmd = sys.argv[1] if len(sys.argv) > 1 else "comments"

if cmd == "comments":
    resp = api_get(f"/api/issues/{TASK_ID}/comments")
    for c in resp:
        print(f"--- {c.get('authorAgentNameKey','?')} ({c['createdAt']}) ---")
        print(c["body"][:800])
        print()

elif cmd == "done":
    comment = sys.argv[2] if len(sys.argv) > 2 else "Done."
    resp = api_patch(f"/api/issues/{TASK_ID}", {"status": "done", "comment": comment})
    print(resp.get("status"), resp.get("id"))

elif cmd == "me":
    resp = api_get("/api/agents/me")
    print(json.dumps(resp, indent=2)[:2000])
