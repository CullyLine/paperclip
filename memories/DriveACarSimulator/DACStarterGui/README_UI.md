# DAC StarterGui — POLA-7 mapping

Ticket asked for these **client** filenames; implementation is split into modules + one loader:

| Ticket name | Implementation |
|-------------|------------------|
| `InventoryUI.client.luau` | `InventoryPanel.luau` |
| `StoreUI.client.luau` | `StorePanel.luau` |
| `EggShopUI.client.luau` | `EggShopPanel.luau` |
| `RebirthUI.client.luau` | `RebirthPanel.luau` |
| `SettingsUI.client.luau` | `SettingsPanel.luau` |
| `CodesUI.client.luau` | `CodesPanel.luau` |
| `DailyRewardUI.client.luau` | `DailyRewardPanel.luau` |
| `PayoutUI.client.luau` | `PayoutPanel.luau` |

All panels are initialized from **`GuiBootstrap.client.luau`** (with `HUD`, `DrivingHUD`, `MenuHub`, `PlaytimeGemHUD`).

Shared helpers: `UIHelpers.luau`, `MenuHub.luau`. Pet index: `PetIndexPanel.luau`.
