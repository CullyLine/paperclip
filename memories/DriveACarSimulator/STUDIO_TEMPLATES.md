# DAC — template models (Studio)

Names must match **config helpers** (defaults to the data `id` unless `modelName` is set on that entry).

| Location | Lookup | Config |
|----------|--------|--------|
| `ReplicatedStorage.PetModels` | `PetConfig.getPetTemplateName(petId)` | `PetConfig.luau` — `listPetIds()` |
| `ReplicatedStorage.EggModels` | `EggConfig.getEggTemplateName(eggId)` | `EggConfig.luau` — `listEggIds()` |
| `ServerStorage.CarModels` | `CarConfig.getCarTemplateName(carId)` | `CarConfig.luau` — `listCarIds()` |

| `ReplicatedStorage.Images` | Browse by child name; each is a Decal or ImageLabel with `rbxassetid://` set | `Images/MANIFEST.md` |

**Runtime wiring**

- **Pets:** `PetController` clones equipped pets into `Workspace.ActivePets` (synced from `DataUpdate`).
- **Cars:** `RunService` clones the equipped car into `Player.Character` as **`Car`** when a run starts (anchored, non-colliding for client `PivotTo`).
- **Eggs:** `EggViewController` clones egg + pet models briefly on hatch (uses `eggId` in hatch result).

Optional override: set **`modelName`** on any pet / egg / car definition in config if the Model in Studio must differ from the id.
