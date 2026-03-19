# Downhill Madness — Audio Curation

All sounds sourced from Splice. Previews (MP3) downloaded below. Full WAV downloads require claiming (1 credit each) — the claim API returned 401 during this session, likely a subscription scope issue. UUIDs provided for manual claiming.

## Engine Loops (2 candidates)

| File | Pack | Duration | UUID | Notes |
|------|------|----------|------|-------|
| `engine/shs_crd_44_texture_industrial_loop_Struggle_engine_motor.wav` | Corridor | 43.6s loop | `18b8b150ded36edbb067387dd4892e803f0103d12133fe71356d18bb41923636` | Industrial engine texture — raw, gritty. Pitch-shift up for high RPM, down for idle. Long loop = seamless. |
| `engine/ESM_FG_mechanical_loop_engine_tractor_drive_1.wav` | Farm Game | 4.9s loop (197 BPM) | `4244a2261c45f1038e0870b27f6a381832648d2657312b59aae951e48635887e` | Chunky tractor engine — has rhythmic mechanical character. Short loop, easy to pitch-shift with speed. |

**Recommendation:** The tractor drive loop has more character for a game — shorter, punchier, and the rhythmic quality makes it feel alive when pitch-shifted. The industrial texture loop is great as an underlying bed/ambience layer.

## Crash/Impact SFX (5 sounds, 3 categories)

### Metal Crunch (car crashes)
| File | Pack | Duration | UUID |
|------|------|----------|------|
| `crash/ESM_Game_Car_Crashes_Metal_Smash_Bash_Impact_Hit.wav` | Advanced Game Sounds | 764ms | `daf710aca256ff99cd264c9f93e27cd85e8bce82d509737e73f41db0f7454c4d` |
| `crash/ESM_Game_Car_Crash_Metal_Smash_Bash_Impact_Hit.wav` | Advanced Game Sounds | 737ms | `3562d48c5079eec29d72efa608d887ae4c591bd00d733d51dd4baee2cdb5f0fd` |
| `crash/ESM_Game_Car_Crash_2_Metal_Smash_Bash_Impact_Hit.wav` | Advanced Game Sounds | 674ms | `ae0472796e36578aec767f87b22e4479542c93310e6c0380c29e404dc41338af` |

### Heavy Thud
| File | Pack | Duration | UUID |
|------|------|----------|------|
| `crash/SPLC-0562_FX_Oneshot_Metal_Tank_Impact.wav` | Heavy Metal Vol.1 | 4.9s | `5bea64b50c660bf23a316315db359a667b3220f113a93a35fafcc39807f5af4b` |

### Glass Break (windshield)
| File | Pack | Duration | UUID |
|------|------|----------|------|
| `crash/ESM_Controlled_Glass_Break_Shatter_Rubble.wav` | HD Source Part 4 | 221ms | `80feb06105be87c0f1632a3b65099e7673c5b54abb3a20af367e1ce582d15191` |

**Creative note:** Layer the metal crunch + glass break for devastating Viper crashes (fragile vehicle, windshield health = 30). Use the heavy tank impact for Rhino collisions — it needs to sound like the *other* car got hurt.

## Tire Screech (2 sounds)

| File | Pack | Duration | UUID |
|------|------|----------|------|
| `tires/FF_CRT_sfx_car_screech_medium.wav` | Cartoon Sound FX | 1.5s | `60971af002f7c9b587493504c19af5f1d4f5f72f50a83ef7910b18af22e11f02` |
| `tires/FF_CRT_foley_car_screech_low.wav` | Cartoon Sound FX | 1.4s | `13e13c1f59311b092c9f67c9ee918f22b1235257e9e5ffe3e9f389d0c7905274` |

**Creative note:** The "medium" screech is your standard drift sound. The "low" screech has more body — good for heavy vehicles (Rhino cornering). Could pitch-shift the medium one higher for the Viper.

## Wind/Speed Ambience (2 loops)

| File | Pack | Duration | UUID |
|------|------|----------|------|
| `wind/ESM_SNLS_cinematic_fx_ambience_loop_wind_constricted_flow_turbulent_01.wav` | Synthesized Nature Loops | 7.5s loop | `bf3580b493bd6c1f44aca8c41ba29c40fd460e0c58baa0f99daddc1301f8b0eb` |
| `wind/ESM_SNLS_cinematic_fx_ambience_loop_wind_full_continuous_air_02.wav` | Synthesized Nature Loops | 11.2s loop | `3fcf421542be54546cc33d8067ab925d136ccc2e7a2083f0ef87563a0c8e7923` |

**Creative note:** The "constricted turbulent" wind is higher-pitched and more aggressive — perfect for the Viper at full speed. The "continuous air" is broader and steadier — base layer that fades in proportional to velocity. Layer both and increase volume/pitch with speed for a dynamic wind system.

## Integration Notes for Engineer

- **Engine:** Set up a looping audio source on each vehicle. Adjust pitch based on current speed (map 0→maxSpeed to pitch 0.6→2.0).
- **Crash:** Play random crash SFX on collision events. Scale volume by impact force. Add glass break when windshield health hits 0.
- **Tires:** Trigger screech when lateral slip exceeds threshold (already tracked in DownhillPhysics). Volume proportional to slip magnitude.
- **Wind:** Continuous loop attached to camera. Volume and pitch scale with vehicle speed (0 at standstill, full at maxSpeed).

## Total Credits Needed: 11
