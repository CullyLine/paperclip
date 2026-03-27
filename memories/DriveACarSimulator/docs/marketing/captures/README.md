# Marketing screenshot pack (Phase 4 HUD polish)

Raw viewport captures for store listings, social posts, and pitch decks. Regenerate with:

`python docs/marketing/capture_marketing_pack.py` (requires Roblox Studio + MCP plugin on `127.0.0.1:58741`, Edit mode).

| File | Use |
|------|-----|
| `hud.png` | Hero / gameplay thumbnail — driving HUD with speed and default world chrome (safe-area aligned). |
| `shop.png` | Monetization slide — main Store panel, tabs, and offer layout. |
| `trophy.png` | Progression / collection — Trophy Case for milestones and long-term goals. |
| `payout.png` | Reward moment — run-end payout overlay (coins, multipliers, fanfare). |
| `friend_bonus.png` | Social / viral angle — Friends Bonus chip when `DACFriendBonusHUD` is in the place; otherwise **Event Banner** (top social-style feed) so solo/unsynced Studio still gets a usable shot. |

`manifest.json` is written next to these files when the capture script runs (Luau return + whether PNG saved).
