#!/usr/bin/env python3
"""
Central 3D Asset Pipeline with Style Profiles

This is the new unified entry point. Agents should use this instead of calling
individual scripts directly.

Usage:
    python memories/3d-assets/pipeline.py generate --style full-character --reference path/to/ref.png --name MyCharacter
    python memories/3d-assets/pipeline.py generate --style chibi-pets --name tungtung

Styles are defined in memories/3d-assets/styles/*.json
`full-character` is the default.
"""

import argparse
import json
import os
import sys
from pathlib import Path

BASE_DIR = Path("memories/3d-assets")
STYLES_DIR = BASE_DIR / "styles"
EXPERIMENTS_DIR = Path("memories/3d-experiments")

def load_style(style_name: str = "full-character"):
    """Load style configuration. full-character is default."""
    if not style_name.endswith(".json"):
        style_name = f"{style_name}.json"
    
    path = STYLES_DIR / style_name
    if not path.exists():
        print(f"Warning: Style {style_name} not found. Using full-character.")
        path = STYLES_DIR / "full-character.json"
    
    with open(path) as f:
        return json.load(f)

def main():
    parser = argparse.ArgumentParser(description="Unified 3D Asset Pipeline")
    parser.add_argument("command", choices=["generate", "list-styles"], help="Command to run")
    parser.add_argument("--style", default="full-character", help="Style profile to use (full-character or chibi-pets)")
    parser.add_argument("--reference", help="Path to reference image")
    parser.add_argument("--name", required=True, help="Asset name (e.g. StoreTungTung, MyCharacter)")
    
    args = parser.parse_args()
    
    if args.command == "list-styles":
        print("Available styles:")
        for f in STYLES_DIR.glob("*.json"):
            style = load_style(f.name)
            default = " (DEFAULT)" if style.get("default", False) else ""
            print(f"  - {style['name']}{default}: {style['description']}")
        return
    
    style = load_style(args.style)
    print(f"Using style: {style['name']} - {style['description']}")
    print(f"Target faces: {style.get('target_faces', 'auto')}")
    print(f"Prompt modifiers: {style.get('hunyuan_prompt_modifiers', 'None')}")
    
    print("\nStyle system loaded successfully.")
    print("Next step: Update individual scripts (submit-hunyuan3d.py, rig-anymate.py, decimate.py, etc.) to accept --style and load this config.")
    print("\nFor now, you can continue using the existing scripts while we migrate them.")

if __name__ == "__main__":
    main()
