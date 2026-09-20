# PoB2 custom Power Report

Based on the official Path of Building 2 **v0.23.1** release.

- Resistance breakdowns name elemental Exposure and explain its base value, extra reduction, effect scaling, enemy effectiveness and rounding when hovering its source name. `Config` stays abbreviated; `EnemyConfig` displays as Enemy settings; base resistance identifies presets/overrides. Penetration tooltips also list contributing modifier sources with spell/main-hand/off-hand filtering. Internal modifier identities and calculation values are unchanged.

- **Electrocuting Arrow:** Configuration exposes **Is an Electrocuting Rod attached?** when the skill is active. This manual, initially unchecked condition enables lightning Electrocution buildup and gates the gem's existing quality effects. Standard quality uses the existing hit-only `DamageGainAsLightning` calculation and gem-stat rounding (10/20/23/28 quality gives 5/10/11/14% gain). Full DPS inclusion is independent. The rod is assumed attached, not automatically maintained after Electrocution. Verified with `tests/custom_electrocuting_arrow.lua`.

- **Soul Core of Xopec on martial weapons:** backports the 0.5.5 weapon modifier from upstream [#2505](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/pull/2505), adapted to this release's `ModRunes` schema. Clipboard imports and the augment editor recognize **25% increased Magnitude of Shock you inflict**, using the existing Shock calculation. Enable **Is the enemy Shocked?** and leave the numeric Shock effect blank to compare automatic magnitude changes. Existing stronger manual Shock values retain precedence. Re-import an item if an earlier editor save discarded its unrecognized augment. The remaining 0.5.5 Soul Core updates are included below.

- Equipping **Lavianga's Spirits** exposes **Do you have a Flask active?** in Configuration, without requiring an allocated flask-dependent passive. The checkbox remains manual and is not marked invalid while Lavianga is equipped.
- Configuration also exposes supported manual scenarios for equipped charms, mana leech, recent shocks/critical hits/non-critical hits/kills, Mark use, Charged Mark's shocked ground, and skills with increased heavy-stun buildup. Hover for the source. These visibility rules preserve checkbox values and do not add automatic assumptions; already supplied backend conditions do not gain extra controls. Mark use does not expose Cast a Spell Recently.

- Right-click a Power Report row to ignore that node in the current build.
- Click **Ignored (N)** above the report to select a node, **Focus on tree**, **Restore / Unignore**, or **Restore All**.
- Focus closes the popup, centers the active tree, and highlights the node for five seconds. Nodes absent from the active tree remain listed and restorable.
- Ignoring and restoring immediately refresh the full calculated candidate list, retaining the current report filter and sort. Fresh calculations also respect the ignored IDs.
- Save the build normally. Ignored IDs and fallback names are saved inside its `Tree/IgnoredPowerNodes` XML section and shared by all tree variants of that build. They do not affect allocations, paths, calculation values, or other builds.
- Power Reports calculate the Full DPS roll-up only for the Full DPS metric. Hit DPS reports omit EHP estimates while retaining basic defence stats; other report metrics and normal tree tooltips keep their required calculations. Node comparisons use fresh calculation environments.
- Report generation yields between nodes after approximately 25 ms of work, retaining the existing progress indicator. A single calculation can exceed that interval. No runtime speedup has been benchmarked.
- In **All / numeric range** Power Reports, the main metric shows the total change from adding the full path or removing the node and all its dependants. **Points** and **Per Point** refer to that same set of nodes. **Notables** continues to compare each notable individually without travel or dependent removals.

- **Show Node Power → Notables** compares adding unallocated and removing allocated non-ascendancy notables individually, without travel nodes. Choose **Full DPS**, then **Show Power Report**. Each candidate has **Points = 1**; both **Full DPS** and **Per Point** remain sortable. Choose **Show Unallocated & Clusters** to include cluster notables. The default **Show All** report labels each row **Add**, **Remove**, or **Remove (item)** and includes signed removal changes for allocated and item-granted notables. **Show Allocated** isolates removals; **Show Unallocated** isolates additions. Each comparison uses only that notable, retaining dependent nodes. Points = 1 means one compared notable; removing an item-granted notable does not refund a skill point. This compares the individual passive only; item eligibility, replacement of an existing anoint, and jewel sockets must still be checked separately. The existing item anoint picker can compare replacement anoints.

## Portable version

The tree metric dropdown starts with **Full DPS**, then **Effective Hit Pool**. In **Notables** mode, both reports show signed percentage changes against the current build, with one point per node. **Full DPS / EHP** is available only in this mode and shows both changes in independently sortable columns. Defence-only gains and negative trade-offs remain visible; zero-effect nodes are omitted. Percentages with zero or non-finite baselines/results show **N/A**. With the default red/blue theme, the combined tree highlights DPS gains in red, EHP gains in blue, and gains to both in purple. Each colour's intensity scales independently with its metric; alternative offence/defence colour themes are respected. Decreases remain visible in the report rather than adding colour. Switching out of Notables returns the combined selection to Full DPS.

Extract the complete ZIP into its own folder and launch `Path of Building-PoE2.exe`. Builds and settings live in that portable folder. Existing builds can be opened or copied into its `Builds` folder.

The package uses the official portable release, retaining the upstream executable, LuaJIT, graphics libraries, and game data. Only the custom Lua files and delivery metadata are added or replaced. No performance benchmark is performed.

The `custom.cfg` marker protects the custom files from the official in-app updater. **Custom Releases** opens this fork's releases page. Keep that marker in place and install future custom ZIPs into a separate folder before copying your builds/settings. Saving a custom build with unmodified upstream PoB2 may discard the additional ignored-node XML section; use the custom version to retain it.

## Repository maintenance

- Local checkout: `D:\Codex\PoE2\PathOfBuilding-PoE2`
- `origin`: `https://github.com/buivydas1-stack/PathOfBuilding-PoE2.git`
- `upstream`: `https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2.git`
- Published custom branch: `codex/pob2-customizations`
- Initial stable base: `v0.23.1` (`7d6f530c`)

Keep upstream branches clean. Review new upstream releases on a temporary integration branch, merge the selected stable release into the custom branch after functional checks, and publish a new custom tag. Avoid rebasing commits already used by a published portable release. The weekly Codex task reports upstream changes and recommends integration; it does not perform merges.

## Verification and packaging

Run `tools/Test-CustomPowerReport.ps1` from Windows PowerShell or PowerShell 7. It uses the upstream LuaJIT DLL and headless wrapper for functional checks, including actual mouse handlers, XML round-trips, popup bounds/actions, stale node IDs, and update protection. Calculation checks compare player/minion node and path results with complete calculations, switch between report metrics, verify complete tooltips and Full DPS fallback, and exercise cooperative scheduling with a simulated clock.

For routine local updates run `tools/Build-CustomPortable.ps1 -Lightweight -OutputDirectory <new-staging-directory>`. This stages only custom Lua files, documentation and metadata, without extracting or creating a ZIP. It is an overlay for the matching installed runtime, not a standalone application. Both modes use `tools/CustomPortableManifest.json` for file selection and upstream archive/executable hashes.

For standalone distribution or preparing an upstream upgrade, run `tools/Build-CustomPortable.ps1 -UpstreamZip <official-v0.23.1-portable.zip> -OutputDirectory <new-empty-output-directory>`. The script validates the pinned upstream ZIP checksum, overlays the custom Lua files, verifies all other upstream files byte-for-byte, and creates a ZIP with SHA-256 and provenance metadata. When upgrading upstream, update the pinned release and checksum after review.

## Calcs hit details

**Skill Hit Damage** displays per-damage-type Lucky chance for non-critical and critical hits alongside average hit values. **Enemy Resistances and Penetration** displays resistance-reduction subtotals, enemy resistance before penetration, total penetration, its minimum resistance floor, and the final effective resistance. Attack values are separated by hand. These read existing calculation values; damage formulas are unchanged. Resistance-reduction subtotals sum negative resistance modifiers (Exposure, curses and other reductions); positive resistance modifiers and caps are reflected in the final enemy resistance. Enabled Exposure uses the existing configured effect and enemy scaling. Leopold's Applause is supported by the existing -50% penetration floor. Hover resistance values for the existing effective-damage breakdown.

## GGG 0.5.5 Soul Cores

Backports the 18 changed and 17 new Soul Cores from upstream #2505 / registry `ce566eac`, retaining the v0.23.1 schema. This includes all 13 Jiquani gem-family cores and all four Atziri corrupted-equipment cores. Their English clipboard text, valid socket choices, editor rebuild and saved-item persistence use the normal augment pipeline. Existing stat-order merge keys are retained where possible; new keys avoid collisions with this branch's older export.

Augment tooltips show one-copy limits. Build warnings flag excess copies across currently equipped items; inactive weapons and unequipped items do not count. Ancient augments share their one-copy limit. As upstream does, this reports invalid combinations rather than deleting cores or choosing which duplicate's effects to suppress. Correct a warned setup before relying on its totals.

Additional parser/calculation support covers Topotante's reduced incoming non-damaging ailment effect, Convalescence's Recoup speed (same total recovery over a shorter duration), and Opiloti's Pin duration multiplier in Calcs. Pin duration does not assume enemy uptime or add DPS. Atziri's corruption-outcome text is preserved as a non-combat property. Jiquani's Thesis helmet Mana uses item Armour; its unchanged glove recharge trigger and boot movement-to-recharge mechanics retain upstream's existing unsupported status.

Run `tools/Test-CustomPowerReport.ps1 -TestPath tests/custom_augments_055.lua` for 67 slot/import fixtures, all thirteen effective gem-level comparisons, corrupted-item scalars, save/load, equipped limits, and representative numeric calculations. Run `tests/custom_augments.lua` through the same harness for automatic Shock and passive comparisons. No in-game mechanics measurement or performance benchmark is implied.

Shock Chance now appears in the sidebar and node/item comparisons for hit skills. Comparisons show the signed percentage-point change using the existing calculated value; unchanged values are omitted. Damage and Shock formulas are unchanged.

Node/item comparison tooltips group changed stats under small muted Damage, Ailments, Survivability and Utility headings. Empty categories and single-category headings are omitted; node-only/path and player/minion comparisons remain separate. Electrocute Buildup uses the existing average buildup per hit, showing percentage-point and relative changes.

Chance and ailment-buildup comparison rows include before/after percentages, for example (10% > 11%), alongside the existing delta. This applies to node and item comparisons; calculations are unchanged.

- Projectile comparisons now show Average Projectile Count with fractional before/after values and total Surpassing Projectile Chance. Calcs exposes both totals and modifier sources. Existing projectile and DPS formulas are unchanged.
