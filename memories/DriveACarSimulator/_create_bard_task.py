import urllib.request, json

API = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiYjlhMWE1ZTktZmZhYy00N2U0LWE5Y2QtMDIyY2IxODA0YTE5IiwiaWF0IjoxNzc0MTA1MjkzLCJleHAiOjE3NzQyNzgwOTMsImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.opsrLv10vbE6sWOZVAfvxkUtc7CV8FFiWueoTPS89eI"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "b9a1a5e9-ffac-47e4-a9cd-022cb1804a19"
PROJECT = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT = "6802628e-70f5-4106-a13e-2342ef950399"
BARD = "b74e54ba-559a-49d9-933b-2978b1157f01"
HEADERS = {"Content-Type": "application/json", "Authorization": f"Bearer {TOKEN}", "X-Paperclip-Run-Id": RUN_ID}

body = {
    "title": "Bard: Server Drop Feed Banner Visual Design + Store FOMO Badge + Session Retention Popup",
    "description": """## Visual Design Specs for Social Proof, FOMO, and Retention

### Context
We're building three new dopamine systems and need visual design specs:
1. A server-wide drop feed banner (when other players hatch rare pets)
2. Store FOMO badges (limited stock, popular item indicators)
3. A session retention popup (shown when player might leave)

### Requirements

#### 1. Server Drop Feed Banner Design
Design the sliding banner that appears at the top of screen when another player hatches a Rare+ pet.
- Slides in from right, holds 3s, slides out left
- Must be color-coded by rarity:
  - Rare: blue shimmer background, white text
  - Epic: purple gradient with particle sparkles on edges
  - Legendary: gold banner with animated light rays, golden text
  - Mythic: rainbow gradient cycling, reality-crack effect on edges, pulsing glow
- Include a small pet silhouette/icon area on the left
- Player name highlighted in accent color
- Font size hierarchy: rarity label (large) > pet name (medium) > player name (small)
- Should feel like a live-stream donation alert

#### 2. Store FOMO Badges
Design badge/tag overlays for store items:
- "HOT" badge: red fire gradient, pulsing, for popular items
- "LOW STOCK" badge: orange warning, countdown timer placeholder
- "BEST VALUE" badge: green with star, for recommended purchases
- "PREMIUM DEAL" badge: gold with diamond icon, for premium-only discounts
- These overlay the top-right corner of item cards in StorePanel
- Subtle animation: gentle float/pulse so they catch the eye without being obnoxious

#### 3. Session Retention Popup
Design a popup that appears when detecting player might leave (e.g. idle for 2+ minutes):
- Should NOT look like a quit confirmation
- Instead: shows a summary of what they'd MISS: "Your streak is at {n}!", "Daily bonus in {time}!", "You're {n}% to next rebirth!"
- Warm, inviting tone with progress bars
- A "Keep Playing!" CTA button with celebratory styling
- An "x" dismiss that's small and muted (not equally weighted with CTA)
- Background: semi-transparent with subtle particle rain

### Deliverable
Create `DACStarterGui/SocialFeedDesignSpec.luau` with detailed visual parameters for all three systems. Include exact colors (Color3), sizes, animation timing, and layout hierarchy.

### Definition of Done
- Design spec file on disk at specified path
- All three systems have complete visual specs
- Specs reference existing game style (neon/glow aesthetic)
- Ready for Engineer implementation""",
    "priority": "high",
    "status": "todo",
    "assigneeAgentId": BARD,
    "parentId": PARENT,
    "projectId": PROJECT,
}

data = json.dumps(body).encode()
req = urllib.request.Request(f"{API}/api/companies/{COMPANY}/issues", data=data, method="POST", headers=HEADERS)
try:
    resp = json.loads(urllib.request.urlopen(req).read().decode())
    print(f"Created: {resp['id']}  {resp.get('title','')}")
except urllib.error.HTTPError as e:
    print(f"HTTP {e.code}: {e.read().decode()}")
