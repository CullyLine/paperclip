import urllib.request, json

BASE = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZDczNTlkYzctMWZlOC00OTBlLWJlZjgtYzQ5MWNkZjRmNTlkIiwiaWF0IjoxNzc0MTAwMjU5LCJleHAiOjE3NzQyNzMwNTksImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.KTM5pmO3cDF2yXUS7T43OVTGbDG2oJjGR5lRylAqRJs"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

req = urllib.request.Request(f"{BASE}/api/companies/{COMPANY}/agents", headers=HEADERS)
resp = json.loads(urllib.request.urlopen(req).read().decode())
for a in resp:
    print(f"ID: {a['id']}  NAME: {a['name']}  ROLE: {a['role']}")
