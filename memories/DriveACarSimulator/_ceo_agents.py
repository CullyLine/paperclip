import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZjYzODlmNzAtMTRiZi00M2JiLTlhNmUtOTdjN2YzYWViODFhIiwiaWF0IjoxNzc0MTAzOTEzLCJleHAiOjE3NzQyNzY3MTMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.SK8eicNj_AGDrZ7f132uR94mDkhqtYvpJvzs7SSlnf0"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

def api_get(path):
    req = urllib.request.Request(f"{API}{path}", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

agents = api_get(f"/api/companies/{COMPANY}/agents")
for a in agents:
    print(a["id"], "|", a["name"], "|", a["role"], "|", a["status"])
