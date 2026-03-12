# Creator Store Listing — Branching Dialogue Engine V1.0

*Ready to copy-paste into the Roblox Creator Store submission form.*

---

## Title

```
Branching Dialogue Engine — RPG NPC System
```

*(43 characters — within 50-character limit)*

---

## Short Description

```
Pro dialogue system: branching trees, typewriter text, NPC portraits, themes, save/load & gamepad. The Roblox equivalent of Unity's Dialogue System — finally here.
```

*(166 characters — within 200-character limit)*

---

## Full Description

**Give your NPCs a real voice. Build conversations that matter.**

The Branching Dialogue Engine is the first professional-grade, production-ready dialogue system on the Roblox Creator Store — purpose-built for anime RPGs, adventure games, and horror experiences where character and story drive the experience.

No more hardcoded if-chains. No more walls of spaghetti LocalScript dialogue. Write your entire NPC story in clean, readable text files or Lua tables, and the engine handles everything else.

---

**Why developers keep reaching for this:**

Roblox has always lacked a proper dialogue toolkit. Unity developers have had Naninovel, Dialogue System for Unity, and Yarn Spinner for years. The Branching Dialogue Engine closes that gap — bringing the same quality-of-life that professional game developers expect, to Roblox.

---

### Core Features

**Dialogue Authoring — Two Formats**
- **Simple text format** — write full conversation trees in plain text using a clean, readable syntax. No Lua knowledge required for the dialogue content itself. Perfect for designers and writers.
- **Lua table format** — define trees programmatically for dynamic, data-driven dialogue. Full control over every field.

**Visual NPC Portraits**
- Auto-viewport portrait pulls the NPC model and displays it in a 3D portrait frame automatically — no setup needed
- Custom portrait images via `portraitImageId` for character art, expressions, and non-humanoid NPCs
- Per-node model overrides for multi-character scenes and cutscene-style dialogue

**Cinematic Presentation**
- Typewriter text animation — smooth character-by-character reveal, rich text safe (never shows broken `<b>` tags mid-animation)
- Voice/sound line support — attach audio to any dialogue node with automatic cleanup
- Full UI sound effects — open, close, typewriter tick, choice hover, and choice select sounds all configurable

**5 Built-In Themes**
- **Dark** — sleek dark UI for anime RPGs and action games (default)
- **Fantasy** — warm parchment tones with serif fonts for medieval and adventure games
- **Sci-Fi** — neon cyan accents on near-black for cyberpunk and space games
- **Bubblegum** — bright pastels and rounded corners for tycoons and simulator games
- **Horror** — blood-red on near-black with slow typewriter for tension and dread
- Full `Theme.Extend()` API to start from any preset and override individual properties
- Per-conversation themes — give each NPC their own look with zero overhead

**Branching & Conditions**
- Unlimited choice depth and branching — as many paths as your story needs
- Condition system — register callbacks to gate choices behind gold, inventory, level, quest flags, or any custom game state
- `hideWhenUnavailable` — choices can be greyed out or completely hidden based on conditions
- **Variable interpolation** — `{playerName}`, `{gold}`, any runtime value embedded directly into dialogue and choice text via `RegisterVariable()` callbacks. Always reflects live game state.
- **Inline text control** — `[pause N]` and `[speed N]` tags for dramatic mid-sentence pacing: hold the typewriter at a tense moment, then snap back to full speed for the punchline

**Event Hooks**
- `onNodeEnter` — fire any game logic when the player reaches a node (give items, start quests, trigger cutscenes)
- `onChoice` — respond to specific player decisions for analytics or state tracking
- `onEnd` — run cleanup when the conversation finishes

**Input — Keyboard, Gamepad & Touch**
- Keyboard: 1–4 to select choices, arrow keys to navigate, Enter/Space to confirm, Escape to close
- Gamepad: D-pad navigation, A to confirm, B to close
- Touch/Click: tap anywhere to skip typewriter, tap choice buttons to select
- Two-step typewriter skip prevents accidental choice selection

**Save & Load State**
- `SaveState()` — snapshot the current dialogue state to a serializable Lua table
- `StartFromState()` — resume from any saved node on next session
- `GetVisitedNodes()` — check which nodes a player has visited for dynamic NPC reactions
- Full DataStore integration example included in the documentation

**Developer Experience**
- ProximityPrompt-ready — replaces deprecated ClickDetector pattern
- Single require — one `require()` call, zero external dependencies
- Works in Team Create and published games
- Full error messages and warnings to help you debug fast

---

### What's Included

- **Core engine** (5 ModuleScripts, fully commented)
- **Example LocalScript** — 4 NPC demos with different themes, conditions, rich text, and branching patterns
- **Complete documentation** — Quick Start, Text Format Reference, Lua Table Reference, Theming Guide, Conditions & Events, Portraits, Input Controls, Save/Load, Full API Reference, FAQ, and Changelog
- **Lifetime updates**

---

### Who This Is For

- **Anime RPG developers** who need NPC story arcs, branching quest dialogue, and conditional path logic
- **Adventure and narrative game creators** who want the dialogue infrastructure that Unity developers take for granted
- **Horror game developers** who need atmospheric NPC encounters with conditional responses and slow, tension-building text reveal
- **Any Roblox developer** tired of writing the same spaghetti NPC dialogue script over and over

---

## Tags

1. `dialogue`
2. `RPG`
3. `NPC`
4. `quest`
5. `narrative`

---

## Pricing Recommendation: **1,400 Robux**

**Rationale (updated for V1.0 feature set):**

The original listing recommended 1,200 Robux based on the initial feature set. V1.0 has significantly expanded the product:

**New in V1.0 since the original listing:**
- Simple text format (dramatically lowers the authoring skill floor)
- 5 built-in themes + `Theme.Extend()` API + per-conversation themes
- Auto-viewport NPC portraits + custom portrait images + per-node model overrides
- Voice/sound line playback
- Full UI sound effects system (`openSoundId`, `closeSoundId`, `typewriterSoundId`, etc.)
- Full keyboard, gamepad, and touch input handling
- Save/Load state system with DataStore integration
- `autoAdvanceDelay` for cinematic no-choice nodes
- `animationSpeed` theme control (including zero for instant UI)
- `engine:Destroy()` for clean lifecycle management
- **Variable interpolation** — `{variableName}` in dialogue and choice text, resolved from registered callbacks at display time
- **Inline text control** — `[pause N]` and `[speed N]` tags for mid-sentence typewriter pacing

**Justification for 1,400 Robux:**

- **Scope:** V1.0 is a substantially more complete product than what the 1,200 Robux estimate was based on. The feature set now competes with paid Unity plugins that sell for $50–$138 USD.
- **Ceiling room:** Still within the 800–1,500 Robux brief. Pricing at 1,400 (rather than 1,500) maintains a slight psychological buffer below the stated ceiling.
- **Value signal:** A higher price in the range signals "professional tool" to the genre developers most likely to buy it (RPG and adventure devs tend to be more experienced and budget-conscious about tooling).
- **Promotional flexibility:** Launching at 1,400 allows a one-time launch sale to 999 Robux for early adopters, with the ability to rise back to 1,500 once reviews accumulate.
- **Competitive anchoring:** Even at 1,400 Robux, this is dramatically underpriced compared to Unity equivalents. That's a feature, not a weakness — developers can feel they got a bargain.

**Alternative:** If the goal is maximum install volume and community building early (to generate DevForum discussion and early reviews), a launch price of **999 Robux** with a planned increase to 1,400 after 30 days is also a strong strategy.
