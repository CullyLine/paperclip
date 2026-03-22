import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZTMzNTNlNjktNzkzMS00Yzc5LTkyOTktOGIxNjQwMmM3NzA2IiwiaWF0IjoxNzc0MTA3MjU1LCJleHAiOjE3NzQyODAwNTUsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.zC1cKO4uq9qGwxf9NwJWrm0JY7M3JOhv4wYoaceE_pw"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

def api_get(path):
    req = urllib.request.Request(f"{API}{path}", method="GET", headers=HEADERS)
    return json.loads(urllib.request.urlopen(req).read().decode())

# Check recent comments on key issues
for issue_id, name in [
    ("6970323f-f457-494c-8e7f-43a3cb83405c", "POLA-171 (my last review)"),
]:
    print(f"\n=== {name} - last 3 comments ===")
    comments = api_get(f"/api/issues/{issue_id}/comments?limit=3&sort=desc")
    if isinstance(comments, dict) and "comments" in comments:
        comments = comments["comments"]
    for c in (comments if isinstance(comments, list) else []):
        author = c.get("agentNameKey") or c.get("agentId","")[:12] or "system"
        body = c.get("body","")[:200]
        print(f"  [{author}]: {body}")

# Check recently done issues
print("\n=== RECENTLY DONE ISSUES ===")
done = api_get(f"/api/companies/{COMPANY}/issues?status=done&limit=15&sort=updatedAt:desc")
if isinstance(done, dict) and "issues" in done:
    done = done["issues"]
for i in done:
    ident = i.get("identifier", "?")
    assignee = i.get("executionAgentNameKey") or "?"
    title = i.get("title", "")[:80]
    updated = i.get("updatedAt", "")[:19]
    print(f"  {ident:>10} | {assignee:>20} | {updated} | {title}")

# Check POLA-168 and POLA-169 comments for deliverables
for issue_id, name in [
    # POLA-168 Bard
    ("d3e6a7dc-53a5-4e7b-9f7a-af497a7a0168"[:36], "POLA-168"),
    # POLA-169 Content Strategist  
    ("d3e6a7dc-53a5-4e7b-9f7a-af497a7a0169"[:36], "POLA-169"),
]:
    pass  # Will get IDs from the issues list

# Get full details for active issues
for ident_num in [168, 169, 164, 131]:
    issues_all = api_get(f"/api/companies/{COMPANY}/issues?search=POLA-{ident_num}&limit=5")
    if isinstance(issues_all, dict) and "issues" in issues_all:
        issues_all = issues_all["issues"]
    for i in issues_all:
        if i.get("issueNumber") == ident_num:
            print(f"\n=== POLA-{ident_num} details ===")
            print(f"  Status: {i.get('status')}")
            print(f"  Assignee: {i.get('executionAgentNameKey') or i.get('assigneeAgentId','')[:12]}")
            iid = i["id"]
            comments = api_get(f"/api/issues/{iid}/comments?limit=3&sort=desc")
            if isinstance(comments, dict) and "comments" in comments:
                comments = comments["comments"]
            for c in (comments if isinstance(comments, list) else []):
                author = c.get("agentNameKey") or c.get("agentId","")[:12] or "system"
                body = c.get("body","")[:300]
                print(f"  [{author}]: {body}")
            break
