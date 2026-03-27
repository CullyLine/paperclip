# Player FAQ — Phase 4 (Discord + game page)

Short answers for common questions. For community expectations and reporting, see [`docs/CommunityRules_Phase4.md`](CommunityRules_Phase4.md). For creators streaming or clipping gameplay (what to blur on camera: codes, prices, IDs), see [`docs/StreamerModeCopy_Phase4.md`](StreamerModeCopy_Phase4.md).  
**Parent:** POLA-104 · **Ticket:** POLA-415

---

## 1. Will my progress save if I leave or the server restarts?

Yes. Progress is stored on Roblox’s servers (DataStore) for your account. The game also auto-saves periodically while you play (about every **2 minutes**).  
Always leave through normal means (stop playing / rejoin) so the latest session can finish saving—avoid force-closing the app mid-purchase if possible.

---

## 2. How do purchases work? Can I get a refund from the devs?

**Game passes** and **developer products** are sold by Roblox; charges and refunds follow [Roblox’s policies](https://en.help.roblox.com/hc/en-us/articles/203313410-Roblox-Community-Standards), not a separate in-game refund desk.  
Passes in this experience include things like **2x Coins**, **2x Speed**, **VIP**, **Extra Pet Slots**, **Lucky Eggs**, and more—check the in-game Store for current names and effects.  
If something fails to deliver after a successful Roblox purchase, note the time and rejoin once; persistent issues are best reported through official channels (see **Reporting** below).

---

## 3. How do worlds unlock? Do I need rebirths?

Worlds unlock **in order** with **coins, gems, or crystals** (not rebirth count). You start in **Grasslands**; **Scorching Desert** costs **500,000 coins**, **Frozen Tundra** **50,000 gems**, **Neon City** **100,000 crystals** (see `WorldConfig` / World panel in-game).  
Each world has a **coin multiplier** on runs (higher tiers pay more per meter).  
You keep unlocked worlds across sessions; they are **not** reset when you rebirth.

---

## 4. How do pets work?

Pets come from **eggs** and give bonuses while equipped; you can run multiple at once up to your **pet slot** limit (extra slots available via **Extra Pet Slots** game pass).  
**Hatched pets stay** in your inventory after **rebirth**; **unhatched eggs in your egg inventory are cleared** on rebirth (see `RebirthConfig.ResetOnRebirth.eggs`).  
Rarity and odds can be improved with passes like **Lucky Eggs** / **Ultra Lucky**—check the Store for the live offer set.

---

## 5. What does rebirth do? What do I lose?

**Rebirth** spends **coins** (cost scales with how many times you’ve rebirthed; **Rebirth Rush** game pass can reduce the coin cost). You gain **permanent stat boosts** (gas / power / speed) and **crystals** each time.  
On rebirth, **coins** and **car upgrade levels** reset (and **egg inventory** clears); **gems, crystals, skulls, owned cars, pets, and world unlocks** stay.  
For full fair-play context on grinding and trading, align with [`docs/CommunityRules_Phase4.md`](CommunityRules_Phase4.md).

---

## 6. Where do I enter codes, and why didn’t mine work?

Use the in-game **Codes** panel. Codes are checked on the **server**; each account can redeem a given code once, and expired codes are rejected.  
Typical rewards are **coins**, **gems**, and/or **crystals** depending on the code.  
Watch official socials for new drops—invalid or mistyped codes won’t grant rewards.

---

## 7. How do I report bugs, bad behavior, or scams?

Follow [`docs/CommunityRules_Phase4.md`](CommunityRules_Phase4.md): use **Roblox’s report tools** for serious or safety issues, and **official group / Discord** channels for feedback the team can triage—don’t share passwords or off-platform payment info.  
**Exploits, harassment, and scams** break both our community line and [Roblox Community Standards](https://en.help.roblox.com/hc/en-us/articles/203313410-Roblox-Community-Standards).  
We can’t moderate DMs—use platform reporting for abuse there.

---

## 8. The game feels laggy or flashy—what can I try?

Open **Settings**: lower **graphics quality**, turn off or reduce **particles**, lower **particle density**, or enable **reduced motion**. You can also toggle **FPS display** to see frame rate.  
These options are saved with your profile and are meant to help on low-end devices or when you want less visual noise.  
If everyone in the server lags, it may be Roblox or network conditions—try a different server or time of day.

---

## MicrocopyConfig candidates (future wiring)

Strings below are **documentation-only** for now; if product wants them in-game, they could move into `DACReplicatedStorage/Config/MicrocopyConfig.luau` (or a dedicated FAQ table) and be surfaced from a Help panel or loading tips.

| Location / use | Suggested key or pool | Notes |
|----------------|----------------------|--------|
| Save / DataStore reassurance | e.g. `FaqSaveBlurb` one-liner | Short “progress saves to Roblox” line for Store or menu |
| Purchase disclaimer | e.g. `FaqPurchaseRoblox` | Roblox handles billing; link support, not in-game refunds |
| World unlock costs summary | e.g. `FaqWorldCosts` | Must stay in sync with `WorldConfig` if duplicated |
| Rebirth reset summary | e.g. `FaqRebirthReset` | Must stay in sync with `RebirthConfig.ResetOnRebirth` |
| Code redemption hint | Reuse / extend `CodeRedeemError` / social CTA | Already have rich pools for invalid/expired codes |
| Reporting pointer | e.g. `FaqReportChannels` | Mirror `CommunityRules_Phase4` one sentence |
| Performance tips | e.g. `FaqPerformanceBullets` | Mirror settings keys: graphics, particles, density, reduced motion, FPS |

---

#### Files on disk

- `memories/DriveACarSimulator/docs/PlayerFAQ_Phase4.md`
