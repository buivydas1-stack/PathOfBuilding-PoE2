# Local PoB2 handoff

## GitHub hold released — 2026-10-02

The user confirmed the Shift+Alt notable allocation update works and explicitly authorized pushing the accumulated local commits. GitHub reads and publication to the existing custom fork are authorized again. Verify the active installation before future pushes. Ask before mouse control; deployment authorization does not authorize desktop mouse control.

Continue from the current local HEAD on `codex/pob2-customizations` in `D:\Codex\PoE2\PathOfBuilding-PoE2`. Preserve local commits and unrelated edits; do not reset to GitHub or replace the checkout.

Latest deployed application commit: `77d8ca3bf37493df16bb53113508ff063b1cf0a0`. All 45 installed Lua payload hashes were verified against source; augment-report functional checks passed with installed modules, and an isolated native interface loaded the installed modules and returned all 126 helmet candidates. The restarted active installation is responding. This application commit is published to the existing custom branch.

## Current batch

- Augment report numbers use PoB thousands/decimal separators; numeric columns are 17 points, names stay 18. Source functional checks and native rendering of grouped signed/result values passed.

- Items has a separate augment recommendation table with an explicit **Calculate augment recommendations** button. No automatic calculations on imports/edits. A native background Lua thread evaluates actual sockets; metric/filter/sort changes reuse completed results. The default baseline clears all target-item augments. **Consider existing augments** compares replacing a chosen socket while retaining the rest. Item categories, equipped one-copy/shared Ancient limits, socket-bound augments and retained invalid limits are checked. Results never apply augments automatically. Source/installed focused checks, existing Power Report/augment/Runeforge checks and native worker/interface delivery passed. Sample worker duration 8.84 seconds for 126 candidates; the isolated frame-loop p95 remained 6 ms, not a full application FPS benchmark. An isolated interface test initially surfaced a native error because its font bundle was missing; the test was stopped, fonts supplied, and subsequent source/installed interface checks passed. The live installation was unchanged at the time of that test error.

- Runeforge button beside Corrupt previews verified deterministic recipes and preserves item rolls, quality and augments. The same button toggles to Undo Runeforge; verified reverse recipes also work after save/reopen or import. Reversal preserves current modifiers and recalculates equipped defences. Apply with Add to build / Save. Unsupported variants, ambiguous recipes and ineligible items are disabled with an explanation. Source and installed functional checks, Runic Ward checks and the Power Report suite passed. Recipe snapshot 2026-10-03; public game patch 0.5.5d is separate from PoB's stable v0.23.1 baseline.
- Rage diagnosis used a disposable copy of the latest saved Pathfinder Lightning Arrow build. It has 120 Strength and no detected Rage source: configured 30 Rage alone has no effect. A temporary `Gain 1 Rage on Hit` modifier activates the scenario and raises Lightning Arrow DPS from 154901.77 to 201551.09. The user's build was not edited.

- Tree comparisons suppress Alt stat reveal while Shift is held; Shift+Alt+left-click still toggles isolated notables. Item comparisons and alternative reveal keys retain their behavior.

- Alt+left-click isolated notable allocation, existing bottom-left warnings for notables not granted by equipped items, and attribute-node shortcut tooltip hints. Focused functional checks cover input, calculation, point counting, item changes, no double count, persistence and tooltip text; the existing Power Report suite passes. The user confirmed the functionality works.

- Remove the informational Emergent Possibility red warning. Configuration help remains; serious build warnings remain.
- Hide inactive Bonded lines in item tooltips, reveal with the existing comparison key (Alt by default), and keep active Shaman/local Idol bonuses visible.
- These display changes were requested without tests. Do not claim functional or visual testing. Application payload hashes and the restarted process are verified during deployment.

Live installation: `C:\Users\Admin\AppData\Local\Programs\PoB2`. Latest stage: `D:\Codex\PoE2\artifacts\pob2-augment-report-format-20261003`. Application-only deployment receipt: `D:\Codex\PoE2\artifacts\pob2-augment-report-format-backup-20261003\deployment.json`. Installed payload hashes, installed functional/native interface checks and the restarted process were verified.

For further changes, commit locally, deploy the current source, verify the active installation, push normally to the existing custom branch and verify the remote commit. Update this note with relevant delivery state.
