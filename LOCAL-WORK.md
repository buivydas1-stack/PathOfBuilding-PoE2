# Local PoB2 handoff

## GitHub hold released — 2026-10-02

The user confirmed the Shift+Alt notable allocation update works and explicitly authorized pushing the accumulated local commits. GitHub reads and publication to the existing custom fork are authorized again. Verify the active installation before future pushes. Ask before mouse control; deployment authorization does not authorize desktop mouse control.

Continue from the current local HEAD on `codex/pob2-customizations` in `D:\Codex\PoE2\PathOfBuilding-PoE2`. Preserve local commits and unrelated edits; do not reset to GitHub or replace the checkout.

Latest deployed application commit: `aa98a0f98576183e9eb2117753f64e73f1607604`. Later commits only update instructions. All 40 installed application files and the executable were verified against source/runtime before this push; the active installation is running.

## Current batch

- Tree comparisons suppress Alt stat reveal while Shift is held; Shift+Alt+left-click still toggles isolated notables. Item comparisons and alternative reveal keys retain their behavior.

- Alt+left-click isolated notable allocation, existing bottom-left warnings for notables not granted by equipped items, and attribute-node shortcut tooltip hints. Focused functional checks cover input, calculation, point counting, item changes, no double count, persistence and tooltip text; the existing Power Report suite passes. The user confirmed the functionality works.

- Remove the informational Emergent Possibility red warning. Configuration help remains; serious build warnings remain.
- Hide inactive Bonded lines in item tooltips, reveal with the existing comparison key (Alt by default), and keep active Shaman/local Idol bonuses visible.
- These display changes were requested without tests. Do not claim functional or visual testing. Application payload hashes and the restarted process are verified during deployment.

Live installation: `C:\Users\Admin\AppData\Local\Programs\PoB2`. Latest stage: `D:\Codex\PoE2\artifacts\pob2-shift-alt-20261002`. Application-only deployment receipt: `D:\Codex\PoE2\artifacts\pob2-shift-alt-backup-20261002\deployment.json`. Installed payload hashes and the restarted process were verified.

For further changes, commit locally, deploy the current source, verify the active installation, push normally to the existing custom branch and verify the remote commit. Update this note with relevant delivery state.
