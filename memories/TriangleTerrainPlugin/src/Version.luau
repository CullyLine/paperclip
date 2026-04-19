--[[
	Triangle Terrain Plugin — version

	BUMP POLICY (semver-style):
	  PATCH (0.0.x): bug fixes, internal refactors, no user-visible behavior change
	  MINOR (0.x.0): new feature, new mode, new UI section, expanded capability
	  MAJOR (x.0.0): breaking change to data format, removal of features, big rewrites

	ALWAYS bump this string before running build_rbxmx.py whenever you ship a
	meaningful change to the plugin. The version is shown in the dock widget
	title so the user can see at a glance which build is loaded.

	History (reverse chronological):
	  0.11.0 — Auto-Triangulate alpha-shape filter. Stylxus laid nodes along
	           a curving road, hit Auto-Triangulate, and got one giant
	           triangle stretching across the empty inside of the curve from
	           one tip to the other. Classic Delaunay convex-hull artifact —
	           the algorithm fills the convex hull regardless of input shape,
	           and any non-convex layout (curves, rings, C-shapes) gets
	           "bridged" by these huge triangles across empty space.
	             Fix: after Bowyer-Watson runs, compute the median nearest-
	             neighbor distance of the input points and drop any triangle
	             whose longest edge exceeds maxEdgeFactor * medianNN. The
	             median-NN baseline scales the threshold to the actual point
	             density, so dense grids and sparse low-poly layouts both
	             work without per-scene tuning.
	             Surfaced as a "Shape Tightness" slider in the Draw panel
	             (range 1.5–8, default 3.0). Lower = stricter shape-following
	             (kills more bridges); higher = closer to raw Delaunay (fills
	             more concavities). Default of 3 catches the curve-bridge
	             case without breaking square grids (their longest legitimate
	             edge is sqrt(2) * spacing ≈ 1.41x). Set to 0 to disable
	             filtering entirely if you ever want raw Delaunay back.
	             stored as autoTriMaxEdgeFactor in settings, persists like
	             everything else through settingsChanged.
	  0.10.4 — Audit pass round 2: 5 medium / low-priority polish items
	           and 2 clarifying comments. No behavior changes you can see
	           directly, but several "wait, why did THAT happen" surfaces
	           are now smoothed over.
	             6. Delete-mode "Deleted: N" counter undercounted whenever
	                a delete cascaded — clicking one node with "Delete
	                Nodes" on would cull ~6 connected triangles, but the
	                counter only added 1. Switched to subscribing to
	                nodeRemoved/triangleRemoved for the duration of the
	                drag, so the counter == actual entities removed (single
	                source of truth = "what state lost"). Removed all the
	                manual SetDeleteStrokeCount calls from the per-tick
	                delete code so it can't drift again.
	             7. Replace-All in the Preset Import panel was a single-
	                click destructive action. One misclick wiped the entire
	                library. Now two-step: first click flips the button to
	                "Confirm replace?" with a darker red for 3 seconds; only
	                a second click within that window commits. Token-
	                guarded timer so re-arming resets the countdown.
	             8. Preset dropdowns in Paint/Draw panels stayed open with
	                stale entries when presets were edited or deleted in
	                the Preset Manager. Clicking a stale row could apply a
	                deleted preset's color/material. Now closes any open
	                "PresetList" descendants on every presets.changed fire.
	            10. Y-position TextBox (and any future _addTextInputRow
	                consumers) re-fired onCommit on focus-lost even when
	                the user didn't type anything. Skips now if the box
	                text matches lastGoodText, killing a needless
	                SetSetting -> settingsChanged cascade that occasionally
	                raced the live-Y broadcaster on the work plane.
	            11. Studio-driven deletes (Delete-key on a node/triangle
	                model in the Explorer) bypassed our state — hover/
	                click/sculpt would silently misbehave on the missing
	                instance until plugin reload. Added ChildRemoved
	                listeners on the nodes / triangles folders that
	                unregister whatever's tracked when an instance leaves
	                the folder by ANY path. Identity-checked (only react
	                if the part that left IS the one we track) so duplicate
	                ids from external sources can't yank our entries.
	                Plugin's own DeleteNode/DeleteTriangle path is
	                idempotent against this — listener fires synchronously
	                during Parent = nil and unregisters first; subsequent
	                UnregisterNode/Triangle is a no-op.
	             Also: clarifying comments on InputHandler:Activate (now
	             guarded against double-Activate inputs binding twice) and
	             NodeManager:ResyncFromWorkspace (explaining why we don't
	             push part.Position back into state.position for already-
	             known nodes — the watchNodeMovement listener handles it).
	  0.10.3 — Audit pass: 5 latent bugs caught before they bit users.
	             1. Selection arrays (selectedNodes / selectedTriangles)
	                never pruned dead ids when the underlying instance was
	                deleted by any path (Place shift+click, Delete mode,
	                cascade from DeleteNode, undo/redo resync). Symptom:
	                "5 selected" label after deleting one of those 5,
	                Delete-Selected silently no-ops on dead ids, undo
	                reviving a part also "re-selects" it as a side effect.
	                Fix: prune in TerrainState:UnregisterNode /
	                UnregisterTriangle (single chokepoint), fire
	                selectionChanged so highlight + label refresh.
	             2. drawSelection (the in-progress 3-vertex Draw pick) had
	                the same problem. Picking node A, switching to Place
	                and deleting A, then returning to Draw and picking B,C
	                left a stale [A,B,C] pick that CreateTriangle silently
	                rejected (nA was nil) — felt like clicks doing nothing.
	                Fix: same prune-on-removal in UnregisterNode, with
	                drawSelectionChanged fired so the panel visual updates.
	             3. TerrainState:SetMode cleared drawSelection but didn't
	                fire drawSelectionChanged, so the Draw panel kept
	                showing a stale partial pick after a mode switch.
	                Fix: clear via table.clear and fire the signal.
	             4. MaterialPresets used Enum.Material[name] directly in
	                two places (_load and ImportFromJSON). Enum.Material[X]
	                THROWS on unknown names rather than returning nil — a
	                single corrupted setting would crash _load mid-loop and
	                truncate the user's library; Import bypassed its own
	                validator and produced a Lua traceback. Wrapped both in
	                pcall with a Plastic fallback (load) / clean error
	                (import).
	             5. Empty Delete-mode click (mouse down on empty space, no
	                drag) opened a ChangeHistoryService recording but
	                captured zero mutations, leaving an empty "DeleteStroke"
	                entry on the undo stack. Now uses
	                Enum.FinishRecordingOperation.Cancel when stroke count
	                is 0, so empty strokes don't pollute undo history.
	                Same fix applied to the mid-stroke deactivation path.
	  0.10.2 — Two real bugs in the Delete-mode shipping in 0.10.0/0.10.1:
	             1. Hover highlight stayed BLUE instead of turning RED.
	                Root cause was a Lua scope bug — HOVER_COLOR_DELETE was
	                declared next to _ensureHoverHighlight (mid-file), but
	                _updateHover (defined earlier) read it as a global, got
	                nil, and _setHoverHighlight fell back to the default
	                blue. Moved both color constants to the top of
	                InputHandler.luau so every method sees them as upvalues.
	             2. Undo of Delete-mode strokes silently failed and printed
	                "The Parent property of Wedge2 is locked, current
	                parent: NULL, new parent Tri_0193" to the output.
	                Root cause: NodeManager:DeleteTriangle / DeleteNode
	                used :Destroy(), which permanently locks the Parent
	                property. ChangeHistoryService recorded the deletion
	                but Roblox refused to re-parent on undo. Switched both
	                to Parent = nil so the instance stays restorable.
	             Also added NodeManager:ResyncFromWorkspace() and wired it
	             to ChangeHistoryService.OnUndo / OnRedo, so when Studio
	             restores deleted parts our self._state.nodes/.triangles
	             maps catch up. Without this, hover/paint/sculpt would
	             still ignore restored geometry until plugin reload.
	             Same fix applies to undo of Delete Selected, Sub-Divide,
	             Auto-Triangulate teardowns, and any other path that
	             routes through DeleteNode/DeleteTriangle.
	  0.10.1 — Delete-mode "Delete Nodes" toggle. Off by default (matches
	           prior behavior). When on:
	             * Hover/click prefers nodes over triangles (smaller hit
	               target wins, same priority as Select mode).
	             * Clicking a node deletes it directly. Connected triangles
	               cascade out via the existing DeleteNode logic.
	             * Deleting a triangle also nukes any of its 3 vertex nodes
	               that aren't used by any other triangle — orphan cleanup,
	               so tearing down a region doesn't leave dangling stray
	               nodes behind.
	           New NodeManager:DeleteTriangleAndOrphans() centralizes the
	           triangle-plus-orphans logic; the inner DeleteNode recordings
	           batch into the outer Delete-stroke recording, so a full sweep
	           (triangles + cascaded triangles + orphan nodes) collapses to
	           one undo step.
	  0.10.0 — New "Delete" mode (7th tool, hotkey 6). Built for fast,
	           free-form triangle cleanup that doesn't require selecting
	           first.
	             * Hover paints the target triangle red (overrides the
	               normal blue hover so the destructive intent is impossible
	               to mistake for Paint or Select hover).
	             * Click deletes the hovered triangle.
	             * Hold and drag to sweep — every triangle the cursor
	               passes over gets deleted, all wrapped in a single
	               ChangeHistoryService recording so the whole stroke is
	               one undo step (matches the Sculpt drag pattern from
	               0.8.2).
	             * Mode toolbar button uses the negative/red active color
	               instead of accent blue, so the "you are in a destructive
	               mode" state is visible from the toolbar alone — no need
	               to glance at the panel.
	             * Panel shows a live "Deleted: N" counter during a drag
	               and a caution banner explaining what's about to happen.
	             * Mid-stroke deactivation cleanly commits the partial
	               recording (same defensive pattern as Sculpt).
	  0.9.0 — Work plane overhaul. The plane was hard to see and you couldn't
	          pin it where you wanted it. Three changes:
	            * Visual: brighter cyan slab with a crisp SelectionBox border,
	              a centre crosshair (so you can see where the camera column
	              hits the plane), and a floating "Y: 23.5" label rendered
	              on top of the plane via SurfaceGui — so you can read the
	              plane's height directly in the viewport, no panel-glance
	              required. Edge color flips to amber when locked, so the
	              lock state is obvious from the 3D scene alone.
	            * Lock + manual Y entry: new "Lock Work Plane" toggle pins
	              Y at the current value; new editable "Y Position" field
	              shows the live Y and lets you type an exact target (typing
	              auto-locks, since "I want it HERE" implies "stay HERE").
	              The "Height Below Cam" slider only does anything when
	              unlocked, so it greys out when lock is on.
	            * Reusable disable cascade: _addToggleRow / _addSliderRow /
	              new _addTextInputRow now return controllers with SetEnabled
	              and SetValue, so any future "this option only matters when
	              the parent toggle is ON" case can grey out cleanly. The
	              work plane section uses this so all the dependent rows
	              (Lock, Y Position, offset slider) grey out when "Show Work
	              Plane" is off.
	  0.8.2 — Undo audit pass. Fixed every remaining "did stuff, can't undo it
	          properly" case found by walking every mutating callsite:
	            * "Delete Selected" *button* in the Select panel had the same
	              bug 0.8.1 fixed for the keyboard path — only one of the two
	              code paths got fixed. Both now route through a shared
	              NodeManager:DeleteMany so they can't drift apart again.
	            * Auto-Triangulate created N undo entries (one per triangle).
	              Now wrapped in one outer recording.
	            * Add Tag / Remove Tag buttons (and the floating tag dialog)
	              created N undo entries. Now batched via
	              NodeManager:AddTagToNodes / RemoveTagFromNodes.
	            * Sculpt drags created one undo entry per Heartbeat tick
	              (~120 entries for a 2-second stroke). Now one outer
	              recording opens on Button1Down and closes on Button1Up,
	              so each stroke is one undo step. Mid-stroke deactivation
	              cleanly commits the partial recording.
	  0.8.1 — Two fixes: (1) "Delete Selected" now produces a single undoable
	          step. Previously triangle-only deletes had NO undo entry (because
	          DeleteTriangle didn't record on its own) and node deletes
	          produced N separate undo steps. Wrapped the whole batch in one
	          ChangeHistoryService recording. (2) Removed the redundant
	          "Clear Selection" button from the Draw panel — clicking the same
	          node again already toggles it off, and Escape now aborts an
	          in-progress 3-vertex pick.
	  0.8.0 — Select mode actually works visually now. Two layers of feedback:
	          (1) gold always-on-top Highlight overlays per selected node/
	          triangle, and (2) Studio's native Selection service is mirrored,
	          so selected items show in the Properties panel and feel like
	          regular Studio selection. Hover in Select mode now also previews
	          triangles (was nodes-only before, even though clicks worked on
	          both). All selection visuals auto-clear when leaving Select mode
	          or deactivating the plugin tool.
	  0.7.2 — Fix off-by-one in "+ New Preset" spotlight. Add() fires `changed`
	          synchronously *before* returning, so the deferred-target trick
	          from 0.7.1 always ran one click late (creating Preset 8 would
	          spotlight Preset 7). Now we call _spotlightPresetRow directly
	          from the click handler with the freshly-returned id, since the
	          manager has already refreshed by that point.
	  0.7.1 — UX fix: clicking "+ New Preset" had no visible effect because the
	          new row appeared off-screen at the bottom of the manager list.
	          Now the manager auto-scrolls the new row into view, focuses its
	          name TextBox (with select-all so typing replaces the placeholder),
	          and briefly flashes its outline accent so it visually pops.
	  0.7.0 — Material Preset import / export. Two buttons in the Presets
	          panel pop up inline JSON panels: Export pretty-prints the
	          library and offers Copy-to-Clipboard (StudioService); Import
	          parses pasted JSON, validates every entry up-front, and lets
	          the user choose Add (merge) or Replace All. One-line-per-
	          preset format that's hand-editable.
	  0.6.1 — Removed the redundant "Use" button from preset manager rows.
	          Selecting a preset from the dropdown already applies it; the
	          extra button just took up space.
	  0.6.0 — Material Presets: 6th "Presets" tab with full CRUD manager
	          (name, color swatch, material picker, ViewportFrame thumbnails,
	          Use button, delete). Preset dropdown added to Paint and Draw
	          panels with thumbnails in the list and a "+ Manage Presets"
	          shortcut at the bottom. Presets persist via plugin:SetSetting
	          so they're shared across every workspace. Ships 6 sensible
	          defaults (Grass, Dirt, Stone, Sand, Snow, Water) on first run.
	          Paint UI now auto-syncs preview/material text via settings
	          signals.
	  0.5.0 — Simplified Sub-Divide: removed the increment slider and custom
	          value input. Always does the classic 1->4 split now. Less UI,
	          fewer T-junction edge cases.
	  0.4.0 — Sub-Divide now re-fans neighboring triangles along the shared
	          edge so they share the new midpoint nodes. Eliminates the
	          T-junction gaps that appeared when sculpting a subdivided edge.
	  0.3.2 — Fix: hover highlight was lighting up the entire workspace when
	          unhovered. Now toggles Highlight.Enabled instead of nilling
	          Adornee (which falls back to adorning the parent).
	  0.3.1 — Fix: hover highlight crash after Sub-Divide. Highlight is now
	          parented to workspace and only the Adornee is swapped, so the
	          highlight's lifetime is decoupled from the hovered instance.
	  0.3.0 — Sub-Divide mode: hover-preview + intelligent triangle subdivision
	          with 1-5 slider plus double-click-to-customize value (up to 50).
	          Adds Version module shown in widget title.
	  0.2.0 — Baseline before Sub-Divide work (5 modes, auto-triangulate,
	          sculpt, paint, work plane, tag filter, persistence).
]]

local Version = {}

Version.STRING = "0.11.0"

return Version
