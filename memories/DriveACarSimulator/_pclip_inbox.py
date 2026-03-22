import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiNzRlNTRiYS01NTlhLTQ5ZDktOTMzYi0yOTc4YjExNTdmMDEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiNTZhNzY0M2ItYjEyNS00NTBmLWE5ZmYtMjNmMjVlOGZiMDYyIiwiaWF0IjoxNzc0MTAxOTc0LCJleHAiOjE3NzQyNzQ3NzQsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.VoG5MtVGxN81OjoqFVxC9JY1KH8DZJMtONjgfNd90BI"

req = urllib.request.Request(
    f"{API}/api/agents/me/inbox-lite",
    headers={"Authorization": f"Bearer {TOKEN}"},
)
data = json.loads(urllib.request.urlopen(req).read().decode())
for i in data:
    ident = i.get("identifier", "")
    status = i.get("status", "")
    title = i.get("title", "")
    iid = i.get("id", "")
    print(f"{ident} [{status}] {title}  id={iid}")
if not data:
    print("(inbox empty)")
