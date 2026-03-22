import urllib.request, json, sys

BASE = "http://127.0.0.1:3100"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzZmIxMDU1NS1lMTBkLTRmMDctYmY1My1jZTY1MDIxMGNlMGEiLCJjb21wYW55X2lkIjoiYjdmY2FjMmUtNmVjOS00ZTU5LWFjYmEtMDYyYjQ5NTcwN2NhIiwiYWRhcHRlcl90eXBlIjoiY3Vyc29yIiwicnVuX2lkIjoiZDczNTlkYzctMWZlOC00OTBlLWJlZjgtYzQ5MWNkZjRmNTlkIiwiaWF0IjoxNzc0MTAwMjU5LCJleHAiOjE3NzQyNzMwNTksImlzcyI6InBhcGVyY2xpcCIsImF1ZCI6InBhcGVyY2xpcC1hcGkifQ.KTM5pmO3cDF2yXUS7T43OVTGbDG2oJjGR5lRylAqRJs"
COMPANY = "b7fcac2e-6ec9-4e59-acba-062b495707ca"
RUN_ID = "d7359dc7-1fe8-490e-bef8-c491cdf4f59d"
PROJECT = "67f13586-234a-4b93-9ccc-f58e5cfb09ef"
PARENT = "6802628e-70f5-4106-a13e-2342ef950399"
AGENT_ID = "3fb10555-e10d-4f07-bf53-ce650210ce0a"
ENGINEER = "323fca23-ecfa-4f35-aeb1-77f206eccf34"
BARD = "b74e54ba-559a-49d9-933b-2978b1157f01"
CONTENT = "0b51d97d-f321-4cb9-830c-892ec863fdf4"

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
    "X-Paperclip-Run-Id": RUN_ID,
}

def post(path, data):
    body = json.dumps(data).encode()
    req = urllib.request.Request(f"{BASE}{path}", data=body, method="POST", headers=HEADERS)
    try:
        return json.loads(urllib.request.urlopen(req).read().decode())
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode()}")
        return None

def patch(path, data):
    body = json.dumps(data).encode()
    req = urllib.request.Request(f"{BASE}{path}", data=body, method="PATCH", headers=HEADERS)
    try:
        return json.loads(urllib.request.urlopen(req).read().decode())
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode()}")
        return None

def create_issue(title, assignee, priority, description):
    data = {
        "title": title,
        "assigneeAgentId": assignee,
        "parentId": PARENT,
        "projectId": PROJECT,
        "status": "todo",
        "priority": priority,
        "description": description,
    }
    resp = post(f"/api/companies/{COMPANY}/issues", data)
    if resp:
        print(f"Created: {resp.get('identifier', '?')} - {resp.get('title', '?')}")
    return resp

if __name__ == "__main__":
    cmd = sys.argv[1]

    if cmd == "test":
        create_issue("Test issue", ENGINEER, "low", "test")

    elif cmd == "wave3":
        # 1. Leaderboard Rank-Up
        create_issue(
            "Engineer: Leaderboard Rank-Up Fanfare + Top 10 Crown VFX",
            ENGINEER,
            "high",
            "Add dopamine juice to the leaderboard system. When a player's rank improves since last check, show a rank-up animation (gold arrows, position number flying up). Cracking top 10 triggers a special crown particle burst. Reaching #1 gets a full-screen 'CHAMPION!' fanfare with confetti and a golden aura. Track previous rank in player data or local cache to detect changes. Files: LeaderboardPanel.luau, LeaderboardService.luau, VFXController.luau, VFXFacade.luau. Wire rank-change detection server-side and fire a new RankUpNotification remote that VFXController listens to.",
        )

        # 2. Pet Fusion Reveal VFX
        create_issue(
            "Engineer: Pet Fusion Reveal VFX + Power Surge Animation",
            ENGINEER,
            "high",
            "Transform the pet fusion from a plain toast into a full dopamine moment. When pets are fused successfully: (1) Show a fusion chamber animation - pets spiral together, flash of light, new pet revealed with rarity-colored burst. (2) Power number counts up dramatically from old to new value. (3) If the fused pet is Legendary/Mythic rarity, add screen shake + rainbow particle explosion. (4) Add a 'FUSION COMPLETE!' banner with the pet's silhouette reveal. Wire a new FusionResult remote from PetService that carries the pet def + power + rarity. VFXController handles the full sequence. Files: PetService.luau, VFXController.luau, VFXFacade.luau, UIController.luau.",
        )

        # 3. Pet Index Discovery Reveal
        create_issue(
            "Engineer: Pet Index Discovery Reveal + Collection Milestone Celebrations",
            ENGINEER,
            "high",
            "Add dopamine to the pet collection/discovery system. (1) When a new pet species is discovered (discoveredPets diff), show a 'NEW DISCOVERY!' popup with the pet silhouette unmasking, rarity-colored glow, and a stamp-down sound effect. (2) Track collection percentage and trigger milestone celebrations at 25%%/50%%/75%%/100%% of the pet index filled: '25%% COLLECTOR', 'HALFWAY THERE!', 'MASTER COLLECTOR', 'POKEDEX COMPLETE!' with escalating VFX. (3) In VFXController.onPlayerDataUpdate, diff discoveredPets between old and new data to detect new discoveries. Files: PetIndexPanel.luau, VFXController.luau, VFXFacade.luau, PetConfig.luau (for total count).",
        )

        # 4. Rebirth Tier Milestones
        create_issue(
            "Engineer: Rebirth Tier Milestones + Prestige Aura Escalation",
            ENGINEER,
            "high",
            "Expand the rebirth celebration system beyond just the first rebirth. Add escalating celebrations for rebirth milestones: Rebirth 5 = 'VETERAN!' bronze burst, Rebirth 10 = 'ELITE!' silver cascade, Rebirth 25 = 'MASTER!' gold supernova, Rebirth 50 = 'LEGEND!' diamond explosion with screen-wide particle storm, Rebirth 100 = 'IMMORTAL!' rainbow universe-crack animation. Each tier gets progressively more dramatic. Also add a persistent prestige glow aura that upgrades at each tier (visible to other players via VipNametag or TitleNametag). In VFXController.onPlayerDataUpdate, check rebirth count against tier thresholds. Files: VFXController.luau, VFXFacade.luau, RebirthPanel.luau.",
        )

        # 5. Content Strategist: FOMO urgency text
        create_issue(
            "Content Strategist: Leaderboard Trash-Talk Headlines + Rank FOMO Text",
            CONTENT,
            "medium",
            "Write compelling competitive/FOMO text for the leaderboard system. (1) Rank-up congratulatory messages (pool of 10+ rotating messages like 'You just CRUSHED rank #{old}!', 'Moving up! #{new} and climbing!'). (2) Top 10 elite messages ('Welcome to the top 10, champion!', 'Only legends live up here.'). (3) Close-to-next-rank teaser text ('You're only 1,234 coins from rank #{next}! One more run!'). (4) Loss-aversion messages when someone is close to overtaking you ('#{rival_rank} is gaining on you! Drive harder!'). Output as a Luau config table in DACReplicatedStorage/Config/LeaderboardTextConfig.luau.",
        )

    elif cmd == "comment":
        iid = sys.argv[2]
        body = sys.argv[3]
        resp = patch(f"/api/issues/{iid}", {"comment": body})
        if resp:
            print(f"Commented on {resp.get('identifier','?')}")
