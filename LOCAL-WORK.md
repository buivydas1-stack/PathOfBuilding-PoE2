# Local PoB2 handoff

## Push hold — active

The user requested accumulating minor changes locally without contacting GitHub at all. Do not fetch, query remote state, use GitHub connectors, push, create a release, or publish pending changes until explicitly authorized. Local commits, packaging, reinstalling and restarting remain authorized. Ask before mouse control; do not infer authorization for a future mouse session from deployment authorization.

Every final answer while local changes remain pending must briefly mention the unpushed local changes, preferably in one concise bullet. No fixed wording is required.

Continue from the current local HEAD on `codex/pob2-customizations` in `D:\Codex\PoE2\PathOfBuilding-PoE2`. GitHub can intentionally lag behind. Preserve all local/unpushed commits and unrelated edits; do not reset to origin or replace the checkout with a fresh clone. Read Git status/log and the installed `custom-build.json` to establish current state.

Last published commit when the hold began: `6e5f115412cf5d6298a08ee6dc1c377fb6d925ab` (Emergent Possibility support).

Latest deployed application commit: `f76e6bb75fdc36fec5f011b92a1fd404db164920`. Later commits may update these local instructions without changing application code. Local HEAD remains the continuation point. Read the installed metadata/receipt locally; no GitHub check is needed during the hold.

## Pending local changes

- Alt+left-click isolated notable allocation, existing bottom-left warnings for notables not granted by equipped items, and attribute-node shortcut tooltip hints. Focused functional checks cover input, calculation, point counting, item changes, no double count, persistence and tooltip text; the existing Power Report suite passes. Desktop visual inspection has not been performed.

- Remove the informational Emergent Possibility red warning. Configuration help remains; serious build warnings remain.
- Hide inactive Bonded lines in item tooltips, reveal with the existing comparison key (Alt by default), and keep active Shaman/local Idol bonuses visible.
- These display changes were requested without tests. Do not claim functional or visual testing. Application payload hashes and the restarted process are verified during deployment.

Live installation: `C:\Users\Admin\AppData\Local\Programs\PoB2`. Latest stage: `D:\Codex\PoE2\artifacts\pob2-direct-notables-20261002`. Application-only deployment receipt: `D:\Codex\PoE2\artifacts\pob2-direct-notables-backup-20261002\deployment.json`. Installed payload hashes and the restarted process were verified.

For further changes, commit locally and deploy the current local source; update this note with relevant pending work. When the user asks to push, verify the active installation, push the accumulated commits normally, verify the remote commit, and remove/update the hold in both this note and the umbrella `AGENTS.md`.
