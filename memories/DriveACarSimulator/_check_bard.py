import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiYjlhMWE1ZTktZmZhYy00N2U0LWE5Y2QtMDIyY2IxODA0YTE5IiwiaWF0IjoxNzc0MTA1MjkzLCJleHAiOjE3NzQyNzgwOTMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.opsrLv10vbE6sWOZVAfvxkUtc7CV8FFiWueoTPS89eI"
HEADERS = {"Content-Type": "application/json", "Authorization": f"Bearer {TOKEN}"}

req = urllib.request.Request(f"{API}/api/issues/87d9bb66-dd96-4d40-b738-3c70677cc043", headers=HEADERS)
resp = urllib.request.urlopen(req)
data = json.loads(resp.read().decode())
print(f"Status: {data['status']}")
print(f"Title: {data['title']}")

# Also check comments
req2 = urllib.request.Request(f"{API}/api/issues/87d9bb66-dd96-4d40-b738-3c70677cc043/comments", headers=HEADERS)
resp2 = urllib.request.urlopen(req2)
comments = json.loads(resp2.read().decode())
for c in comments:
    aid = c.get("authorAgentId","board")
    if aid:
        aid = aid[:8]
    else:
        aid = "board"
    body_preview = c.get("body","")[:300]
    print(f"\n--- {aid} ---")
    print(body_preview)
