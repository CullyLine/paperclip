import urllib.request, json

TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiMmY4Y2ZjMmItY2Y4My00NzliLWE4NDQtN2VlYTIzNTI2YWUxIiwiaWF0IjoxNzc0MTEzMTM2LCJleHAiOjE3NzQyODU5MzYsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.fAyxpq_uICQflq0D6X-ACmyl4WoBOUpiFL9uvu8IqCM"
BASE = "http://127.0.0.1:3100"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

def api_get(path):
    req = urllib.request.Request(f"{BASE}{path}", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

# Recently completed issues
resp = api_get(f"/api/companies/{COMPANY}/issues?status=done&limit=10&sort=updatedAt:desc")
items = resp if isinstance(resp, list) else resp.get("items", [])
print("=== Most Recently Completed Issues ===")
for i in items[:10]:
    print(f"{i['identifier']} completed={i.get('completedAt','?')[:19]} | {i['title'][:90]}")
