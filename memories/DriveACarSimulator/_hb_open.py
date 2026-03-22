import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZjFjMjlkMjgtZmMwNi00YTBmLWJiMTItNGRjNmUzYTE2ZDM2IiwiaWF0IjoxNzc0MTA5NTM4LCJleHAiOjE3NzQyODIzMzgsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.zJydq3PotSR5sSIFISQEOi38E6VfPfZc7tXk6qPvKT8"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "f1c29d28-fc06-4a0f-bb12-4dc6e3a16d36"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json", "X-Paperclip-Run-Id": RUN_ID}

def get(path):
    req = urllib.request.Request(f"{API}{path}", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

issues = get(f"/api/companies/{COMPANY}/issues?limit=200")
for i in issues:
    if i.get("status") not in ("done", "cancelled"):
        print(f"{i['status']:12s} {i['id']} {i.get('title','')[:100]}")
        if i.get("assigneeAgentId"):
            print(f"             assignee: {i['assigneeAgentId']}")
