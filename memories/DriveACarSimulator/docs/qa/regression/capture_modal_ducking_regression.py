# Phase 4 modal ducking — panel screenshot regression (POLA-274).
# Requires Roblox Studio + robloxstudio-mcp plugin on http://127.0.0.1:58741, Edit mode.
# Game Settings > Security: enable Allow Mesh / Image APIs for capture_screenshot.
from __future__ import annotations

import base64
import json
import time
import urllib.request
from pathlib import Path

MCP = "http://127.0.0.1:58741/mcp/"
OUT = Path(__file__).resolve().parent

HIDE_ALL_AND_SHOW_ONE = r"""
local sg = game.StarterGui:FindFirstChild("DACMain")
if not sg then return "no DACMain" end
sg.Enabled = true
local panels = sg:FindFirstChild("Panels")
if not panels then return "no Panels" end
for _, ch in ipairs(panels:GetChildren()) do
	if ch:IsA("GuiObject") then
		ch.Visible = false
		local sc = ch:FindFirstChildOfClass("UIScale")
		if sc then sc.Scale = 1 end
	end
end
local name = [[__PANEL_NAME__]]
if name ~= "" and name ~= "__NONE__" then
	local f = panels:FindFirstChild(name)
	if f and f:IsA("GuiObject") then
		f.Visible = true
	end
end
return "ok " .. name
"""

OVERLAY_ONLY = r"""
local name = [[__NAME__]]
for _, ch in ipairs(game.StarterGui:GetChildren()) do
	if ch:IsA("ScreenGui") and ch.Name:sub(1, 3) == "DAC" then
		ch.Enabled = false
	end
end
local root = game.StarterGui:FindFirstChild(name)
if not root then return "missing " .. name end
root.Enabled = true
if root:FindFirstChild("Root") then
	local r = root.Root
	if r:IsA("GuiObject") then r.Visible = true end
elseif root:FindFirstChild("Bar") then
	root.Bar.Visible = true
elseif root:FindFirstChild("Card") then
	local dim = root:FindFirstChild("Dim")
	local card = root:FindFirstChild("Card")
	if dim and dim:IsA("GuiObject") then dim.Visible = true end
	if card and card:IsA("GuiObject") then card.Visible = true end
end
return "ok " .. name
"""


def mcp(tool: str, body: dict | None = None) -> dict:
    if body is None:
        body = {}
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        MCP + tool,
        data=data,
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=180) as r:
        return json.loads(r.read().decode())


def mcp_text(j: dict) -> str:
    c = j.get("content", [])
    if c and c[0].get("type") == "text":
        return c[0].get("text", "")
    return json.dumps(j)


def save_screenshot_png(path: Path) -> bool:
    j = mcp("capture_screenshot", {})
    for block in j.get("content", []):
        if block.get("type") == "image" and block.get("data"):
            raw = base64.b64decode(block["data"])
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
            return True
    path.with_suffix(".json").write_text(json.dumps(j, indent=2), encoding="utf-8")
    return False


def luau(code: str) -> str:
    j = mcp("execute_luau", {"code": code})
    return mcp_text(j)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    try:
        mcp("stop_playtest", {})
    except Exception:
        pass
    time.sleep(1.0)

    shots: list[tuple[str, str]] = [
        ("regression_shop_store.png", HIDE_ALL_AND_SHOW_ONE.replace("__PANEL_NAME__", "Store").replace("__NONE__", "")),
        ("regression_trophy_case.png", HIDE_ALL_AND_SHOW_ONE.replace("__PANEL_NAME__", "TrophyCase").replace("__NONE__", "")),
        ("regression_tutorial_overlay.png", OVERLAY_ONLY.replace("__NAME__", "DACTutorialOverlay")),
        ("regression_payout_overlay.png", OVERLAY_ONLY.replace("__NAME__", "DACPayout")),
        ("regression_settings.png", HIDE_ALL_AND_SHOW_ONE.replace("__PANEL_NAME__", "Settings").replace("__NONE__", "")),
    ]

    manifest: list[dict[str, str]] = []
    for fname, code in shots:
        try:
            ret = luau(code)
        except Exception as e:
            ret = f"ERR {e}"
        ok = save_screenshot_png(OUT / fname)
        manifest.append({"file": fname, "luau_return": ret[:500], "saved_png": str(ok)})
        time.sleep(0.4)

    try:
        luau(
            """
local m = game.StarterGui:FindFirstChild("DACMain")
if m then m.Enabled = true end
for _, ch in ipairs(game.StarterGui:GetChildren()) do
	if ch:IsA("ScreenGui") and ch.Name:sub(1,3) == "DAC" then
		if ch.Name == "DACTutorialOverlay" or ch.Name == "DACPayout" then
			ch.Enabled = false
		end
	end
end
return "restored"
"""
        )
    except Exception:
        pass

    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print("Wrote", OUT, "entries", len(manifest))


if __name__ == "__main__":
    main()
