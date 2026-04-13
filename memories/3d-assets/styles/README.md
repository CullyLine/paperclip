# 3D Asset Style System

This directory defines **style profiles** so agents can generate both chibi pets (for the Roblox game) and full-size commercial assets (for the Roblox Asset Store) using the same core pipeline.

## Core Principle
- **Never hardcode style rules** in prompts or scripts.
- Always load from a style JSON file via `--style full-character` or `--style chibi-pets`.
- `full-character` is the **default**.

## Available Styles

### `full-character.json` (Default)
- Faithful to reference image
- Clean, smooth, game-ready topology
- Realistic proportions (no chibi)
- Higher poly budget (~2000-8000 faces typical)
- Minimal stylization / polish
- Optimized for Roblox Asset Store / Marketplace sales

### `chibi-pets.json`
- Classic chibi pet toy style for Drive A Car Simulator
- Oversized head, stubby limbs, vibrant toy look
- Follows all rules in `PermanentDesignSpecs.md`
- Lower poly target (~340-600 faces)
- Heavy saturation + AO polish

## How to Use

```bash
# Default = full-character
python submit-hunyuan3d.py --style full-character path/to/reference.png

# Explicit chibi pet
python submit-hunyuan3d.py --style chibi-pets path/to/reference.png
```

All core scripts (`submit-hunyuan3d.py`, `decimate.py`, `polish-pet.py`, `rig-anymate.py`, etc.) will be updated to read these profiles.

## For Future Agents
**Always read the style file first.** When the user says "make a 3D asset", ask which style unless it's clear from context. Default to `full-character` for new commercial work.

This system prevents style bleed between game pets and sellable assets.

Last updated: April 2026
```

The style system is now created with `full-character` as default.

Next I will update the core pipeline scripts to load and respect these profiles (starting with the Hunyuan submit and rigging scripts).

Would you like me to continue with updating the scripts now, or review/tweak the two style JSON files first? (The Tung Tung Sahur highpoly is open in your IDE — we can re-run the pipeline with the new `full-character` style immediately after the scripts are updated.)