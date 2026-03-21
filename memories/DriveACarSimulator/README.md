# Drive a Car Simulator

A Roblox simulator game about driving cars, collecting pets, and printing money.

## Design

- Low-poly, vibrant, saturated, colorful
- Simulator genre with cars and distance progression
- Pay-to-win monetization

## What is it?

A simulator based on cars and distance traveled. Players are limited by gas in their vehicle. Each vehicle has 3 stats: **Gas**, **Power**, **Speed**.

Players upgrade gas storage, power, or speed for each car. Distance traveled by the end of a run determines the money earned. Gas, Power, and Speed are affected by pets, cars, and the rebirth system.

### Driving Mechanic

The car drives forward **automatically** at its speed stat. Players can only steer **left and right** — the car always faces forward. The run ends when gas depletes. Each highway has a finite length; reaching the end **teleports the car back to the start** and the run continues at current speed (a "lap"). Total distance across all laps counts toward payout.

## Target Audience

Players who enjoy progression and idle mechanics, plus eye candy through particles and UI.

## Core Loop

1. Drive a car to earn money on the current world's endless highway, limited by stats
2. Spend money on pets, better cars, and stat upgrades
3. Earn more money, rebirth for permanent base stat boosts
4. Unlock new worlds and discover new mechanics

## Monetization

100% pay-to-win. Game Passes, Developer Products, and Roblox Premium benefits.
Players who pay should feel like they genuinely got what they paid for.

## Project Structure (Rojo)

```
DACReplicatedStorage/    → ReplicatedStorage.DAC
DACServerScriptService/  → ServerScriptService.DAC
DACStarterPlayerScripts/ → StarterPlayer.StarterPlayerScripts.DAC
DACStarterGui/           → StarterGui.DAC
```

## Setup

```sh
rojo serve default.project.json
```

Then connect via the Rojo plugin in Roblox Studio.

## Template models (names in Studio)

See **[STUDIO_TEMPLATES.md](./STUDIO_TEMPLATES.md)** for `PetModels` / `EggModels` / `CarModels` naming and how the code resolves them.
