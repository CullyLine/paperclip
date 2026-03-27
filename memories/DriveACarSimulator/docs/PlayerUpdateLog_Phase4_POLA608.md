# Drive a Car Simulator — Player update log (draft, Phase 4)

**Audience:** Experience page, group post, or Discord `#announcements` · **Tone:** reward-forward simulator, honest about limits · **Parent:** POLA-104 · **Ticket:** POLA-608

**Related:** Feature headlines and character budgets → `docs/WhatsNew_Phase4_PlayerFacing.md` · Full patch skeleton → `docs/PatchNotesTemplate_Phase4.md` · **Known limitations (short paste block)** → `docs/KnownLimitations_MicroSection_POLA611.md` (POLA-611)

---

## What shipped (this phase)

**Feel & juice** — Phase 4 focus is dopamine-safe polish: milestone and combo feedback, notification lane ordering, HUD safe-area work, and world/atmosphere touches so driving stays readable on phone and desktop.

**First-time clarity (FTUE)** — Onboarding beats, loading tips, and player FAQ docs so new drivers understand gas → distance → money → upgrades without guessing. Tutorial and empty-state copy align with the same loop.

**Stability & networking** — Server-side guardrails on remotes (rate checks, code redemption sliding window, cooldowns) reduce spam and edge-case abuse without changing the core loop for fair players.

**Audio pipeline** — Sounds are organized for upload and runtime hydration: registry-driven playback, optional overwrite from `ReplicatedStorage.Audio` when clips are placed in Studio, and a documented path from source files to OGG for Roblox. Final loudness and coverage continue to improve as the audio pass lands in Studio.

**Progression content (data)** — Cars, pets, eggs, and rebirth-style systems stay aligned with the design docs; trade remains off for launch verification where noted in the internal checklist.

---

## Monetization (how we talk about it)

**Paying players** — Game Passes and developer products are framed as real power and convenience: faster progression, quality-of-life, and optional cosmetics where configured. We do not oversell what is not yet wired.

**Free-to-play** — The full loop is playable without spending; paying accelerates and widens options. We avoid implying that every SKU is live until Creator Dashboard IDs are pasted into config (see internal POLA-95).

---

## What’s next (honest roadmap)

- **Creator Dashboard** — Wire real game pass and developer product IDs into config when SKUs exist; until then, treat store surfaces as “coming when published.”
- **Studio & assets** — Thumbnails, icons, and any remaining placeholder media are completed in Roblox Studio and uploads, not only in git.
- **Playtests** — When POLA-606 (or equivalent) playtest notes land, fold concrete player feedback into the next revision of this log; do not invent outcomes.

---

## One-paragraph paste (experience page / long description, ~900 characters max)

Drive a Car Simulator is in **Phase 4 polish**: we are tightening how the game *feels*—clearer first sessions, smarter HUD and notification stacking, milestone celebrations that reward big moments, and server-side protections so the road stays fair. Audio is on a structured pipeline from files through Roblox so music and SFX improve as we finish the pass in Studio. The core loop stays the same: drive, earn, upgrade pets and cars, rebirth for long-term power. Paying players get real advantages where products are live; everyone else still progresses. Some Creator Dashboard IDs and art passes are still in flight—thanks for sticking with us while we ship the last mile.

---

*Internal only — do not paste:* POLA-95 (SKU IDs), POLA-553 (human audio ops), POLA-606 (playtest pairing). Player copy should never blame vendors or promise specific ticket outcomes.
