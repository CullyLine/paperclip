# DialogueEngine Code Review — V1.0 Pre-Release

Comprehensive code review of the Branching Dialogue Engine for Roblox, organized by severity.

---

## Critical bugs

### 1. **Connection leak in DialogueUI — advance input listeners never disconnected**

**File:** `DialogueUI.lua` (lines 499–533)

**Issue:** When displaying a no-choice node (with or without `autoAdvanceDelay`), the UI adds `UserInputService.InputBegan` connections to listen for advance (click/Enter/Space/A). These are stored in `self._connections` but are **never disconnected** when:
- The user closes the dialogue via Escape or the close button (before advancing)
- A new node is displayed (e.g. auto-advance triggers and `DisplayNode` is called for the next node)

**Consequences:**
- Connections accumulate over multiple dialogues
- Orphaned connections keep firing and call `onAdvance()` → `_endDialogue()` → `Close()`
- A new dialogue can be closed when the player presses Enter due to an old connection firing

**Fix:** Disconnect and clear `_connections` when:
1. `DisplayNode` is called (at the start, after `_cancelAutoAdvance`)
2. `Hide` is called (before or at the start of close)

```lua
-- Add to start of DisplayNode, after _cancelAutoAdvance():
for _, conn in ipairs(self._connections) do
    conn:Disconnect()
end
self._connections = {}

-- Add at start of Hide():
for _, conn in ipairs(self._connections) do
    conn:Disconnect()
end
self._connections = {}
```

Also, when `_cancelAutoAdvance` cancels the task in the auto-delay path, the connection created in that branch is never disconnected (the task never reaches `conn:Disconnect()`). The above fix covers that.

---

## Medium issues

### 2. **RegisterTree overwrites visited nodes**

**File:** `DialogueRunner.lua` (lines 17–19)

**Issue:** Each call to `RegisterTree(treeId, treeData)` sets `self._visitedNodes[treeId] = {}`, clearing all visited state for that tree. Re-registering a tree (e.g. to update dialogue content) unintentionally resets progress.

**Recommendation:** Document this behavior, or consider only overwriting `_visitedNodes[treeId]` when explicitly desired (e.g. add `ResetVisited` to the public API and have `RegisterTree` not touch visited state).

---

### 3. **Voice sound uses Connect instead of Once**

**File:** `DialogueUI.lua` (lines 618–622)

**Issue:** `sound.Ended:Connect(...)` is used for a one-shot voice sound. `Once` would be clearer and avoids theoretical edge cases if the callback fires multiple times.

**Fix:** Use `sound.Ended:Once(...)`.

---

### 4. **Dead imports in DialogueUI**

**File:** `DialogueUI.lua` (lines 11–12)

**Issue:** `RunService` and `Workspace` are required but never used.

**Fix:** Remove unused requires.

---

### 5. **LoadState API documentation mismatch**

**Files:** `DOCS.md` (lines 1300–1311), `DialogueEngine.lua` (209–211)

**Issue:** DOCS says *"Use this to pre-load state before calling `Start()`"*, but `LoadState` only validates the state and returns a boolean. It does not store or pre-load anything. Users must call `StartFromState` to actually resume; there is no separate pre-load flow.

**Fix:** Clarify in documentation: *"Validates that a saved state is valid for the given tree. Returns true if the state can be used with `StartFromState()`. Does not start the UI or modify engine state."*

---

### 6. **DialogueEngine singleton behavior and Destroy**

**File:** `DialogueEngine.lua` (lines 12–29, 217–226)

**Issue:** The module uses a single active instance (`instance`). `new()` closes the previous instance but does not fully destroy it. `Destroy()` clears `instance` only when `instance == self`, so multiple engines can exist; only one is considered active. This is not documented.

**Recommendation:** Add a note in the docs that only one dialogue should be active at a time and that `new()` closes any prior dialogue.

---

## Minor improvements

### 7. **Example filename inconsistency**

**Files:** `README.md` (line 38), `Example/ExampleUsage.local.luau`

**Issue:** README lists `ExampleUsage.lua`; the actual file is `ExampleUsage.local.luau`.

**Fix:** Update README to `ExampleUsage.local.luau` or match the actual filename in docs.

---

### 8. **Theme.GetDefault return type**

**File:** `Theme.lua` (line 143)

**Issue:** `Theme.GetDefault(): any` uses `any`. Could use a more specific type if `ThemeConfig` is exported from Types.

---

### 9. **Choice text with `--` comment**

**File:** `DialogueParser.lua`

**Issue:** A choice like `> Hello -> target -- comment` would parse `target -- comment` as the target node ID. Comments in choice lines are not supported.

**Recommendation:** Document that `--` should not appear in choice lines, or explicitly strip inline comments.

---

### 10. **Changelog version inconsistency**

**File:** `DOCS.md` (lines 1120–1127, 1130)

**Issue:** Changelog lists "V1.1.0" for variable interpolation and inline text control, while LISTING.md and the product version use V1.0. This suggests a future release rather than current features.

**Fix:** Align versions: either move these features under V1.0 in the changelog or clarify that V1.1.0 is planned.

---

## Code quality notes

### 11. **DialogueEngine._displayNode — choice index handling**

**File:** `DialogueEngine.lua` (line 148)

**Note:** `choice.index` from `GetAvailableChoices` is used to index `node.choices[choiceIndex]`. This is correct since `index` matches the original 1-based choice position.

---

### 12. **Theme preset "Dark"**

**File:** `Theme.lua` (line 52)

**Note:** `Dark = {}` is correct; an empty table means "use default theme" when merged.

---

## Documentation vs code

### README.md
- All API methods listed exist and behave as described.
- File structure references `ExampleUsage.lua`; actual file is `ExampleUsage.local.luau`.

### DOCS.md
- `LoadState` is described as pre-loading; implementation only validates.
- `Theme.Merge` is documented.
- Portraits section correctly notes that `portraitImageId` is not supported in the text format.
- The `-- TODO` in the Line Types table is example text, not a leftover TODO.

### LISTING.md
- Feature list matches implementation.
- Version (V1.0) and feature set are consistent.

---

## Summary

| Severity   | Count |
|-----------|-------|
| Critical  | 1     |
| Medium    | 5     |
| Minor     | 4     |

The critical connection leak in `DialogueUI` should be fixed before release. The medium items (visited-state reset, voice sound binding, dead imports, LoadState docs, singleton behavior) are good candidates for the next pass. The rest are polish and documentation updates.
