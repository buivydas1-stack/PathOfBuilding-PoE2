# PoB2 custom Power Report

Based on the official Path of Building 2 **v0.23.1** release.

- Equipping **Lavianga's Spirits** exposes **Do you have a Flask active?** in Configuration, without requiring an allocated flask-dependent passive. The checkbox remains manual and is not marked invalid while Lavianga is equipped.
- Configuration also exposes supported manual scenarios for equipped charms, mana leech, recent shocks/critical hits/non-critical hits/kills, Mark use, Charged Mark's shocked ground, and skills with increased heavy-stun buildup. Hover for the source. These visibility rules preserve checkbox values and do not add automatic assumptions; already supplied backend conditions do not gain extra controls. Mark use does not expose Cast a Spell Recently.

- Right-click a Power Report row to ignore that node in the current build.
- Click **Ignored (N)** above the report to select a node, **Focus on tree**, **Restore / Unignore**, or **Restore All**.
- Focus closes the popup, centers the active tree, and highlights the node for five seconds. Nodes absent from the active tree remain listed and restorable.
- Ignoring and restoring immediately refresh the full calculated candidate list, retaining the current report filter and sort. Fresh calculations also respect the ignored IDs.
- Save the build normally. Ignored IDs and fallback names are saved inside its `Tree/IgnoredPowerNodes` XML section and shared by all tree variants of that build. They do not affect allocations, paths, calculation values, or other builds.
- Power Reports calculate the Full DPS roll-up only for the Full DPS metric. Hit DPS reports omit EHP estimates while retaining basic defence stats; other report metrics and normal tree tooltips keep their required calculations. Node comparisons use fresh calculation environments.
- Report generation yields between nodes after approximately 25 ms of work, retaining the existing progress indicator. A single calculation can exceed that interval. No runtime speedup has been benchmarked.

- **Show Node Power → Notables** compares unallocated non-ascendancy notables individually, without travel nodes. Choose **Full DPS**, then **Show Power Report**. Each candidate has **Points = 1**; both **Full DPS** and **Per Point** remain sortable. Choose **Show Unallocated & Clusters** to include cluster notables. This compares the added passive only; item eligibility, replacement of an existing anoint, and jewel sockets must still be checked separately. The existing item anoint picker can compare replacement anoints.

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

Run `tools/Build-CustomPortable.ps1 -UpstreamZip <official-v0.23.1-portable.zip> -OutputDirectory <new-empty-output-directory>`. The script validates the pinned upstream ZIP checksum, overlays the custom Lua files, verifies all other upstream files byte-for-byte, and creates a ZIP with SHA-256 and provenance metadata. When upgrading upstream, update the pinned release and checksum after review.
