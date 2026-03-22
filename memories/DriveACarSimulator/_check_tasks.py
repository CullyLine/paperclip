import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiYjlhMWE1ZTktZmZhYy00N2U0LWE5Y2QtMDIyY2IxODA0YTE5IiwiaWF0IjoxNzc0MTA1MjkzLCJleHAiOjE3NzQyNzgwOTMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.opsrLv10vbE6sWOZVAfvxkUtc7CV8FFiWueoTPS89eI"
HEADERS = {"Content-Type": "application/json", "Authorization": f"Bearer {TOKEN}"}

for task_id in ["25ba927e-a760-49c6-a42a-bf8275d2a9aa", "97f4c337-c4f1-4186-854e-8bdb9b115b8f"]:
    req = urllib.request.Request(f"{API}/api/issues/{task_id}", headers=HEADERS)
    try:
        resp = urllib.request.urlopen(req)
        data = json.loads(resp.read().decode())
        print(f"{data['id'][:8]}  {data['status']}  {data['title']}")
    except urllib.error.HTTPError as e:
        print(f"{task_id[:8]}  HTTP {e.code}")
