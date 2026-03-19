# Downhill Madness — M1 In-Game UI Copy

## Hub Screen

| Element        | Label / Text               | Subtitle / Tooltip                |
|----------------|----------------------------|-----------------------------------|
| Play button    | PLAY                       | Queue for next round              |
| Play (queued)  | CANCEL                     | Leave queue                       |
| Party Mode     | PARTY MODE                 | Squad up with friends             |
| Garage         | GARAGE                     | Customize and upgrade your rides  |
| Shop           | SHOP                       | Skins, boosts, and more           |
| Settings       | SETTINGS                   | Audio, controls, and display      |
| Player list    | PLAYERS                    | _(header)_                        |
| Queue counter  | {n}/{total} queued          | _(dynamic)_                       |
| Game title     | DOWNHILL MADNESS            | _(top center)_                    |

---

## Pre-Round (Vehicle Selection)

| Element              | Text                                |
|----------------------|-------------------------------------|
| Screen title         | SELECT YOUR VEHICLE                 |
| Grid header          | VEHICLES                            |
| No selection prompt  | Select a vehicle from the grid      |
| Taken overlay        | TAKEN                               |
| Confirm button       | CONFIRM                             |
| Countdown timer      | _{seconds remaining}_ (numeric)     |

---

## Race HUD

| Element             | Text / Format                        |
|---------------------|--------------------------------------|
| Placement           | 1st / 2nd / 3rd / 4th … (ordinal)   |
| Elapsed time        | {m}:{ss} (e.g. 0:47)                |
| Timer title         | TIME LEFT                            |
| Timer value          | {m}:{ss} countdown from 2:00        |
| Leaderboard header  | STANDINGS                            |
| Leaderboard entry   | {position} {name} {progress%/time}  |
| Countdown overlay   | 3 → 2 → 1 → GO!                    |

---

## End-of-Round Results

| Element              | Text                                         |
|----------------------|----------------------------------------------|
| Screen title         | RACE RESULTS                                 |
| Timer text           | Next round in {n}s                           |
| Column headers       | POS · PLAYER · TIME                          |
| Finish time format   | {m}:{ss}.{ms}                                |
| Did Not Finish       | DNF                                          |
| Ready button         | READY UP                                     |
| Ready button (toggled) | READY!                                     |
| Return button        | RETURN TO HUB                                |

---

## Settings Menu

| Section     | Label              | Options / Description                              |
|-------------|--------------------|-----------------------------------------------------|
| Audio       | Music Volume       | Slider 0–100                                        |
| Audio       | SFX Volume         | Slider 0–100                                        |
| Controls    | Steer Sensitivity  | Slider: Low / Med / High                            |
| Controls    | Invert Y-Axis      | Toggle On/Off                                       |
| Controls    | Touch Layout       | Buttons / Virtual Joystick                          |
| Display     | Camera Shake       | Toggle On/Off                                       |
| Display     | Show FPS           | Toggle On/Off                                       |
| Display     | Graphics Quality   | Low / Medium / High / Auto                          |
| _Footer_    |                    | v0.1.0 — Downhill Madness                           |

---

## Tutorial / First-Time Player Hints

Short tips shown during a player's first few sessions (loading screens or toast pop-ups):

1. **Steer into it!** — Use left/right to dodge obstacles. Staying on the road = faster times.
2. **Brakes exist.** — Tap brake before sharp turns. Your future self will thank you.
3. **Pick your ride wisely.** — Each vehicle has different speed, handling, and durability. Try them all.
4. **Gravity is not your friend.** — Going airborne looks cool but kills your speed. Hug the ground.
5. **Don't panic on ice.** — Ice cuts your grip hard. Ease off the gas and steer gently.
6. **Watch the timer.** — You've got 2 minutes to reach the bottom. DNF means no rewards.
7. **Ready Up!** — After each race, hit Ready Up to jump straight into the next round.
8. **Wreckage ahead.** — Your car has panels that take damage. Keep your hood on if you can.
